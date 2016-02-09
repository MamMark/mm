/*
 * LedRailAppC
 *
 * Test the PowerRail interface and Regulator module implementation
 */

configuration LedRailAppC {
}
implementation {
  components MainC, LedRailP, Pwr3V3C, LedsC;
  components new TimerMilliC() as Timer0;

  LedRailP.Boot -> MainC.Boot;
  LedRailP.Timer0 -> Timer0;
  LedRailP.PwrReg -> Pwr3V3C;
  LedRailP.Leds -> LedsC;
}
