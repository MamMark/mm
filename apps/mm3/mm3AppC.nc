/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration mm3AppC {}
implementation {
  components MainC, mm3C;
  MainC.SoftwareInit -> mm3C;
  mm3C -> MainC.Boot;
  
  components RegimeC;
  mm3C.Regime -> RegimeC;
  
  components LedsC;
  mm3C.Leds -> LedsC;

  /*
   * Include sensor components.  No need to wire.  They will
   * start when regimeChange() is signalled.
   */
  //  components BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;
  components AccelC;
}
