/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"
//#include "sensors.h"

configuration AdcC {
  provides interface Adc[uint8_t client_id];
}

implementation {
  components AdcP, MainC;
  Adc = AdcP;
  MainC.SoftwareInit -> AdcP;

  components HplMM3AdcC;
  AdcP.HW -> HplMM3AdcC;

  components new RoundRobinResourceQueueC(SENSOR_SENTINEL) as RR;
  AdcP.Queue -> RR;

  components new Alarm32khzC() as PA;
  AdcP.PowerAlarm -> PA;
}
