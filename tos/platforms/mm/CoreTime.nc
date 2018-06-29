interface CoreTime {
  /*
   * start a syncronization cycle between the 32Ki ACLK and
   * the DCOCLK.
   */
  async command void dcoSync();
}
