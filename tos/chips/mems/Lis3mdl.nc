interface Lis3mdl {
  /**
   * Get Device ID
   *
   * @return SUCCESS Device ID is available in id argument
   *
   *         EOFF Device is not powered on or selected
   * 
   */
  command error_t whoAmI(uint8_t *id);
}
