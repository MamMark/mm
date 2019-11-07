interface CoreTime {
  /**
   * start a syncronization cycle between the 32Ki ACLK and
   * the DCOCLK.
   */
  command void dcoSync();

  /**
   * excessiveSkew: check for too much skew.  Checks *new_rtcp against
   *    current time.
   *
   *    returns TRUE if skew between current time and new time is too much,
   *            FALSE otherwise.
   *    delta is computed via new_secs - cur_secs.  If new time is in the
   *    future delta will be positive.
   *
   *    cur_secsp, new_secsp, and deltap are used to pass back values set
   *    by the routine.
   *
   * input:    *new_rtcp, pointer to time to check
   *           *new_secsp pointer to cell for calculated new_sec
   *           *cur_secsp ditto
   *           *deltap    pointer to cell for calculated delta
   *
   * returns:   FALSE   no excessive skew.
   *            TRUE    excessive skew, value in secs of skew.
   *           *cur_secsp  if non-NULL, filled in with calculated values.
   *           *new_secsp
   *           *delta1000p if non-NULL, filled in with calculated skew.
   *
   * computes delta (secs,us) between new rtc time and current rtc time.
   * epochs are fixed point integer tuples, (secs, usecs).  Each housed
   * in 32 bit numbers.
   *
   * Delta returned is delta * 1000, fixed point with ms in the lower 3
   * digits (base 10).
   *
   * skew = new - cur.  If new is in the future we will have positive skew.
   */
  async command bool excessiveSkew(rtctime_t *new_rtcp, uint32_t *new_secsp,
                                   uint32_t *cur_secsp, int32_t *delta1000p);

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
