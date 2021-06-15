/*
 * On board tmp sensor, addr 0x48.
 *
 * The tmp driver provides a parameterized singleton interface.  Currently
 * the bus is not arbitrated because we power up the onboard tmp, read it
 * then the external sensor.  There is no sense powering the tmps down
 * and there is no reason not to read the sensor together.
 *
 * Care must be taken to read the sensors in a reasonable fashion to avoid
 * conflicts.  The bus is not arbitrated.
 *
 * The sensors are typically turned off and there is only one pwr
 * bit that controls power to all sensors on the bus.
 */

configuration TmpPC {
  provides interface SimpleSensor<uint16_t>;
}

implementation {
  enum {
    TMP_ADDR   = 0x48,
  };

  components HplTmpC;
  SimpleSensor = HplTmpC.SimpleSensor[TMP_ADDR];
}
