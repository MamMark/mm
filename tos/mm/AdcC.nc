/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration AdcC {
  provides interface Adc[uint8_t client_id];
  uses interface StdControl as SensorPowerControl[uint8_t id];
}

implementation {
  components AdcP, MainC;
  Adc = AdcP;
  SensorPowerControl = AdcP;
  MainC.SoftwareInit -> AdcP;

  components HplMM3AdcC;
  AdcP.HW -> HplMM3AdcC;

  components new RoundRobinResourceQueueC(MM_NUM_SENSORS) as RR;
  AdcP.Queue -> RR;

  components new Alarm32khzC() as PA;
  AdcP.PowerAlarm -> PA;

  components PanicC;
  AdcP.Panic -> PanicC;
}
