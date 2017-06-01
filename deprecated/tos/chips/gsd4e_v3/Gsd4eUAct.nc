interface Gsd4eUAct {
  command       void gpsa_change_speed();
  async command void gpsa_checking(uint8_t byte);
  async command void gpsa_configing(uint8_t byte);
  async command void gpsa_processing(uint8_t byte);
  command       void gpsa_ready();
  command       void gpsa_recv_complete();
  command       void gpsa_reset_mode();
  command       void gpsa_sc_done();
  command       void gpsa_send_check();
  command       void gpsa_send_complete();
  command       void gpsa_send_error();
  command       void gpsa_set_asleep();
  command       void gpsa_set_awake();
  command       void gpsa_start();
  command       void gpsa_start_config();
  command       void gpsa_stop();
  event         void gpsa_change_state(gpsc_state_t next_state, gps_where_t where);
  event         gpsc_state_t gpsa_get_state();
  event         void gpsa_poke_comm();
  async event   void gpsa_process_byte(uint8_t byte);
  async event   void gpsa_send_done(uint8_t* ptr, uint16_t len, error_t error);
  event         void gpsa_start_rx_timer(uint32_t t);
  event         void gpsa_start_tx_timer(uint32_t t);
  event         void gpsa_stop_rx_timer();
  event         void gpsa_stop_tx_timer();
}
