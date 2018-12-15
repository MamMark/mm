interface CoreTime {
  /**
   * start a syncronization cycle between the 32Ki ACLK and
   * the DCOCLK.
   */
  command void dcoSync();

  /**
   * Deep Sleep initialization.
   * perform needed functions to set up for deep sleep.
   */
  async command void initDeepSleep();

  /**
   * irq_preamble
   *
   * interrupt entry handler.
   */
  async command void irq_preamble();

  /*
   * used for debugging and checking R/PS sync
   */
  async command void verify();
  async command void log(uint16_t where);
  async command uint16_t get_ps();
}
