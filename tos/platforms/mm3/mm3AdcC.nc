/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"
//#include "sensors.h"

configuration mm3AdcC {
  provides interface mm3Adc[uint8_t client_id];
}

implementation {
  components mm3AdcP, MainC;
  mm3Adc = mm3AdcP;
  MainC.SoftwareInit -> mm3AdcP;

  components HplMM3AdcC;
  mm3AdcP.HW -> HplMM3AdcC;

  components new RoundRobinResourceQueueC(SENSOR_SENTINEL) as RR;
  mm3AdcP.Queue -> RR;

  components new TimerMilliC() as PT;
  mm3AdcP.PowerTimer -> PT;
}
