interface L3g4200 {
  /**
   * Get Device ID
   *
   * @return SUCCESS Device ID is available in id argument
   *
   *         EOFF Device is not powered on or selected
   * 
   */
  command error_t whoAmI(uint8_t *id);

  /**
   * Configure for Gyro XYZ 1Hz Sample Rate
   */
  command error_t config100Hz();

  /**
   * Check for sample availability
   */
  command bool xyzDataAvail();

  /**
   * Read an XYZ sample
   */
  command error_t readSample(uint8_t *buf, uint8_t bufLen);
}
