/*
 * Control 3V3 power regulator
 */

configuration Pwr3V3C {
  provides interface PwrReg;
}
implementation {
  components Pwr3V3P;
  components new TimerMilliC() as VoutTimer;
  components LedsC as Enable;

  PwrReg = Pwr3V3P;

  Pwr3V3P.VoutTimer -> VoutTimer;
  Pwr3V3P.Enable -> Enable;
}
