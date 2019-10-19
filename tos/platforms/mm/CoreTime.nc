interface CoreTime {
  /**
   * start a syncronization cycle between the 32Ki ACLK and
   * the DCOCLK.
   */
  command void dcoSync();

  /**
   * excessiveSkew: check for too much skew.  Checks *new_rtcp against
   *    current time.  If the caller already has a copy of epoch secs
   *    computed it can be passed in via cur_secs.
   *
   *    returns TRUE if skew from current time is too much, false otherwise.
   *    delta is computed via new_secs - cur_secs.  If new time is in the
   *    future delta will be positive.
   *
   *    cur_secsp, new_secsp, and deltap are used to pass back values set
   *    by the routine.
   *
   * input:    *new_rtcp, pointer to time to check
   *            cur_secs  epoch secs, 0 if not set.
   *           *cur_secsp pointer to cell for calulated cur_sec
   *           *new_secsp ditto
   *           *deltap    pointer to cell for calculated delta
   *
   * returns:   false   no excessive skew.
   *            true    excessive skew, value in secs of skew.
   *           *deltap  if non-NULL, filled in with calculated skew.
   *
   * computes epochs secs for time to be checked.  if cur_secs is 0 then
   * compute cur_secs from cur_time (epoch).  Calculate delta_sec as
   * new_secs - cur_secs.
   */
  async command bool excessiveSkew(rtctime_t *new_rtcp, uint32_t  cur_secs,
                                   uint32_t *cur_secsp, uint32_t *new_secsp,
                                   int32_t   *deltap);

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
