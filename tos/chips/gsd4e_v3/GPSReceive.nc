interface GPSReceive {
  async event   void       receive(gps_msg_t *msg);
  command       void       recv_done(gps_msg_t *msg);
}
