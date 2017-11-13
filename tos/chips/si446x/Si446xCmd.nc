/**
  * The interface for Si446x Radio Chip Low level access.
  *
  * This interface abstracts the low level radio chip input/output operations
  * into a set of basic commands for controlling chip functionality.
  * Though primarily a set of commands, one event is included to manage the hardware
  * interrupt operation.
  *
  * All access to the SPI interface is performed within this interface, though the
  * acquisition of the arbiter not. It is assumed that the SPI port is dedicated to
  * the radio chip.
  *
  * All access to chip-related MSP hardware (GPIO, etc) is handled within this interface
  * as well and exposed as abstracted commands.
  *
  * @author Dan Maltbie
  * @date   March 1 2016
  */

#include "trace.h"

interface Si446xCmd {
  /**
   * force radio chip to change to specific state.
   *
   * @param     state         desired radio chip state
   * @param     wait          true if need to wait for command processing to complete
   */
  async command si446x_device_state_t change_state(si446x_device_state_t state, bool wait);

  /**
   * Perform Clear Channel Assessment.
   *
   * @return     true if channel is clear (no other radio transmission detected)
   */
  async command bool          check_CCA();

  /**
   * Clear radio chip select.
   */
  async command void          clr_cs();

  /**
   * Configure the Fast Response Registers to the expected values
   *
   * Configures the radio chip to return the specific values used by the Driver. See
   * si446x_frr_info_t structure in si446x.h for details.
   */
  async command void          config_frr();

  /**
   * Disable radio chip hardware interrupt.
   */
  async command void          disableInterrupt();

  /**
   * Dump all of the current radio chip configuration.
   */
  async command void          dump_radio();

  /**
   * Enable radio chip interrupt.
   */
  async command void          enableInterrupt();

  /**
   * Get current state of the radio chip using fast read register.
   *
   * @return        device state as read from the fast read register
   */
  async command uint8_t       fast_device_state();

  /**
   * Read the fast response register that holds packet handler pending interrupt flags
   *
   * @return        pending interrupt flags for packet handler
   */
  async command uint8_t       fast_ph_pend();

  /**
   * Read the fast response register that holds modem pending interrupt flags
   *
   * @return        pending interrupt flags for modem
   */
  async command uint8_t       fast_modem_pend();

  /**
   * Read the fast response register that holds radio receive signal strength indicator
   *
   * The radio chip measures the receive signal strength during the beginning of receiving
   * a packet, and latches this value. This value is used by the radio chip to compare
   * with the configured threshold for acceptable receive signal strength for valid packet.
   *
   * @return        latched value for the RSSI
   */
  async command uint8_t       fast_latched_rssi();

  /**
   * Read all four fast response registers
   *
   * @param     status        pointer to buffer for holding the FRR values
   */
  async command void          fast_all(uint8_t *status);

  /**
   * Get information about the current tx/rx fifo depths and optionally flush.
   *
   * @param    rxp           pointer to word to return rx fifo count
   * @param    txp           pointer to word to return tx fifo count
   * @param    flush_bits    flags for flushing rx and/or tx fifos
   */
  async command void          fifo_info(uint16_t *rxp, uint16_t *txp, uint8_t flush_bits);

  /**
   * Get a list of configuration lists.
   *
   * Get a list of pointers, each pointing to a list (array) of configuration strings
   * formated appropiately for the send_cmd routine.  This includes a list of the
   * configuration strings generated by the WDS program as well as local configuration
   * specific to the radio driver.
   *
   * @return    a list of configuration string lists (list of list of string)
   */
  async command uint8_t    ** get_config_lists();

  /**
   * Get current state radio chip command processor.
   *
   * @return        true of processor has completed processing of previous command
   */
  async command bool          get_cts();

  /**
   * Read the fast response register that holds modem pending interrupt flags
   *
   * @return        pending interrupt flags for modem
   */
  async command uint16_t      get_packet_info();


  /**
   * Signal that the radio chip has asserted its hardware interrupt.
   */
  async event void            interrupt();

  /**
   * Clear all of the radio chip pending interrupts.
   *
   * Clears all pending interrupts in the radio chip. This should also negate the radio chip
   * interrupt pin. This is a low overhead (ll_) routine.
   */
  async command void          ll_clr_ints(uint8_t ph_clr, uint8_t modem_clr, uint8_t chip_clr);

  /**
   * Clear all of the radio chip pending interrupts return pending status (prior to clear).
   *
   * #param     intp          pointer to buffer for interrupt pending results
   */
  async command void          ll_getclr_ints(volatile si446x_int_clr_t *int_clr_p,
                                             volatile si446x_int_state_t *int_stat_p);

  /**
   * Turn radio chip power on.
   */
  async command void          power_up();

  /**
   *
   * Read one or more contiguous radio chip properties
   *
   * @param     p_id          property identifier
   * @param     num           number of properties to read
   * @param     rsp_p         pointer to string to hold read results
   */
  async command void          read_property(uint16_t p_id, uint16_t num, uint8_t *rsp_p);

  /**
   * Read data from the radio chip receive fifo.
   *
   * @param    data          pointer to buffer where to place the data from receive fifo
   * @param    length        number of bytes to read from the fifo
   */
  async command void          read_rx_fifo(uint8_t *data, uint8_t length);


  /**
   *
   * set one or more contiguous radio chip properties 
   *
   * @param     prop          property index
   * @param     values        ptr to string holding values to write
   * @param     vl            length of values string
   */
  async command void          set_property(uint16_t prop, uint8_t *values, uint16_t vl);

  /**
   * Send a config string to the radio chip.
   *
   * @param    properties    pointer to string to send
   * @param    length        length of properties string to send
   */
  async command void          send_config(const uint8_t *properties, uint16_t length);

  /**
   * Power off the radio chip.
   */
  async command void          shutdown();

  /**
   * Transition the radio chip to the receive enabled state.
   *
   * Waits for the radio chip to report that the command processing has been completed.
   */
  async command void          start_rx();

  /**
   * Transition the radio chip to the receive enabled state.
   *
   * Doesn't reload settings (should have been previously loaded with the last start_rx() command.
   * Waits for the radio chip to report that the command processing has been completed.
   */
  async command void          start_rx_short();

  /**
   * Transition the radio chip to the transmit state.
   *
   * @param    data           total length of packet to send.
   */
  async command void          start_tx(uint16_t len);

  /**
   * Add entry to system trace.
   *
   * @param    where          identifies where trace is called from
   * @param    r0             argument 0
   * @param    r1             argument 1
   */
  async command void          trace(trace_where_t where, uint16_t r0, uint16_t r1);

  /**
   * Read the radio pending status, using fast registers.
   *
   * @param     pend          pointer to buffer for returning the FFR values read
   */
  async command void          trace_radio_pend(uint8_t *pend);

  /**
   * Power on the radio chip.
   */
  async command void          unshutdown();

  /**
   * Write data into the radio chip transmit fifo.
   *
   * @param    data          pointer to data to place in fifo
   * @param    length        length of data to place in fifo
   */
  async command void          write_tx_fifo(uint8_t *data, uint8_t length);
}
