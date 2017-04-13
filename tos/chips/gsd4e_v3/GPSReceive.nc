interface GPSReceive {
  async event   void       receive(uint8_t *msg, uint16_t len);
  command       void       receive_done(uint8_t *msg, uint16_t len);
}
