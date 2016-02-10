interface Lis3mdl {
  command error_t whoAmI();
  event void whoAmIDone(error_t status, uint8_t id);
}
