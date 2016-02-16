interface MemsCtrl {
  command error_t spiRx(uint8_t addr, uint8_t *buf, uint8_t len,
			bool mult_addr);
  command error_t spiTx(uint8_t addr, uint8_t *buf, uint8_t len,
			bool mult_addr);
  command error_t readReg(uint8_t addr, uint8_t *val);
  command error_t writeReg(uint8_t addr, uint8_t val);
  command error_t modifyReg(uint8_t addr, uint8_t clear_bits, uint8_t set_bits);
}
