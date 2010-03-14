/**
 * Copyright @ 2008, 2010 Eric B. Decker
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

  components Hpl_MM_hwC;
  AdcP.HW -> Hpl_MM_hwC;

  components new RoundRobinResourceQueueC(MM_NUM_SENSORS) as RR;
  AdcP.Queue -> RR;

  components new Alarm32khzC() as PA;
  AdcP.PowerAlarm -> PA;

  components PanicC;
  AdcP.Panic -> PanicC;

  components HplMsp430UsciB1C as UsciC;
  AdcP.Usci -> UsciC;
  AdcP.UsciInterrupts -> UsciC;
}
