/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 * nmea_add_checksum and sirf_bin_add_checksum from gpsd/sirfmon.c 2.37
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 */

#include "panic.h"
#include "gps.h"


noinit uint8_t gps_speed;		// will default to 0, 115200
noinit uint8_t recv_only;
noinit uint16_t recv_count;
uint8_t send_cmd;			// zeroed on boot
uint32_t send_cmd_delay;

/*
 * send_cmd 1: switch to nmea (assumes sirf_bin)
 *	    2: switch sirf_bin baud rate.
 *	    3: send sw ver
 */

uint8_t nmea_go_sirf_bin[] = {
  '$', 'P', 'S', 'R', 'F',		// header
  '1', '0', '0', ',',			// set serial port MID
  '0', ',',				// protocol 0 SirfBinary 1 - NEMA
  '5', '7', '6', '0', '0', ',',		// baud rate
  '8', ',',				// 8 data bits
  '1', ',',				// 1 stop bit
  '0',					// no parity
  '*', '0', '4',			// checksum
  '\r', '\n'				// terminator
};


uint8_t sirf_go_nmea[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x18,			// len 24 (0x18)
  0x81,				// set nmea
  2,			        // mode, 0 enable nmea debug, 1 disable, 2 don't change.
  1, 1,				// GGA 1 sec period, checksum
  0, 1,				// GLL
  1, 1,	                        // GSA
  5, 1,				// GSV (5 sec period)
  1, 1,				// RMC
  0, 1,				// VTG
  0, 1,				// MSS
  0, 0,				// Unused
  0, 1,				// ZDA
  0, 0,				// Unused
  0x12, 0xc0,			// Baud rate (4800)
  0x01, 0x65,			// checksum
  0xb0, 0xb3			// end seq
};

uint8_t sirf_send_sw_ver[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x02,			// len 2
  0x84,				// send sw ver
  0x00,				// unused
  0x00, 0x84,			// checksum
  0xb0, 0xb3			// end seq
};

uint8_t sirf_set_baud[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x09,			// len 9
  0x86,				// change main baud rate
  0x00, 0x00, 0xe1, 0x00,	// 57600
  0x08,				// num bits
  0x01,				// stop bits
  0x00,				// parity, none
  0x00,				// pad
  0x01, 0x70,			// checksum
  0xb0, 0xb3			// end seq
};

uint8_t sirf_set_mid_rate[] = {
  0xa0, 0xa2,			// start sequence
  0x00, 0x00,			// length
  0xa6,				// set message rate
  0x00,				// send now, no
};

uint8_t sirf_set_msc_2[] = {
  0xa0, 0xa2,			// start seq
  0x00, 0x02,			// len 2
  0xb4, 0x02,			// set mrk config, 2 (sirf binary, 57600)
  0x00, 0xb6,			// checksum
  0xb0, 0xb3			// end seq
};

#define SSIZE 2048

uint8_t sbuf[SSIZE];
norace uint16_t s_idx;
uint32_t t_send_start, t_send_done;
uint32_t t_diff;;
uint8_t rctl;

norace struct {
  uint8_t  do_send;
  uint8_t  first_err_rctl;
  uint8_t  first_char;
  uint16_t char_count;
  uint16_t first_err_count;
  uint32_t t_request;
  uint32_t t_pwr_on;
  uint32_t t_first_char;
  uint32_t t_last_char;
  uint32_t t_first_err;
  uint32_t t_eos;
} gpsp_inst;


module GPSP {
  provides {
    interface Init;
    interface SplitControl as GpsControl;
    interface Msp430UartConfigure;
    interface Boot as GpsBoot;
  }
  uses {
    interface Boot;
    interface Resource as UARTResource;
    interface Timer<TMilli> as GpsTimer;
    interface LocalTime<TMilli>;
    interface HplMM3Adc as HW;
    interface UartStream;
    interface Panic;
    interface HplMsp430Usart as Usart;
  }
}

implementation {
  typedef enum {
    GPSC_FAIL = 1,
    GPSC_OFF,

    /*
     * Boot up states.  When first booted these are the states we move through.
     */
    GPSC_BOOT_REQUESTED,
    GPSC_BOOT_FIRST_CHAR,		// @115200 look for the gps to speak something intelligent.  0xa0 would be nice
    GPSC_BOOT_EOS_WAIT,			// wait for end of start up stream @ 115200, sirf binary
    GPSC_BOOT_EOS_DELAY,		// for messing around.
    GPSC_RECONFIG_4800_PWR_DOWN,	// switch to 4800 and power bounce (to get start up sequence)
    GPSC_RECONFIG_4800_FIRST_CHAR_WAIT,
    GPSC_RECONFIG_4800_EOS_WAIT,	// wait for end of start @ 4800 before sending go_sirf_bin
    GPSC_RECONFIG_SEND_WAIT,		// waiting for send of go_sirf_bin to complete
    GPSC_RECONFIG_1152_PWR_DOWN,	// switch to 115200, power is down

    /*
     * Normal sequencing.
     */
    GPSC_REQUESTED,
    GPSC_FIRST_CHAR,
    GPSC_EOS_WAIT,			// wait for end of start up sequence.  don't send any commands before this.
    GPSC_ON,
  } gpsc_state_t;

  typedef enum {
    GPSM_NMEA_DOLLAR = 1,
    GPSM_NMEA_NEXT,
    GPSM_START,
    GPSM_START_2,
    GPSM_LEN,
    GPSM_LEN_2,
    GPSM_PAYLOAD,
    GPSM_CHK,
    GPSM_CHK_2,
    GPSM_END,
    GPSM_END_2,
  } gpsm_state_t;

  norace gpsc_state_t gpsc_state;
  norace gpsm_state_t gpsm_state;
  norace uint16_t gpsm_length;

  //#ifdef notdef
  /* add NMEA checksum to a possibly  *-terminated sentence */
  void nmea_add_checksum(uint8_t *sentence) {
    uint8_t sum = 0;
    uint8_t c, *p = sentence;

    if (*p == '$') {
      p++;
      while ( ((c = *p) != '*') && (c != '\0')) {
	sum ^= c;
	p++;
      }
      *p++ = '*';
      c = sum >> 4;
      if (c > 9)
	*p++ = c + 0x40;
      else
	*p++ = c + 0x30;
      c = sum & 0x0f;
      if (c > 9)
	*p++ = c + 0x37;
      else
	*p++ = c + 0x30;
      *p++ = '\r';
      *p++ = '\n';
    }
  }
  //#endif

  void sirf_bin_add_checksum(uint8_t *buf) {
    uint8_t *bp;
    uint16_t n, sum, len;

    sum = 0;
    len = buf[2] << 8 | buf[3];
    bp = &buf[4];
    for (n = 0; n < len; n++)
      sum += bp[n];
    bp[n] = (sum >> 8) & 0x7f;
    bp[n+1] = (sum & 0xff);
  }

  /*
   * Reconfigure the GPS.
   *
   * 1) gpsc_state = GPSC_RECONFIG
   * 2) switch the uart to 4800
   * 3) Turn power off to the gps.  (we want to see the start up stream)
   *
   *    QUESTION: The NMEA Sirf manual says the receiver will restart after getting
   *    the set port (MID 100).  Do we need to bounce power?
   *
   * 4) set the gpstimer to t_char_delay (doesn't matter, just some time for the bounce.)
   *
   * Timer goes off (gpsc_state == GPSC_RECONFIG)
   * 5) turn GPS power on.
   * 6) set gpstimer for first_char_time_out
   * 7) gpsc_state = GPSC_RECONFIG_FIRST_CHAR_WAIT
   *
   * Timeout: oops
   *
   * got first char and is '$' (nmea, 4800)  (not '$', oops)
   * 8) send go_sirf_bin
   * 9) start gpstimer (first_char_time_out)
   *
   * switch to 4800
   * power off		reconfig
   * ...
   * power up		reconfig_first_char
   * ...
   * first char '$'
   * wait for end of start up.
   * send go sirf bin
   * ...
   * send complete
   * switch to 115200
   * ...
   * look for a0a2
   * 
   * send rest of startup
   * 
   * normal processing.
   * how do we know if the reconfig worked?
   * 
   */

  void start_reconfig() {
    call Usart.disableIntr();		// going down, no interrupts while there
    gpsc_state = GPSC_RECONFIG_4800_PWR_DOWN;
    call HW.gps_off();
    call GpsTimer.startOneShot(T_CHAR_DELAY);
    return;
  }

  command error_t Init.init() {
    if (recv_only != 0 && recv_only != 1)
      recv_only = 1;
    if (gps_speed > 2)
      gps_speed = 0;
    nmea_add_checksum(nmea_go_sirf_bin);
    sirf_bin_add_checksum(sirf_go_nmea);
    sirf_bin_add_checksum(sirf_send_sw_ver);
    sirf_bin_add_checksum(sirf_set_baud);
    sirf_bin_add_checksum(sirf_set_mid_rate);
    sirf_bin_add_checksum(sirf_set_msc_2);
    gpsc_state = GPSC_OFF;
    gpsm_state = GPSM_START;
    gpsm_length = 0;
    memset(sbuf, 0, sizeof(sbuf));
    s_idx = 0;
    return SUCCESS;
  }

  /*
   * Boot up the GPS.
   *
   * Previous components have completed boot, now it is GPS's turn.
   *
   * Start up strategy...
   *
   * The ET-312 sirfIII module has a battery pin and pwr.  The sirf chip will
   * maintain its last configuration settings as long as the battery input has
   * a reasonable amount of juice.  The pwr pin is brought up when we need
   * to have the GPS do its thing.  When powered the GPS first spews for awhile
   * with development information.  Then it settles down into issuing periodic
   * navigation results.
   *
   * If the tag runs out of power, the battery pin will no longer be supplied
   * and the GPS will revert to NMEA-4800-8N1.
   *
   * It takes approximately 300ms for the GPS to power up and start sending
   * data.  We want to set the GPS to SirfBinary at 115200.  We also set
   * various MID so it minimizes how much the chip talks.  We request specific
   * MIDs that give us the navigation information that we want.
   *
   * HOWEVER, sending immediately doesn't seem to work.  So the question is how
   * long do we need to wait before the GPS receiver will accept the command.
   *
   * But if power has been maintained, the GPS will still be communicating in
   * sirfBinary at 115200.  So first we listen at 115200.  If we see framing
   * or other errors we switch to 4800 and switch over using the NMEA change
   * protocol message.
   *
   * The GPS bootstrap is performed once on system bring up.  Its purpose is
   * to perform the following steps:
   *
   * 1) Arbritrate for the UART (will also arbritrate for the underlying USART)
   * 2) Power the GPS up and set the UART for 115200.
   * 3) Listen for a packet (how long?)
   * 4) Send binary initializations, set up long report rates for MIDS, etc.
   *    We use explicit requests to get the information we want.
   *
   * 5) If we get overruns, framing errors, etc. then switch to 4800.
   * 6) repower to reset?
   * 7) wait for a NMEA 4800 packet.  how long?  (look for packets or valid byte)
   *    packet would be more reliable.
   * 8) if we get a valid packet, send the switch to sirfBinary 115200
   * 9) wait for binary packet (goto 3).
   *
   * at 4800 NMEA, first char must be '$' (0x24, 36)
   * at 115200 binary, first char must be 0xa0 (sop is 0xa0a2)
   *
   * How long...
   *
   * gps @ 4800, uart 115200 time to first char...  when do overruns and rx errors occur.
   *	no characters received.  no errors.  got power on timeout.
   *
   * gps @ 115200, 115200, TTFC:  start up message length: 129 (time 107 mis), binary
   *	first_char = 160 (0xa0), char_count = 129, t_request = 386, t_pwr_on = 387,
   *	t_first_char = 701 (314 mis), t_last_char = 808, t_eos = 887 (timeout of 500 from power on)
   *	TTS: (nmea_go_sirf_bin, 26 bytes)  3 mis
   *
   * gps @ 4800, 4800: TTFC:  start up message length: 263 chars, 625 mis, 1053 from power on
   *	first_char = 36 '$', char_count = 263, t_request = 432, t_pwr_on = 433,
   *	t_first_char = 861 (428 mis), t_eos = 1486 (delta 625, from pwr_on 1053 mis)
   *	TTS: (nmea_go_sirf_bin, 26 bytes) 58 mis
   *
   * gps @ 115200, uart 4800:
   *	no characters received.  no errors.  get power on timeout.
   *
   * ------------------------------------------------------------------------
   */

  event void Boot.booted() {
    gpsc_state = GPSC_BOOT_REQUESTED;
    gpsp_inst.char_count = 0;
    gpsp_inst.first_err_count = 0;
    gpsp_inst.t_request = call LocalTime.get();
    call UARTResource.request();
  }

  /*
   * Start GPS.
   *
   * This is what is normally used to fire the GPS up for readings.
   *
   * Some thoughts...
   *
   * 1) We turn the critter on, assuming we've gone through the boot
   *    up sequence which makes sure we are binary, 115200.
   * 2) can we immediately throw commands requesting the navigation data we want?
   * 3) can we send commands back to back?
   * 4) is it reliable?
   * 5) would it be better to sequence?
   * 6) do we want nav data as meters or geodetic?  (mid 2 or mid 41)
   * 7) what is the byte order?  sirf is big endian.  the msp430 is little endian.
   * 8) On boot we may want to actually run a simplified state machine for the
   *    NMEA.  It would be more robust.  See if we can get away with what we've
   *    got.  (That is looking for just the first char seen as the indicator of
   *    goodness).
   *
   * 9) Wait for a while and then send a command.  What does the GPS do?  Then
   *    back it up and see when is the earliest we can send it.
   *
   * During the granting process the GPS will be configured along with
   * the USART used to talk to it.  During this process interrupts
   * will be enabled and we should be prepared to handle them even
   * though we haven't gotten the grant back yet (the arbiter
   * configures then grants.
   */

  command error_t GpsControl.start() {
    gpsc_state = GPSC_REQUESTED;
    gpsm_state = GPSM_START;
    gpsp_inst.char_count = 0;
    gpsp_inst.first_err_count = 0;
    gpsp_inst.t_request = call LocalTime.get();
    return call UARTResource.request();
  }

  /*
   * Stop.
   *
   * Stop all GPS activity.
   *
   * If we have requested but not yet been granted and stop is called
   * not to worry.  When the grant occurs, our state being OFF will
   * cause an immediate release.
   */
  command error_t GpsControl.stop() {
    call Usart.disableIntr();
    gpsc_state = GPSC_OFF;
    call HW.gps_off();
    if (call UARTResource.isOwner()) {
      call UARTResource.release();
      mmP5out.ser_sel = SER_SEL_NONE;
    }
    return SUCCESS;
  }


  /*
   * UARTResource.granted
   *
   * Called when the arbiter gives us control of the UART (also the underlying USART)
   * It will have already called the configurator which turns the gps on and selects
   * the gps via the serial mux.
   *
   * We start a timer (T_GPS_FIRST_CHAR_TIME_OUT) during which time we
   * are looking for the first char from the GPS.  If we time out,
   * assume wrong baud rate.  If we don't receive what we are
   * expecting (binary start 0xa0 0xa2) then assume wrong baud rate.
   */

  event void UARTResource.granted() {

    if (recv_only == 1) {
      gpsc_state = GPSC_ON;
      return;
    }

    switch (gpsc_state) {
      default:
	call Panic.panic(PANIC_GPS, 1, gpsc_state, 0, 0, 0);
	nop();

      case GPSC_OFF:
	/*
	 * We are off which means someone called stop after a request
	 * was issued but the grant hadn't happened yet.  Since we got
	 * the grant, that means there was an outstanding request.
	 * Prior to the grant being issued the configure will have
	 * turned the gps back on so we want to turn it off again.
	 */
	call Usart.disableIntr();
	call HW.gps_off();
	mmP5out.ser_sel = SER_SEL_NONE;
	call UARTResource.release();
	return;

      case GPSC_BOOT_REQUESTED:
	gpsc_state = GPSC_BOOT_FIRST_CHAR;
	break;

      case GPSC_REQUESTED:
	gpsc_state = GPSC_FIRST_CHAR;
	break;
    }
    call GpsTimer.startOneShot(T_GPS_FIRST_CHAR_TIME_OUT);
    return;
  }
  

  event void GpsTimer.fired() {
    switch (gpsc_state) {
      default:
	call Panic.panic(PANIC_GPS, 2, gpsc_state, 0, 0, 0);
	nop();
	return;

      case GPSC_BOOT_FIRST_CHAR:
	/*
	 * Still waiting for the first char.  But we timed out so
	 * reconfig to 4800, send the majik.
	 */
	start_reconfig();
	return;

      case GPSC_BOOT_EOS_WAIT:

	/*
	 * these calls to uartstream.send really should check the return value.
	 */
	switch (send_cmd) {
	  default:
	  case 0:
	    gpsc_state = GPSC_ON;
	    return;
	  case 1:
	    t_send_start = call LocalTime.get();
	    call UartStream.send(sirf_go_nmea, sizeof(sirf_go_nmea));
	    break;
	  case 2:
	    t_send_start = call LocalTime.get();
	    call UartStream.send(sirf_set_baud, sizeof(sirf_set_baud));
	    break;
	  case 3:
	    t_send_start = call LocalTime.get();
	    call UartStream.send(sirf_send_sw_ver, sizeof(sirf_send_sw_ver));
	    break;
	}
	return;

      case GPSC_BOOT_EOS_DELAY:
	return;

      case GPSC_RECONFIG_4800_PWR_DOWN:
	/*
	 * Doing a reconfig (see start_reconfig for sequence.
	 * gps was powered down.  Bring it back up and look for the
	 * start up sequence.  Should be NMEA@4800
	 */
	gpsc_state = GPSC_RECONFIG_4800_FIRST_CHAR_WAIT;
	call HW.gps_on();
	call GpsTimer.startOneShot(T_GPS_FIRST_CHAR_TIME_OUT);
	call Usart.setBaud(UBR_4MHZ_4800, UMCTL_4MHZ_4800);
	call Usart.enableIntr();
	return;

      case GPSC_RECONFIG_4800_EOS_WAIT:
	gpsc_state = GPSC_RECONFIG_SEND_WAIT;
	call GpsTimer.startOneShot(T_GPS_FIRST_CHAR_TIME_OUT);
	t_send_start = call LocalTime.get();
	call UartStream.send(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin));
	return;

      case GPSC_RECONFIG_1152_PWR_DOWN:
	/*
	 * final stage of reconfig.  should now be sirfbin @ 115200
	 */
//	gpsc_state = GPSC_BOOT_FIRST_CHAR;
	gpsc_state = GPSC_ON;
	call GpsTimer.stop();
	call HW.gps_on();
//	call GpsTimer.startOneShot(T_GPS_FIRST_CHAR_TIME_OUT);
//	call Usart.setBaud(UBR_4MHZ_115200, UMCTL_4MHZ_115200);
	call Usart.enableIntr();
	return;
    }
  }
  
  async event void UartStream.receivedByte( uint8_t byte ) {
    uint32_t t;

    t = call LocalTime.get();
    rctl = U1RCTL;
    if (gpsp_inst.char_count == 0) {
      gpsp_inst.t_first_char = t;
      gpsp_inst.first_char = byte;
      nop();
    }
    if ((uart1_rctl & RXERR) && !gpsp_inst.first_err_rctl) {
      gpsp_inst.first_err_rctl = uart1_rctl;
      gpsp_inst.first_err_count = gpsp_inst.char_count;
      gpsp_inst.t_first_err = t;
    }
    gpsp_inst.char_count++;
    gpsp_inst.t_last_char = t;
    sbuf[s_idx++] = byte;
    if (s_idx == 1024) {
      nop();
    }
    if (s_idx >= SSIZE)
      s_idx = 0;

    if (gpsc_state == GPSC_ON) {
      /*
       * Run the normal message collection state machine
       */
      return;
    }

#ifdef notdef
    if (s_idx > recv_count && gpsc_state == GPSC_BOOT_EOS_WAIT) {
      nop();
    }
    if (gpsc_state == GPSC_BOOT_EOS_WAIT)
      return;
#endif

    switch (gpsc_state) {
      case GPSC_OFF:
	/*
	 * We can be in the OFF state but still get an interrupt.  There is a small window
	 * if we have requested and not been granted and a STOP is issued.  The STOP will
	 * set state to OFF and turn things off.  But the request is still outstanding and
	 * when granted the UART configurator will turn the GPS on with interrupts enabled.
	 * Once the grant is issued, the gps is shut down.  But during this time it is
	 * possible to take an interrupt.  It should be ignored.
	 */

      case GPSC_RECONFIG_SEND_WAIT:
	/*
	 * While sending go_sirf_bin we can still be taking incoming input.
	 */
	break;

      case GPSC_BOOT_REQUESTED:
      case GPSC_REQUESTED:
	/*
	 * we haven't seen the grant yet but took an interrupt
	 * kind of strange because we just turned on.  if single
	 * stepping ignore it.
	 *
	 * Panic to let it be seen.
	 */
	call Panic.panic(PANIC_GPS, 98, gpsc_state, byte, 0, 0);
	nop();				// less confusing.
	break;

      case GPSC_BOOT_FIRST_CHAR:
	/*
	 * Looking for the first char @ 115200, assuming SiRF binary.
	 */
	if (byte == SIRF_BIN_START) {
	  gpsc_state = GPSC_BOOT_EOS_WAIT;
	  call GpsTimer.startOneShot(T_CHAR_DELAY);
	  return;
#ifdef notdef
	  gpsm_state = GPSM_START_2;	// all good, looking for 2nd byte of start sequence
	  gpsc_state = GPSC_ON;		// Normal processing.  See if that works.
	  return;
#endif
	}

	/*
	 * not what we expected, reconfigure to 4800 and wack it.
	 */
	start_reconfig();
	return;

      case GPSC_RECONFIG_4800_FIRST_CHAR_WAIT:
	if (byte == NMEA_START) {
	  /*
	   * got the start char.  Keep receiving chars as long as the
	   * gps sends them.  This is a heuristic to find the end of the
	   * start up stream.  Is there a better way to tell?
	   */
	  gpsc_state = GPSC_RECONFIG_4800_EOS_WAIT;
	  call GpsTimer.startOneShot(T_CHAR_DELAY);
	  return;
#ifdef notdef
	  gpsc_state = GPSC_RECONFIG_SEND_WAIT;
	  call GpsTimer.startOneShot(T_GPS_FIRST_CHAR_TIME_OUT);
	  t_send_start = t;
	  call UartStream.send(nmea_go_sirf_bin, sizeof(nmea_go_sirf_bin));
	  return;
#endif
	}
	/*
	 * well that didn't work.  now what?
	 */
	call Panic.panic(PANIC_GPS, 3, byte, 0, 0, 0);
	return;

      case GPSC_BOOT_EOS_WAIT:
      case GPSC_RECONFIG_4800_EOS_WAIT:
	/*
	 * as long as we are receiving bytes keep reseting the timer
	 * Once the timer expires then we assume that we are at the
	 * end of the start up sequence.
	 *
	 * how expensive is this?
	 */
	call GpsTimer.startOneShot(T_CHAR_DELAY);
	return;

      case GPSC_RECONFIG_4800_PWR_DOWN:		// pwr off, shouldn't have any interrupts
      case GPSC_RECONFIG_1152_PWR_DOWN:		// pwr off, shouldn't have any interrupts
      default:
	call Panic.panic(PANIC_GPS, 99, gpsc_state, byte, 0, 0);
	nop();			// less confusing.
	break;
    }
  }


  async event void UartStream.sendDone( uint8_t* buf, uint16_t len, error_t error ) {
    t_send_done = call LocalTime.get();
    switch(gpsc_state) {
      case GPSC_RECONFIG_SEND_WAIT:
#ifdef notdef
	call Usart.disableIntr();
	gpsc_state = GPSC_RECONFIG_1152_PWR_DOWN;
	call HW.gps_off();
	call GpsTimer.startOneShot(T_CHAR_DELAY);
#endif
	break;

      case GPSC_BOOT_EOS_WAIT:
	switch(send_cmd) {
	  default:
	  case 0:
	    gpsc_state = GPSC_ON;
	  case 1:
	    break;
	  case 2:
	    break;
	  case 3:
	    break;
	}

      default:
	break;
    }
    return;
  }


  async event void UartStream.receiveDone( uint8_t* buf, uint16_t len, error_t error ) {
  }


  const msp430_uart_union_config_t gps_4800_serial_config = {
    {
       ubr:   UBR_4MHZ_4800,
       umctl: UMCTL_4MHZ_4800,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };

 
  const msp430_uart_union_config_t gps_57600_serial_config = {
    {
       ubr:   UBR_4MHZ_57600,
       umctl: UMCTL_4MHZ_57600,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };


  const msp430_uart_union_config_t gps_115200_serial_config = {
    {
       ubr:   UBR_4MHZ_115200,
       umctl: UMCTL_4MHZ_115200,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };


  /*
   * Called from within the Usart configurator.
   *
   * We default to 115200 assuming that the gps most likely will have been powered
   * and properly configured after initial boot.
   */
  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    mmP5out.ser_sel = SER_SEL_GPS;
    call HW.gps_on();
    gpsp_inst.t_pwr_on = call LocalTime.get();
    switch(gps_speed) {
      case 2:
	return (msp430_uart_union_config_t*) &gps_4800_serial_config;
      case 1:
	return (msp430_uart_union_config_t*) &gps_57600_serial_config;
      default:
	return (msp430_uart_union_config_t*) &gps_115200_serial_config;
    }
  }
}
