interface CoreTime {
  /**
   * start a syncronization cycle between the 32Ki ACLK and
   * the DCOCLK.
   */
  command void dcoSync();

  /**
   * excessiveSkew: check for too much skew.  Checks new rtcp
   *    against current time.  If the caller already has a copy
   *    of an already computed secs from a call to epoch it can
   *    pass that in for use by this routine.
   *
   * input:    *rtcp,   pointer to time to check
   *            cur_secs epoch secs, 0 if not set.
   *           *inp     pointer for incoming (new) secs computed
   *           *curp    pointer for current secs computed.
   *
   * returns:   0       no excessive skew (essentially FALSE).
   *            skew    excessive skew, value in secs of skew.
   *
   * computes epochs secs for time to be checked.  (in_secs)
   * if cur_secs is 0 then compute epoch_secs from cur_time.
   *
   * compare in_secs against cur_secs.  If too much skew,
   * return non-zero value of the skew otherwise 0.
   *
   * if inp and/or curp are non-zero, return the value of computed
   * secs from the respective times.
   */
  async command uint32_t excessiveSkew(rtctime_t *new_rtcp, uint32_t  cur_secs,
                                       uint32_t  *inp,      uint32_t *curp);

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
