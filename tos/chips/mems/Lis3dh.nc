interface Lis3dh {
  command uint8_t whoAmI();
  command void    config1Hz();
  command bool    xyzDataAvail();
  command void    readSample(uint8_t *buf, uint8_t bufLen);
}
