/*
 * Copyright (c) 2015, 2016-2018 Eric B. Decker, Dan J. Maltbie
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Author: Eric B. Decker <cire831@gmail.com>
 *         December 2015.
 * Author: Daniel J. Maltbie <dmaltbie@daloma.org>
 *         May 2017.
 */

/*
 * This module provides the main functionality of the driver,
 * including the Si446x driver state machine, all state machine
 * actions, and the Radio interrupt event handler.
 *
 *
 * Driver Layer Finite State Machine
 *
 * The driver FSM is defined by events, actions, and states. For a given
 * event and a given current state, there is one and only one action and
 * next state.  Events are presented from various parts of the system,
 * including operator control commands, driver task events, and interrupts.
 * A tasklet provides the means to ensure that the state machine is
 * exclusively executed regardless of task or interrupt event source.
 * An event trace of the state machine can be found in fsm_trace_array.
 * See fsm_change_state() below for details on state machine mechanics.
 *
 *
 * Interrupt Handler
 *
 * The interrupt handler ensures that all notifications presented by
 * the radio chip interrupt are proccessed as state machine events.
 *
 *
 * State Machine Actions
 *
 * The action functions of the state machine perform the operations
 * requested by the state transition.
 * See fsm_change_state() for the list of all valid actions.
 *
 *
 * Driver Tasks
 *
 * load_config_task, cmd_done_task, send_done_task.
 *
 */
#ifndef PANIC_RADIO

enum {
  __pcode_radio = unique(UQ_PANIC_SUBSYS)
};

#define PANIC_RADIO __pcode_radio
#endif

#include <Si446xDriverLayer.h>
#include <Tasklet.h>
#include <RadioAssert.h>
#include <TimeSyncMessageLayer.h>
#include <RadioConfig.h>
#include <si446x.h>
#include <si446x_stats.h>
#include <message.h>


/**************************************************************************/

module Si446xDriverLayerP {
  provides {
    interface RadioState;
    interface RadioSend;
    interface RadioReceive;
    interface RadioCCA;
    interface RadioPacket;

    interface PacketField<uint8_t> as PacketTransmitPower;
    interface PacketField<uint8_t> as PacketRSSI;
    interface PacketField<uint16_t> as PacketTransmitDelay;

    interface TagnetAdapter<tagnet_block_t>  as  RadioStats;
  }
  uses {
    interface Si446xDriverConfig as Config;
    interface Si446xCmd;

    interface PacketFlag     as TransmitPowerFlag;
    interface PacketFlag     as TransmitDelayFlag;
    interface PacketFlag     as RSSIFlag;

    interface PacketTimeStamp<TRadio, uint32_t>;

    interface Timer<TMilli>  as sendTimer;

    interface Tasklet;
    interface RadioAlarm;

#ifdef RADIO_DEBUG_MESSAGES
    interface DiagMsg;
#endif
    interface Platform;
    interface Panic;
    interface Trace;
  }
}

implementation {

#define HI_UINT16(val) (((val) >> 8) & 0xFF)
#define LO_UINT16(val) ((val) & 0xFF)

#define HIGH_PRIORITY 1
#define LOW_PRIORITY 0

#define __PANIC_RADIO(where, w, x, y, z) do {               \
        call Panic.panic(PANIC_RADIO, where, w, x, y, z);   \
  } while (0)


/**************************************************************************/
/*
 * global I/O context
 */
  tasklet_norace message_t        * pRxMsg;         // recv msg buf driver owns
  tasklet_norace message_t        * pTxMsg;         // xmit msg buf  driver owns

  tasklet_norace si446x_stats_t     global_ioc;
  tasklet_norace uint8_t            rxMsgBuffer[sizeof(message_t)];
  tasklet_norace uint8_t            rxMsgBufferGuard[] = "DEADBEAF";

  void set_global_rssi(uint8_t rssi) {
    global_ioc.last_rssi = rssi;
    global_ioc.max_rssi = (global_ioc.max_rssi < rssi) ? rssi : global_ioc.max_rssi;
    global_ioc.min_rssi = (global_ioc.min_rssi > rssi) ? rssi : global_ioc.min_rssi;
  }


/**************************************************************************/
/* the following defines control how msg send is handled when a delay is
 * required due to other activity that the radio driver is handling, like
 * receiving a msg.
 */
#define SEND_MIN_WAIT    45
#define SEND_MIN_TRIES    2


/**************************************************************************/
/*
 * FINITE STATE MACHINE
 *
 * The Si446x Driver uses a Finite State Machine to control all significant
 * operations of the driver. The FSM description is data-driven, created by
 * an interactive graphical editor (QFSM) and translated into c-code by a
 * custom Python script fsmc.py (found in mm/support/utils/fsmc). The
 * resulting si446xFSM.h file, included below, contains all of the
 * definitions for states, events, actions, transitions, and other related
 * data structures and compiler needs. The routines in this file use these
 * definitions to operate, introducing some dependencies between the FSM
 * and this code. For instance, fsmc.py generates all of forward declarations
 * for the action routines. It is expected that the code below provides the
 * actual routines that correspond to what is generated. Note that while the
 * compiler can detect that a routine is declared but not provided, it
 * cannot detect that a routine is provided but not declared (and therefore
 * not used by the state machine).
 *
 * on boot, the FSM is initilized to STATE_SDN (0)
 *
 * Also, on boot, platform initialization is responsible for setting
 * the pins on the si446x so it is effectively turned off.  (SDN = 1)
 *
 * Platform code is responsible for setting the various pins needed by
 * the chip to determine proper states.  ie.  NIRQ, CTS, inputs,
 * CSN (deasserted), SDN (asserted).  SPI pins set up for SPI mode.
 *
 */
#include <Si446xFSM.h>

  // this action is used by several other actions to re-initialize the receiver
  fsm_result_t a_rx_on(fsm_transition_t *t);

  tasklet_norace fsm_state_t fsm_global_current_state;

  /*
   * fsm_get_state - return value of current state
   */
  fsm_state_t fsm_get_state() {
    return fsm_global_current_state;
  }

  norace uint8_t fsm_active;

  /**************************************************************************/

  // used to record the state transition machine operation
  // each stage represents a record of the FSM stage execution
  typedef struct {
    uint32_t               ts_start;
    uint16_t               elapsed;
    uint16_t               ph;
    uint16_t               modem;
    uint16_t               chip;
    si446x_device_state_t  ds;
    uint16_t               rssi;
    fsm_event_t            ev;
    fsm_state_t            cs;
    fsm_action_t           ac;
    fsm_state_t            ns;
    fsm_event_t            ne;
    uint8_t                al_s;
    uint8_t                al_e;
  } fsm_stage_info_t;

  /*************************************************************************
   *
   * fsm_select_transition
   *
   * Finds the state transition record for the given event and state
   */
  fsm_transition_t *fsm_select_transition(fsm_event_t ev, fsm_state_t st) {
    fsm_transition_t *ev_list;
    fsm_transition_t *trans;
    fsm_event_t n_events;

    n_events = NELEMS(fsm_events_group);
    if (ev >= n_events)
      __PANIC_RADIO(80, ev, st, 0, 0);

    trans = NULL;
    for (ev_list = (fsm_transition_t *) fsm_events_group[ev];
         ev_list && (ev_list->action != A_BREAK); ev_list++) {
      if ((ev_list->current_state == st) || (ev_list->current_state == S_DEFAULT)) {
        trans = ev_list;
        break;
      }
    }
    if (trans == NULL)
      __PANIC_RADIO(81, ev, st, 0, 0);
    return trans;
  }

  /**************************************************************************/
  /*
   * fsm_change_state
   *
   * Given an event as input, search event based fsm transitions to match current state.
   * perform the associated action and update the global state.
   *
   * mutual exclusion is provided using a Tasklet group.  Must be called from within
   * Tasklet.run.
   *
   * There are 3 different sources of events that potentially can occur for
   * this state machine, Interrupts, User, and Task.  We provide a 1
   * element queue for each of these sources.
   *
   * The RadioTimer implements timeouts, waiting, etc and queues through the "task"
   * event.
   *
   * Priority is Int > User > Task.
   */

  tasklet_norace fsm_event_t fsm_int_event, fsm_user_event, fsm_task_event;

  void fsm_int_queue(fsm_event_t ev) {
    if (fsm_int_event) {
      __PANIC_RADIO(82, (parg_t) ev, fsm_int_event,  0, 0);
    }
    fsm_int_event = ev;
    call Tasklet.schedule();
  }


  void fsm_user_queue(fsm_event_t ev) {
    if (fsm_user_event) {
      __PANIC_RADIO(83, ev, fsm_user_event,  0, 0);
    }
    fsm_user_event = ev;
    call Tasklet.schedule();
  }


  void fsm_task_queue(fsm_event_t ev) {
    if (fsm_task_event) {
      __PANIC_RADIO(84, ev, fsm_task_event,  0, 0);
    }
    fsm_task_event = ev;
    call Tasklet.schedule();
  }


  fsm_result_t fsm_results(fsm_state_t s, fsm_event_t e) {
    fsm_result_t t;
    t.s = s;
    t.e = e;
    return t;
  }


  /*
   * fsm_trace related global variables and update routines. records state
   * machine execution details.
   */
#define FSM_MAX_TRACE   120
  tasklet_norace fsm_stage_info_t fsm_trace_array[FSM_MAX_TRACE];
  tasklet_norace uint16_t fsm_tp, fsm_tc, fsm_count;
  const uint16_t fsm_max =  FSM_MAX_TRACE;

  void fsm_trace_start(fsm_event_t ev, fsm_state_t cs) {
    call Si446xCmd.trace(T_DL_TRANS_ST, ev, cs);
    fsm_trace_array[fsm_tc].ts_start  = call Platform.usecsRaw();
    fsm_trace_array[fsm_tc].ev = ev;
    fsm_trace_array[fsm_tc].cs = cs;
    fsm_trace_array[fsm_tc].ac = 0;
    fsm_trace_array[fsm_tc].elapsed = 0;
    fsm_trace_array[fsm_tc].ns = S_SDN;
    fsm_trace_array[fsm_tc].ne = E_0NOP;
    fsm_trace_array[fsm_tc].al_s = call RadioAlarm.isFree();
  }

  fsm_action_t fsm_trace_action(fsm_action_t ac) {
    fsm_trace_array[fsm_tc].ac = ac;
    return ac;
  }

  void fsm_trace_end(fsm_result_t ns) {
    fsm_trace_array[fsm_tc].elapsed = call Platform.usecsRaw() - fsm_trace_array[fsm_tc].ts_start;
    fsm_trace_array[fsm_tc].ns = ns.s;
    fsm_trace_array[fsm_tc].ne = ns.e;
    fsm_trace_array[fsm_tc].al_e = call RadioAlarm.isFree();
    fsm_tp = fsm_tc;
    if (++fsm_tc >= fsm_max)   //  >= NELEMS(fsm_trace_array))
      fsm_tc = 0;
    fsm_count++;
    fsm_trace_array[fsm_tc].ts_start = 0;
  }

  task void cmd_done_task();
  task void send_done_task();

  /*
   * fsm_change_state
   *
   */
  void fsm_change_state(fsm_event_t ev) {
    fsm_transition_t *t;
    fsm_result_t ns;

    if (fsm_active)
      __PANIC_RADIO(82, ev, fsm_global_current_state, fsm_active, 1);

    do {
      fsm_active++; // keep track of number of iterations of internal events
      ns.s = S_SDN;
      ns.e = E_NONE;
      fsm_trace_start(ev, fsm_global_current_state);

      /*
       * select transition record based on event and current state
       * fsm_select_transition will not return NULL, will panic
       * if no transition.
       */
      t = fsm_select_transition(ev, fsm_global_current_state);

      // this list must match with actions defined by FSM
      switch (fsm_trace_action(t->action)) {
        case A_CLEAR_SYNC:  ns = a_clear_sync(t);  break;
        case A_CONFIG:      ns = a_config(t);      break;
        case A_NOP:         ns = a_nop(t);         break;
        case A_PWR_DN:      ns = a_pwr_dn(t);      break;
        case A_PWR_UP:      ns = a_pwr_up(t);      break;
        case A_READY:       ns = a_ready(t);       break;
        case A_RX_CMP:      ns = a_rx_cmp(t);      break;
        case A_RX_CNT_CRC:  ns = a_rx_cnt_crc(t);  break;
        case A_RX_DRAIN_FF: ns = a_rx_drain_ff(t); break;
        case A_RX_FETCH_FF: ns = a_rx_fetch_ff(t); break;
        case A_RX_FLUSH:    ns = a_rx_flush(t);    break;
        case A_RX_OVERRUN_RESET:  ns = a_rx_overrun_reset(t);  break;
        case A_TX_UNDERRUN_RESET: ns = a_tx_underrun_reset(t); break;
        case A_RX_START:    ns = a_rx_start(t);    break;
        case A_RX_TIMEOUT:  ns = a_rx_timeout(t);  break;
        case A_STANDBY:     ns = a_standby(t);     break;
        case A_TX_CMP:      ns = a_tx_cmp(t);      break;
        case A_TX_FILL_FF:  ns = a_tx_fill_ff(t);  break;
        case A_TX_START:    ns = a_tx_start(t);    break;
        case A_TX_TIMEOUT:  ns = a_tx_timeout(t);  break;
        case A_UNSHUT:      ns = a_unshut(t);      break;
        case A_BREAK:
        default:            t = NULL;              break;
      }
      fsm_trace_end(ns);
      // update new state, (keep current if default or unknown)
      if (ns.s < S_DEFAULT)
        fsm_global_current_state = ns.s;

      // protect against infinite loop errors, no more than 3
      // consequtive events are allowed to be generated by
      // action processing
      if (fsm_active > 3)
        __PANIC_RADIO(83, ev, fsm_global_current_state, ns.s, ns.e);
      // process new event generated by previous action, if any
      ev = ns.e;
    } while (ev);

    fsm_active = 0;                     /* done with any cascade */

    // signal completions
    if (global_ioc.rc_signal)
      post cmd_done_task();
    if (global_ioc.tx_signal)
      post send_done_task();
  }

  /**************************************************************************/
  /*
   * load_config_task state variables
   */
  typedef struct si446x_config_state {
    uint32_t       start_time;
    uint32_t       task_time;
    uint8_t       *prop_ptr;
    uint16_t       task_posts;
    uint16_t       task_records;
    uint8_t        list_iter;
    bool           power_up_found;
  } si446x_config_state_t;

  tasklet_norace si446x_config_state_t cfg_cb;

  /**************************************************************************/

  typedef enum {
    CMD_NONE        = 0,     // no command pending.
    CMD_TURNOFF     = 1,     // goto lowest power state.
    CMD_STANDBY     = 2,     // goto low power state
    CMD_TURNON      = 3,     // goto RX_ON state
    CMD_TRANSMIT    = 4,     // transmit a message
    CMD_RECEIVE     = 5,     // receive a message
    CMD_CCA         = 6,     // perform a clear chanel assesment
    CMD_CHANNEL     = 7,     // change the channel
    CMD_SIGNAL_DONE = 8,     // signal the end of the state transition
  } si446x_cmd_t;

  tasklet_norace si446x_cmd_t dvr_cmd;        /* gets initialized to 0, CMD_NONE  */


  /*************************************************************************
   *
   * When powering up/down and changing state we use the rfxlink
   * utilities and the TRadio alarm for timing.   We flag this
   * using stateAlarm_active.  This allows for bailing out from
   * the main state control tasklet while we are waiting for
   * the RadioAlarm to fire.
   */
  norace bool stateAlarm_active   = FALSE;


  /**************************************************************************/

  si446x_packet_header_t *getPhyHeader(message_t *msg) {
    return ((void *) msg);
  }


  si446x_metadata_t *getMeta(message_t *msg) {
    return &(((message_metadata_t *)&(msg->metadata))->si446x_meta);
  }


  /**************************************************************************/

  /* ----------------- CHANNEL ----------------- */

  uint8_t get_channel() {
    return global_ioc.channel;
  }

  void set_channel(uint8_t c) {
    global_ioc.channel = c;
  }

  tasklet_async command uint8_t RadioState.getChannel() {
    return (get_channel());
  }

  tasklet_async command error_t RadioState.setChannel(uint8_t c) {
    c &= SI446X_CHANNEL_MASK;
    if (dvr_cmd != CMD_NONE)
      return EBUSY;
    else if (get_channel() == c)
      return EALREADY;
    set_channel(c);
    return SUCCESS;
  }


  /**************************************************************************/
  /*
   * load_config_task - guts of chip configuration loading.
   *
   * iterates through the configuration, breaking it into 1 millisecond
   * processing periods until all configuration records are processed.
   *
   * State variables to control state across post events are defined above
   */
  task void load_config_task() {
    uint32_t iter_start, iter_now;
    uint16_t size;
    uint8_t *cp;
    uint8_t **config_list;

    if (fsm_get_state() != S_CONFIG_W) {
      __PANIC_RADIO(90, fsm_get_state(), 0, 0, 0);
    }

    config_list = (void *) call Si446xCmd.get_config_lists();

    cp = (void *) cfg_cb.prop_ptr;

    /*
     * cfg_cb.prop_ptr will be NULL if we haven't started yet.
     *
     * Don't let any other radio stuff in via suspend.
     */
    if (!cp) {
      call Tasklet.suspend();
      cfg_cb.prop_ptr = (uint8_t *) config_list[cfg_cb.list_iter];
      cp = (void *) cfg_cb.prop_ptr;
      cfg_cb.task_time = 0;
      cfg_cb.task_posts = 0;
      cfg_cb.task_records = 0;
      cfg_cb.start_time = call Platform.usecsRaw();
    }

    iter_start = call Platform.usecsRaw();

    /* repeat while more config strings exist and less than
     * one millisecond time expired */
    while (cp) {

      /* check to see if we've spent too much time */
      iter_now = call Platform.usecsRaw();
      if ((iter_now - iter_start) > 1000) {
        cfg_cb.prop_ptr = cp;  // keep track of where we left off
        break;
      }

      // process next command in list
      size = *cp++;
      if (size > 16) {
        __PANIC_RADIO(91, cfg_cb.list_iter,
                      (parg_t) cfg_cb.prop_ptr, size, 0);
      }
      // if reached end of this list, look for next list
      if (size == 0) {
        cfg_cb.list_iter++;
        cfg_cb.prop_ptr = (uint8_t *) config_list[cfg_cb.list_iter];
        cp = (void *) cfg_cb.prop_ptr;
        continue;
      }
      // skip over records prior to and including the POWER_UP string.
      if (cfg_cb.power_up_found) {
        nop();
        // don't change the frr config, will mess up hardware CTS
        if (!((cp[0] == SI446X_CMD_SET_PROPERTY) && (cp[1] == 2 /* FRR_CTL */)))
          call Si446xCmd.send_config(cp, size);  // send everything else
      } else {
        nop();
        // power up and patch (if present) are handled by Si446xCmd.power_up()
        if (cp[0] == SI446X_CMD_POWER_UP)
          cfg_cb.power_up_found = TRUE;
      }

      // move to next entry
      cp += size;
      cfg_cb.task_records++;
    }

    if (cp) {                   /* still more to do, post, let others run */
      cfg_cb.task_posts++;
      post load_config_task();
      return;
    }

    // measure time to execution
    iter_now = call Platform.usecsRaw();
    cfg_cb.task_time = iter_now - cfg_cb.start_time;
    cfg_cb.list_iter = 0;

    call Si446xCmd.enable_hw_cts(); // now that configuration is completed
                                    // we can start using hardware cts
    call Si446xCmd.dump_radio();    // copy group register state to ram
    // invoke driver state machine with completion notification event
    fsm_task_queue(E_CONFIG_DONE);
    call Tasklet.resume();
  }


  /**************************************************************************/
  /*
   * cmd_done_task
   *
   * handle signaling completion of user commands
   */
  task void cmd_done_task() {
    if (global_ioc.rc_signal) {
      switch (dvr_cmd){
      case CMD_TURNON:
      case CMD_TURNOFF:
      case CMD_STANDBY:
        dvr_cmd = CMD_NONE;
        signal RadioState.done();
        break;
      case CMD_CCA:
        dvr_cmd = CMD_NONE;
        signal RadioCCA.done(call Si446xCmd.check_CCA() ? SUCCESS : EBUSY);
        break;
      default:
        dvr_cmd = CMD_NONE;
        break;
      }
      global_ioc.rc_signal = FALSE;
    }
    if ((dvr_cmd == CMD_NONE) && (fsm_get_state() == S_RX_ON)) {
      signal RadioSend.ready();
      global_ioc.rc_readys++;
    }
  }


  /**************************************************************************/
  /*
   * send_done_task
   *
   * handle signaling completion of user commands
   */
  task void send_done_task() {
    if (global_ioc.tx_signal) {
      call PacketTransmitDelay.clear(pTxMsg);
      pTxMsg = NULL;
      global_ioc.tx_error = 0;
      global_ioc.tx_reports++;
      global_ioc.tx_signal = FALSE;
      signal RadioSend.sendDone(global_ioc.tx_error);
    }
    if ((dvr_cmd == CMD_NONE) && (fsm_get_state() == S_RX_ON)) {
      signal RadioSend.ready();
      global_ioc.rc_readys++;
    }
  }


  /**************************************************************************/
  /*
   * start_alarm
   *
   * check to see that RadioAlarm is free, otherwise panic.
   * When the RadioAlarm times out, it will cause the Driver finite state machine
   * to run again with E_WAIT_DONE event
   */

  void start_alarm(uint32_t t) {
    if (!(call RadioAlarm.isFree()))
      call RadioAlarm.cancel();
    if (call RadioAlarm.isFree()) {
      call RadioAlarm.wait(t);
      stateAlarm_active = TRUE;
      return;
    }
    stateAlarm_active = TRUE;
    __PANIC_RADIO(63, t, 0, 0, 0);
  }


  /**************************************************************************/
  /*
   * stop_alarm
   *
   * check to see that RadioAlarm is active and cancel it.
   */

  void stop_alarm() {
    stateAlarm_active = FALSE;
    if (call RadioAlarm.isFree())
      return;
    call RadioAlarm.cancel();
  }


  /**************************************************************************/
  /*  do nothing.
   */

  fsm_result_t a_nop(fsm_transition_t *t) {
    global_ioc.nops++;
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_unshut
   *
   * turn on power to the SI446x chip and start a timer to allow time for
   * power to become stable.
   *
   */

  fsm_result_t a_unshut(fsm_transition_t *t) {
    start_alarm(SI446X_POR_WAIT_TIME);
    call Si446xCmd.unshutdown();
    pRxMsg = (message_t *) &rxMsgBuffer;
    pTxMsg = 0;
    global_ioc.rc_signal = 0;
    global_ioc.tx_signal = 0;
    global_ioc.unshuts++;
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
  * a_pwr_up
  *
  * check to see if CTS is up, better be.  Then send POWER_UP command to
  * continue with powering up the chip.  This will take some
  * time (16ms).  CTS will go back up when done.
  */

  fsm_result_t a_pwr_up(fsm_transition_t *t) {
    volatile norace uint8_t xcts;

    nop();
    if (!(xcts = call Si446xCmd.get_cts())) {
      __PANIC_RADIO(9, xcts, 0, 0, 0);
    }
    start_alarm(SI446X_POWER_UP_WAIT_TIME);
    call Si446xCmd.power_up();
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_config
   *
   * prepare the chip for configuration and post the config task to start
   * loading it.
   */

  fsm_result_t a_config(fsm_transition_t *t) {
    /*
     * make the FRRs return a driver custom setting, see si446x_frr_config for
     * details.
     */
    call Si446xCmd.config_frr();
    post load_config_task();
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************
   *
   * a_ready
   *
   * Make the chip ready for receive operation, including final configuration
   * and initialization steps.
   * The user turnon command is acknowledged by the response task and interrupts
   * are enabled.
   * Finally, receiver is turned on (repurposes fsm action).
   */

  fsm_result_t a_ready(fsm_transition_t *t) {
    set_channel(get_channel());
    // initialize interrupts
    call Si446xCmd.ll_clr_ints(0, 0, 0);  // clear all interrupts
    call Si446xCmd.enableInterrupt();
    // set flag for returning cmd done after fsm completes
    global_ioc.rc_signal = TRUE;
    // snapshot radio chip internal register state
    //call Si446xCmd.dump_radio();
    // proceed with a_rx_on action to start receiving
    return a_rx_on(t);
  }


  /**************************************************************************/

  /*
   * go into standby to lower power consumption
   * Also nuke any potential last interrupt that might have gotten in
   * on the way to standby.  See pwr_dn.
   */

  fsm_result_t a_standby(fsm_transition_t *t) {
    stop_alarm();
    call Si446xCmd.disableInterrupt();
    fsm_int_event = E_NONE;
    call Si446xCmd.goto_sleep();   // instruct chip to go to sleep
    // set flag for returning cmd done after fsm completes
    global_ioc.rc_signal = TRUE;
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/

  /*
   * we turn off interrupt and kick fsm_int_event in case one last interrupt
   * got in prior to the pwr_dn taking.  Once we transition to SDN, any interrupt
   * that got in would have been fatal.  (no transition -> panic).
   */
  fsm_result_t a_pwr_dn(fsm_transition_t *t) {
    stop_alarm();
    call Si446xCmd.disableInterrupt();
    fsm_int_event = E_NONE;
    call Si446xCmd.shutdown();
    // set flag for returning cmd done after fsm completes
    global_ioc.rc_signal = TRUE;
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_rx_on
   *
   * enable the receiver for the next packet
   *
   * 1) set the radio state to ready. this will quiesce any active IO
   * 2) we wait for state change to complete so that we avoid any
   *    race conditions with the remaining steps
   * 3) clear pending interrupts of stale conditions
   * 4) send start_rx command to radio
   */
  fsm_result_t a_rx_on(fsm_transition_t *t) {

    if (!pRxMsg){
      __PANIC_RADIO(3, 0, 0, 0, 0);
    }
    /*
     * transitioning to rx_on should flush both.  Clean out transmit, no longer
     * transmitting, and make sure that we don't have anyone else's crap in
     * the fifo.
     */
    stop_alarm();
    call Si446xCmd.change_state(RC_READY, TRUE);   // make sure in ready state
    call Si446xCmd.fifo_info(NULL, NULL, SI446X_FIFO_FLUSH_RX | SI446X_FIFO_FLUSH_TX);
    call Si446xCmd.ll_clr_ints(0, 0, 0);  // clear all interrupts
    call Si446xCmd.start_rx();
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_rx_start
   *
   * detection of active packet reception
   */
  fsm_result_t a_rx_start(fsm_transition_t *t) {

    if (!(pRxMsg))
      __PANIC_RADIO(11, 0, 0, 0, 0);
    global_ioc.rx_ff_index = 0;
    global_ioc.rx_packets++;
    start_alarm(SI446X_RX_TIMEOUT);
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * pull_rx(): pull the rx fifo into the buffer.
   *
   * NOTE: we could (when we have enough bytes) give the Receiver (upstairs)
   * access to the header to see if this packet is for us (FOR_ME).  However
   * if we bail on this packet and return to RX_ON we effectively opening up
   * the transmit gate and if there is a pending TX it would go out.  But the
   * packet we just punted could still be in flight.  ICK.
   *
   * So receive the whole packet, then have a look at the header.  This keeps
   * the transmit gate closed until it really is good to send (after the recv
   * completes).
   */
  void pull_rx(int32_t min) {
    uint8_t  *dp;
    uint16_t  tx_len, rx_len, x, y;
    uint16_t  max_delta;

    dp = (uint8_t *) getPhyHeader(pRxMsg);
    if (!dp) {                          // should have somewhere to receive
      __PANIC_RADIO(10, 0, 0, 0, 0);
    }
    max_delta = sizeof(pRxMsg->header) + sizeof(pRxMsg->data);
    call Si446xCmd.fifo_info(&rx_len, &tx_len, 0);
    if ((min) && (global_ioc.rx_ff_index + rx_len > max_delta)) {
      call Si446xCmd.fifo_info(&x, &y, 0);
      __PANIC_RADIO(10, global_ioc.rx_ff_index, rx_len, ((uint32_t) x) << 16 | y, (parg_t) dp);
    }
    if (rx_len) {
      call Si446xCmd.read_rx_fifo(dp + global_ioc.rx_ff_index, rx_len);
      global_ioc.rx_ff_index += rx_len;
    }
    if (!call PacketRSSI.isSet(pRxMsg)) {
        call PacketRSSI.set(pRxMsg,
                            call Si446xCmd.fast_latched_rssi());
        set_global_rssi(call Si446xCmd.fast_latched_rssi());
      }
  }


  /**************************************************************************/
  /*
   * a_rx_drain_ff
   *
   * bad dog.
   *
   * draining and tossing the received data.  We place it in the
   * active receive buffer so we can see it.  Doesn't go up the stack.
   */

  fsm_result_t a_rx_drain_ff(fsm_transition_t *t) {
    // fifo may be empty, so pulling zero bytes is ok
    pull_rx(0);
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_rx_fetch_ff
   *
   * good dog.
   */

  fsm_result_t a_rx_fetch_ff(fsm_transition_t *t) {
    // need to pull at least one, otherwise panic
    pull_rx(1);
    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_rx_flush
   *
   * current receive has blown up in some spectacular fashion.
   * terminate with extreme prejudice
   */
  fsm_result_t a_rx_flush(fsm_transition_t *t) {

    global_ioc.rx_crc_packet_rx++;
    stop_alarm();
    pull_rx(0);
    return a_rx_on(t);
  }


  /**************************************************************************/
  /*
   * a_tx_start
   *
   * start the transmission of a packet, subsequent events will complete it
   *
   * the radio is prepared for transmission with the following steps:
   * 1) set power if msg metadata has a value set
   * 2) set the radio state to ready. this will quiesce any active IO
   * 3) we wait for state change to complete so that we avoid any
   *    race conditions with the remaining steps
   * 4) clear the fifo and pending interrupts of any stale info
   * 5) write first tranche of data to the transmit fifo
   * 6) issue the start_tx radio command
   * 7) start timer to avoid dead transmitter
   */
  fsm_result_t a_tx_start(fsm_transition_t *t) {
    uint8_t        *dp;
    uint16_t        pkt_len, tx_ff_free, rx_len;
    uint8_t         pwr[1], new_pwr[1];

    dp = (uint8_t *) getPhyHeader(pTxMsg);
    if (!dp || !(*dp))                  /* make sure reasonable to send */
      __PANIC_RADIO(5, 0, 0, 0, 0);

    /* set power level based on setting in message. if no setting, then
     * use previously set value (no change)
     */
    if (call PacketTransmitPower.isSet(pTxMsg)) {
      pwr[0] = call PacketTransmitPower.get(pTxMsg);
      // change power rail based on high order bit
      if (pwr[0] & 0x80) {
        call Si446xCmd.set_pwr_3_3v();
        pwr[0] &= 0x7f;
      } else
        call Si446xCmd.set_pwr_1_8v();
      call Si446xCmd.set_property(SI446X_PROP_PA_PWR_LVL, pwr, 1);
      call Si446xCmd.read_property(SI446X_PROP_PA_PWR_LVL, 1, new_pwr);
      if (pwr[0] != new_pwr[0]) {
        call Si446xCmd.read_property(SI446X_PROP_PA_PWR_LVL, 1, new_pwr);
        __PANIC_RADIO(57, pwr[0], new_pwr[0], 0, 0);
      }
      call PacketTransmitPower.clear(pTxMsg);
    }

    call Si446xCmd.change_state(RC_READY, TRUE);   // instruct chip to go to ready state
    pkt_len = *dp;                  // length of data field is first byte of msg
    (*dp)--;                        // h/w expects one less, stoopid h/w
    call Si446xCmd.fifo_info(&rx_len, &tx_ff_free, SI446X_FIFO_FLUSH_TX);
    if (tx_ff_free != SI446X_EMPTY_TX_LEN)   // fifo should be empty
      __PANIC_RADIO(6, tx_ff_free, pkt_len, 0, (parg_t) dp);
    // find size to fill fifo max(pkt_len, tx_ff_free)
    global_ioc.tx_ff_index = (pkt_len < tx_ff_free) ? pkt_len : tx_ff_free;
    call Si446xCmd.ll_clr_ints(0, 0, 0);  // clear all interrupts
    call Si446xCmd.write_tx_fifo(dp, global_ioc.tx_ff_index);
    call Si446xCmd.start_tx(pkt_len);
    start_alarm(SI446X_TX_TIMEOUT);

    return fsm_results(t->next_state, E_NONE);
  }


  /**************************************************************************/
  /*
   * a_tx_fill_ff
   *
   * use the tx_fifo_almost_empty to indicate that more can be added to
   * the transmit fifo.
   */
  fsm_result_t a_tx_fill_ff(fsm_transition_t *t) {
    uint8_t        *dp;
    uint16_t        pkt_len, tx_ff_free, rx_len, max_delta;
    int16_t         chk_len;

    dp = (uint8_t *) getPhyHeader(pTxMsg);
    pkt_len = 0;
    chk_len = 0;

    if (dp) {
      /*
       * WARNING WARNING WARNING.  At this point we have already started
       * transmitting the packet and have modified the frame_size cell to
       * make the h/w happy.  Thusly it will be one less than we started
       * with at the high layer.
       */
      pkt_len = *dp + 1;              // length of data field is first byte of msg
      chk_len = pkt_len - global_ioc.tx_ff_index;
    }
    max_delta = sizeof(pTxMsg->header) + sizeof(pTxMsg->data);
    if (!dp || chk_len < 0)
      __PANIC_RADIO(7, chk_len, pkt_len, global_ioc.tx_ff_index, (parg_t) dp);
    if (chk_len > 0) {
      call Si446xCmd.fifo_info(&rx_len, &tx_ff_free, 0);
      if (tx_ff_free == SI446X_EMPTY_TX_LEN)   // too late if fifo is already empty
        __PANIC_RADIO(7, tx_ff_free, pkt_len, global_ioc.tx_ff_index, (parg_t) dp);
      // find size to fill fifo min(chk_len, tx_ff_free)
      chk_len = (chk_len < tx_ff_free) ? chk_len : tx_ff_free;
      if (global_ioc.tx_ff_index + chk_len > max_delta)
        __PANIC_RADIO(7, global_ioc.tx_ff_index, chk_len, tx_ff_free, (parg_t) dp);
      call Si446xCmd.write_tx_fifo(dp + global_ioc.tx_ff_index, chk_len);
      global_ioc.tx_ff_index += chk_len;
    }
    return fsm_results(t->next_state, E_NONE);
  }


 /**************************************************************************/

  fsm_result_t a_rx_cnt_crc(fsm_transition_t *t) {
    uint16_t rx_len, tx_len;
    si446x_int_state_t istate;
    si446x_int_clr_t   int_clr;
    uint32_t t0, t1;

    call Si446xCmd.fast_device_state();
    call Si446xCmd.fifo_info(&rx_len, &tx_len, 0);
    int_clr.ph_pend = 0xff;
    int_clr.modem_pend = 0xff;
    int_clr.chip_pend = 0xff;
    call Si446xCmd.ll_getclr_ints(&int_clr, &istate);
    t0 = call Platform.usecsRaw();
    call Si446xCmd.change_state(RC_READY, TRUE);
    t1 = call Platform.usecsRaw();

    call Si446xCmd.fifo_info(NULL, NULL, SI446X_FIFO_FLUSH_RX | SI446X_FIFO_FLUSH_TX);
    call Si446xCmd.ll_clr_ints(0, 0, 0);  // clear all interrupts
    call Si446xCmd.fifo_info(&rx_len, &tx_len, 0);
    call Si446xCmd.ll_getclr_ints(&int_clr, &istate);
    nop();                              /* BRK */
    t1 -= t0;
    global_ioc.rx_bad_crcs++;
    return fsm_results(t->next_state, E_NONE);
  }


 /**************************************************************************/
  fsm_result_t a_rx_timeout(fsm_transition_t *t) {
    global_ioc.rx_timeouts++;
    return a_rx_on(t);
  }


 /**************************************************************************/
  fsm_result_t a_reset_rx_fifo(fsm_transition_t *t) {
    call Si446xCmd.fifo_info(NULL, NULL, SI446X_FIFO_FLUSH_RX);
    return a_rx_on(t);
  }


 /**************************************************************************/
  fsm_result_t a_clear_sync(fsm_transition_t *t) {
    global_ioc.rx_inv_syncs++;
    return a_reset_rx_fifo(t);
  }


 /**************************************************************************/

  fsm_result_t a_tx_timeout(fsm_transition_t *t) {
    global_ioc.tx_timeouts++;
    global_ioc.tx_signal = TRUE;
    global_ioc.tx_error = FAIL;
    //    call Si446xCmd.change_state(RC_SLEEP, FALSE);
    return a_rx_on(t);
  }


  /**************************************************************************/
  /*
   * over_under_reset - clean up after an over/underrun error
   */
  fsm_result_t over_under_reset(fsm_transition_t *t) {
    si446x_device_state_t  new_state;
    uint32_t               t0, t1;

    /* quiesce radio */
    t0 = call Platform.usecsRaw();
    new_state = call Si446xCmd.change_state(RC_READY, TRUE);
    t1 = call Platform.usecsRaw();
    if (new_state != RC_READY)
      __PANIC_RADIO(4, t0, t1, t1-t0, 0);
    t1 -= t0;
    nop();                               /* BRK */
    return a_rx_on(t);
  }

  /**************************************************************************/

  fsm_result_t a_rx_overrun_reset(fsm_transition_t *t) {
    global_ioc.rx_overruns++;
    switch (t->current_state) {
      case S_CRC_FLUSH: global_ioc.rx_crc_overruns++;    break;
      case S_RX_ACTIVE: global_ioc.rx_active_overruns++; break;
      default: break;
    }
    return over_under_reset(t);
  }

  /**************************************************************************/

  fsm_result_t a_tx_underrun_reset(fsm_transition_t *t) {
    global_ioc.tx_underruns++;
    return over_under_reset(t);
  }

  /**************************************************************************/

  fsm_result_t a_rx_cmp(fsm_transition_t *t) {
    uint16_t        pkt_len;
    si446x_packet_header_t *hp;

    stop_alarm();

    /*
     * get pkt_len before any other state changes, we don't know
     * if it matters or not.  but haven't explored it.
     */
    pkt_len = call Si446xCmd.get_packet_info() + 1;        // include len byte
    pull_rx(0);

    /*
     * first byte?  this is the length and SiLabs seems to think this is the
     * length of the following bytes and doesn't include the length itself.
     * Brooookkkkeeennnn.   fix the first byte which is the frame length.
     */
    hp = getPhyHeader(pRxMsg);
    if (!hp)
      __PANIC_RADIO(11, 0, 0, 0, 0);
    hp->frame_length += 1;
    if (pkt_len != global_ioc.rx_ff_index ||
        pkt_len != hp->frame_length) {
      /*
       * something weird happened.  We finished receiving but it is too
       * short.  Lost something in the middle.  Lost interrupt?
       * Overrun?
       */
      global_ioc.rx_errors++;
      return a_rx_on(t);
    }
    /*
     * First ask upstairs (which knows things, like what our node_id is...)
     * if it wants to accept the packet.  Doing this here, means we receive
     * the whole packet which is important to keep the transmit gate closed.
     *
     * In other words, don't change this !!!!   this means you!  Yeah.   You.
     */
    if (signal RadioReceive.header(pRxMsg)) {
      pRxMsg = signal RadioReceive.receive(pRxMsg);
      global_ioc.rx_reports++;
    }
    return a_rx_on(t);                  /* start receiving again */
  }


  /**************************************************************************/

  fsm_result_t a_tx_cmp(fsm_transition_t *t) {
    uint16_t        tx_len, rx_len;

    stop_alarm();
    global_ioc.tx_packets++;
    call Si446xCmd.fifo_info(&rx_len, &tx_len, 0);
    if (tx_len != SI446X_EMPTY_TX_LEN)
      __PANIC_RADIO(10, rx_len, tx_len, 0, 0);

    // set conditions for returning send done after FSM completes
    global_ioc.tx_signal = TRUE;
    global_ioc.tx_error = SUCCESS;

    /* proceed with a_rx_on action to start receiving again */
    return a_rx_on(t);
  }


  /**************************************************************************/

  /* ----------------- RadioState --------------- */

  tasklet_async command error_t RadioState.turnOff() {
    if (dvr_cmd != CMD_NONE)
      return EBUSY;
    else if (fsm_get_state() == S_SDN)
      return EALREADY;

    dvr_cmd = CMD_TURNOFF;
    global_ioc.rc_signal = FALSE;
    fsm_user_queue(E_TURNOFF);
    return SUCCESS;
  }


  tasklet_async command error_t RadioState.standby() {
    if ((dvr_cmd != CMD_NONE) || (fsm_get_state() == S_TX_ACTIVE) || (fsm_get_state() == S_RX_ACTIVE))
      return EBUSY;
    if (fsm_get_state() == S_STANDBY)
      return EALREADY;

    dvr_cmd = CMD_STANDBY;
    global_ioc.rc_signal = FALSE;
    fsm_user_queue(E_STANDBY);
    return SUCCESS;
  }


  tasklet_async command error_t RadioState.turnOn() {
    if (dvr_cmd != CMD_NONE)
      return EBUSY;
    if ((fsm_get_state() != S_SDN) && (fsm_get_state() != S_STANDBY))
      return EALREADY;

    dvr_cmd = CMD_TURNON;
    global_ioc.rc_signal = FALSE;
    fsm_user_queue(E_TURNON);
    return SUCCESS;
  }


  default tasklet_async event void RadioState.done() { }


  /**************************************************************************/

  // need to handle time in a task because RadioSend.send is async call
  task void send_start_task() {
    call sendTimer.startOneShot(global_ioc.send_wait_time);
  }

  event void sendTimer.fired() {
    nop();
    nop();                                /* BRK */
    // initiate transmit if possible, else start timer to try again
    if (global_ioc.send_tries--) {
      if (fsm_get_state() == S_RX_ON)
        fsm_user_queue(E_TRANSMIT);
      else
        call sendTimer.startOneShot(SEND_MIN_WAIT);
      }
    // too many tries, return error to higher layer
    else {
      global_ioc.tx_signal = TRUE;
      global_ioc.tx_error  = ETIMEOUT;
      post send_done_task();
    }
  }

  /* ----------------- RadioSend ----------------- */

  tasklet_async command error_t RadioSend.send(message_t *msg) {
    nop();
    nop();                                /* BRK */
    if (dvr_cmd != CMD_NONE)
      return EBUSY;
    if (pTxMsg)
      return EALREADY;

    pTxMsg = msg;
    global_ioc.tx_signal = FALSE;
    global_ioc.tx_error = SUCCESS;
    global_ioc.send_tries = SEND_MIN_TRIES;
    global_ioc.send_wait_time = SEND_MIN_WAIT;
    if (call PacketTransmitDelay.isSet(msg))
      global_ioc.send_wait_time += call PacketTransmitDelay.get(msg);
    if (global_ioc.send_wait_time > global_ioc.send_max_wait)
      global_ioc.send_max_wait = global_ioc.send_wait_time;
    post send_start_task();
    return SUCCESS;
  }


  default tasklet_async event void RadioSend.sendDone(error_t error) { }


  default tasklet_async event void RadioSend.ready() { }


  /**************************************************************************/

  /* ----------------- RadioCCA ----------------- */


  tasklet_async command error_t RadioCCA.request() {
    if (dvr_cmd != CMD_NONE)
      return EBUSY;

    dvr_cmd = CMD_CCA;
    // set conditions for returning send done after fsm completes
    global_ioc.rc_signal = TRUE;
    return SUCCESS;
  }


  default tasklet_async event void RadioCCA.done(error_t error) { }


  /**************************************************************************/

  /* ----------------- RadioReceive ----------------- */

 default tasklet_async event bool RadioReceive.header(message_t *msg) {
   return TRUE;
 }

 default tasklet_async event message_t* RadioReceive.receive(message_t *msg) {
   return msg;
 }

  /**************************************************************************/

  /* ------------ HW Interrupt Handling ----------------- */

  /*
   * queue up the fsm_int_event and schedule the tasklet to handle interrupts
   */
  async event void Si446xCmd.interrupt() {
    if (!fsm_int_event) {
      fsm_int_queue(!E_NONE);  // just queue non-null value
    }
  }

  /*
   * store radio chip interrupt pending information for tasklet processing.
   *
   */
  tasklet_norace si446x_frr_info_t          pending_interrupts;

  /*
   * get_next_interrupt_event
   *
   * Check to see if any more interrupts are in the pending information
   * and return associated FSM event to be processed.
   * Clear the flag in the pending information to denote handled.
   *
   * Interrupt Priority:
   *
   * preamble_detect
   * invalid_sync
   * sync_detect
   * crc_error
   * fifo_over/underrun (fifo_ou_run)
   *
   * rx_thresh
   * tx_thresh
   * packet_rx
   * packet_sent
   *
   */
  fsm_event_t get_next_interrupt_event(volatile si446x_int_state_t *isp) {

    /*
     * CMD_ERR
     */
    if (isp->chip_pend & SI446X_CHIP_STATUS_CMD_ERROR)
      __PANIC_RADIO(18, isp->ph_pend, isp->modem_pend, isp->chip_pend, 0);

    if (isp->modem_pend & SI446X_MODEM_STATUS_PREAMBLE_DETECT) {
      isp->modem_pend ^= SI446X_MODEM_STATUS_PREAMBLE_DETECT;
      return E_PREAMBLE_DETECT;
    }
    if (isp->modem_pend & SI446X_MODEM_STATUS_INVALID_SYNC) {
      isp->modem_pend ^= SI446X_MODEM_STATUS_INVALID_SYNC;
      return E_INVALID_SYNC;
    }
    if (isp->modem_pend & SI446X_MODEM_STATUS_SYNC_DETECT) {
      isp->modem_pend ^= SI446X_MODEM_STATUS_SYNC_DETECT;
      return E_SYNC_DETECT;
    }
    if (isp->ph_pend & SI446X_PH_STATUS_CRC_ERROR) {
      isp->ph_pend ^= SI446X_PH_STATUS_CRC_ERROR;
      return E_CRC_ERROR;
    }
    if (isp->chip_pend & SI446X_CHIP_STATUS_FIFO_UNDER_OVER_ERROR) {
      isp->chip_pend ^= SI446X_CHIP_STATUS_FIFO_UNDER_OVER_ERROR;
      return E_FIFO_OU_RUN;
    }
    if (isp->ph_pend & SI446X_PH_STATUS_RX_FIFO_ALMOST_FULL) {
      isp->ph_pend ^= SI446X_PH_STATUS_RX_FIFO_ALMOST_FULL;
      return E_RX_THRESH;
    }
    if (isp->ph_pend & SI446X_PH_STATUS_TX_FIFO_ALMOST_EMPTY) {
      isp->ph_pend ^= SI446X_PH_STATUS_TX_FIFO_ALMOST_EMPTY;
      return E_TX_THRESH;
    }
    if (isp->ph_pend & SI446X_PH_STATUS_PACKET_RX) {
      isp->ph_pend ^= SI446X_PH_STATUS_PACKET_RX;
      return E_PACKET_RX;
    }
    if (isp->ph_pend & SI446X_PH_STATUS_PACKET_SENT) {
      isp->ph_pend ^= SI446X_PH_STATUS_PACKET_SENT;
      return E_PACKET_SENT;
    }
    if (isp->modem_pend & SI446X_MODEM_STATUS_RSSI) {
      isp->modem_pend ^= SI446X_MODEM_STATUS_RSSI;
      return E_NONE;
    }

    if (isp->ph_pend || isp->modem_pend || isp->chip_pend) {
      /* missed something */
      __PANIC_RADIO(19, isp->ph_pend, isp->modem_pend, isp->chip_pend, 0);
      isp->ph_pend = 0;
      isp->modem_pend = 0;
      isp->chip_pend = 0;
    }
    return E_NONE;
  }


  typedef struct int_trace {
    uint32_t               time_stamp;
    uint16_t               delta;
    si446x_idevice_state_t ds;
    uint8_t                ph_pend;
    uint8_t                modem_pend;
    uint8_t                chip_pend;
  } int_trace_t;

  tasklet_norace uint8_t          int_tc, int_tp;
  tasklet_norace int_trace_t      int_trace_array[40];
  tasklet_norace uint32_t         int_trace_prev_time;

  void interrupt_trace(volatile si446x_int_state_t *isp) {
    call Si446xCmd.trace(T_DL_INTERRUPT, isp->ph_pend, (isp->modem_pend << 8) | isp->chip_pend);
    fsm_trace_array[fsm_tc].ph = isp->ph_pend;
    fsm_trace_array[fsm_tc].modem = isp->modem_pend;
    fsm_trace_array[fsm_tc].chip = isp->chip_pend;
    fsm_trace_array[fsm_tc].ds = call Si446xCmd.fast_device_state();
    fsm_trace_array[fsm_tc].rssi = call Si446xCmd.fast_latched_rssi();

    int_trace_array[int_tc].time_stamp = call Platform.usecsRaw();
    int_trace_array[int_tc].ph_pend = isp->ph_pend;
    int_trace_array[int_tc].modem_pend = isp->modem_pend;
    int_trace_array[int_tc].chip_pend = isp->chip_pend;
    int_trace_array[int_tc].ds = fsm_trace_array[fsm_tc].ds;
    int_trace_array[int_tc].delta = int_trace_array[int_tc].time_stamp - int_trace_prev_time;
    int_trace_prev_time =  int_trace_array[int_tc].time_stamp;
    int_tp = int_tc;
    if (++int_tc >= NELEMS(int_trace_array))
      int_tc = 0;
  }

  /*
   * process_interrupt
   *
   * Interrupts can only occur while interrupts are on and this can only
   * be TRUE in the states...  S_RX_ON, S_RX_ACTIVE, S_TX_ACTIVE, and
   * S_CRC_FLUSH.  If an interrupt occurs and is queued (fsm_int_event is
   * non-zero), and we aren't in one of the interrupt states, there won't
   * be a transition and the FSM will PANIC.
   *
   * Called from the tasklet, this routine processes all of the chip
   * interrupt pending conditions.
   *
   * A single hardware interrupt can have pending information on multiple
   * chip related conditions.
   *
   * After clearing chip interrupt pending flags an additional check
   * occurs to prevent race condition with NIRQ changes when clearing
   * pending flags and missing a pending condition.
   */
  volatile norace si446x_int_state_t cur_int_state;
  volatile norace si446x_int_clr_t   cur_int_clear;
  norace uint8_t radio_pend[4];

  void process_interrupt() {
    fsm_event_t ev;
    volatile si446x_int_state_t  *isp  =  &cur_int_state;

    while (TRUE) {
      call Si446xCmd.fast_all(radio_pend);
      call Si446xCmd.trace_radio_pend(radio_pend);
      call Si446xCmd.ll_getclr_ints(NULL,isp);
      if (!isp->ph_pend && !isp->modem_pend && !isp->chip_pend)
        break;
      // process only events of interest
      isp->ph_pend    &= SI446X_PH_INTEREST;
      isp->modem_pend &= SI446X_MODEM_INTEREST;
      isp->chip_pend  &= SI446X_CHIP_INTEREST;
      while ((isp->ph_pend | isp->modem_pend | isp->chip_pend)) {
        interrupt_trace(isp);
        if ((ev = get_next_interrupt_event(isp))) {
          fsm_change_state(ev);
        }
      }
    }
  }


  /**************************************************************************/

  /* ----------------- RadioAlarm ----------------- */

  /*
   * radio_alarm_task
   *
   * radio_alarm_task handles time outs when not in one of the interrupt
   * capable states.  Namely we are doing a pwr_up or configuration.
   * Handle all this at task level.
   */
  task void radio_alarm_task() {
    if (stateAlarm_active) {
      stateAlarm_active = FALSE;
      fsm_task_queue(E_WAIT_DONE);
    }
  }

  /*
   * WARNING: RadioAlarm has to be wired into the same Tasklet as the
   * FSM below.  That is what provides mutual exclusion for the state
   * machine.   See <tinyos>/tos/lib/rfxlink/util/RadioAlarmP.nc. etc.
   *
   * Note: by calling fsm_change_state directly we avoid having to
   * invoke the Tasklet group (via .schedule).  We don't know what
   * order the Tasklet.runs are invoked in.
   */
  tasklet_async event void RadioAlarm.fired() {
    if (call Si446xCmd.isInterruptEnabled()) {
      /*
       * if we are running at interrupt level, the machine is in the
       * interrupt driven portion.  We will handle any timeout
       * detected at interrupt level.
       *
       * Otherwise, the machine is doing pwr_up/configuration kinds
       * of operations and should run at task level.  These things
       * can take a while.
       */
      stateAlarm_active = FALSE;
      fsm_task_queue(E_WAIT_DONE);
      return;
    }

    /*
     * we are running non-interrupt pwr_up/configuration types of things
     * do that from task level.
     */
    post radio_alarm_task();
  }


  /**************************************************************************/
  /*
   * Main State Machine Sequencer
   */
  tasklet_async event void Tasklet.run() {
    fsm_event_t ev;

    while (TRUE) {
      if (fsm_int_event) {
        fsm_int_event = E_NONE;
        process_interrupt(); // may process multiple pending events
        continue;
      }
      if (fsm_user_event) {
        ev = fsm_user_event;
        fsm_user_event = E_NONE;
        fsm_change_state(ev);
        continue;
      }
      if (fsm_task_event) {
        ev = fsm_task_event;
        fsm_task_event = E_NONE;
        fsm_change_state(ev);
        continue;
      }
      break;
    }
  }


  /**************************************************************************/

  /* ----------------- PacketTransmitPower ----------------- */

  async command bool PacketTransmitPower.isSet(message_t *msg) {
    return call TransmitPowerFlag.get(msg);
  }


  async command uint8_t PacketTransmitPower.get(message_t *msg) {
    return getMeta(msg)->tx_power;
  }


  async command void PacketTransmitPower.clear(message_t *msg) {
    call TransmitPowerFlag.clear(msg);
    getMeta(msg)->tx_power = 0;
  }


  async command void PacketTransmitPower.set(message_t *msg, uint8_t value) {
    call TransmitPowerFlag.set(msg);
    getMeta(msg)->tx_power = value;
  }


/**************************************************************************/

/* ----------------- PacketRSSI ----------------- */

  async command bool PacketRSSI.isSet(message_t *msg) {
    return call RSSIFlag.get(msg);
  }


  async command uint8_t PacketRSSI.get(message_t *msg) {
    return getMeta(msg)->rssi;
  }


  async command void PacketRSSI.clear(message_t *msg) {
    call RSSIFlag.clear(msg);
    getMeta(msg)->rssi = 0;
  }


  async command void PacketRSSI.set(message_t *msg, uint8_t value) {
    call RSSIFlag.set(msg);
    getMeta(msg)->rssi = value;
  }


  /**************************************************************************/

  /* ----------------- PacketTransmitDelay ----------------- */

  async command bool PacketTransmitDelay.isSet(message_t *msg) {
    return call TransmitDelayFlag.get(msg);
  }


  async command uint16_t PacketTransmitDelay.get(message_t *msg) {
    return getMeta(msg)->tx_delay;
  }


  async command void PacketTransmitDelay.clear(message_t *msg) {
    call TransmitDelayFlag.clear(msg);
    getMeta(msg)->tx_delay = 0;
  }


  async command void PacketTransmitDelay.set(message_t *msg, uint16_t value) {
    call TransmitDelayFlag.set(msg);
    getMeta(msg)->tx_delay = value;
  }


  /**************************************************************************/

  /* ----------------- RadioPacket ----------------- */

  /*
   * this returns the total offset from the start of the message buffer
   * to the MPDU header.
   *
   * MPDU start right after PPDU (PHY) which is only the length (1 byte)
   */
  async command uint8_t RadioPacket.headerLength(message_t *msg) {
    return call Config.headerOffset(msg) + 1;
  }


  async command uint8_t RadioPacket.payloadLength(message_t *msg) {
    return getPhyHeader(msg)->frame_length;
  }


  async command void RadioPacket.setPayloadLength(message_t *msg, uint8_t length) {
    // we DON'T include the CRC, which is automatically generated
    getPhyHeader(msg)->frame_length = length;
  }


  async command uint8_t RadioPacket.maxPayloadLength() {
    RADIO_ASSERT( call Config.maxPayloadLength() - sizeof(si446x_packet_header_t) <= 125 );

    return call Config.maxPayloadLength() - sizeof(si446x_packet_header_t);
  }


  async command void RadioPacket.clear(message_t *msg) {
    call PacketTransmitPower.clear(msg);
    call PacketRSSI.clear(msg);
    call PacketTransmitDelay.clear(msg);
  }


  /**************************************************************************/

  command bool RadioStats.get_value(tagnet_block_t *stats, uint32_t *lenp) {

    if (stats == NULL || lenp == NULL || *lenp < sizeof(global_ioc))
      __PANIC_RADIO(124, (uint32_t) stats, (uint32_t) lenp,  *lenp, 0);

    stats->block = (uint8_t *) &global_ioc;
    *lenp = sizeof(global_ioc);
    return TRUE;
  }


  command bool RadioStats.set_value(tagnet_block_t *stats, uint32_t *lenp) {
    return FALSE;
  }


  /**************************************************************************/

  async event void Panic.hook() {
    switch(fsm_global_current_state) {
      default:
      case S_SDN:
      case S_POR_W:
      case S_PWR_UP_W:
        return;

        /* reasonable states just fall through */
      case S_CONFIG_W:
      case S_CRC_FLUSH:
      case S_RX_ACTIVE:
      case S_RX_ON:
      case S_STANDBY:
      case S_TX_ACTIVE:
      case S_DEFAULT:
    }
    call Si446xCmd.dump_radio();
  }



  /**************************************************************************/

#ifndef REQUIRE_PLATFORM
  /*
   * We always require Platform.usecsRaw to be working.
   *
   * default async command uint32_t Platform.usecsRaw()       { return 0; }
   * default async command uint32_t Platform.usecsRawSize()   { return 0; }
   */
#error Si446x requires PLATFORM

  default async command uint32_t Platform.usecsRaw()       { return 0; }
  default async command uint32_t Platform.usecsRawSize()   { return 0; }
  default async command uint32_t Platform.jiffiesRaw()     { return 0; }
  default async command uint32_t Platform.jiffiesRawSize() { return 0; }
#endif

}
