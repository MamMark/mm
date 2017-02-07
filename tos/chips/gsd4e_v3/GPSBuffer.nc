interface GPSBuffer {
  async command       void     add_byte(uint8_t byte);
  async command       void     begin_NMEA_SUM();
  async command       void     begin_SIRF_SUM();
  async command       uint16_t end_SUM(int8_t correction);
  async command       void     msg_abort();
  async command       void     msg_complete();
  async command       void     msg_start();
}
