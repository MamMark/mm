configuration mm3AppC
{
}
implementation
{
  components MainC, mm3C;
  MainC.SoftwareInit -> mm3C;
  mm3C -> MainC.Boot;

  components HplMM3AdcC;
  mm3C.HW-> HplMM3AdcC.HplMM3Adc;

  components RegimeC;
  mm3C.Regime -> RegimeC;

  components BattC, TempC, SalC, AccelC, PTempC, PressC, SpeedC, MagC;
  mm3C.BattSense  -> BattC;
  mm3C.TempSense  -> TempC;
  mm3C.SalSense   -> SalC;
  mm3C.AccelSense -> AccelC;
  mm3C.PTempSense -> PTempC;
  mm3C.PressSense -> PressC;
  mm3C.SpeedSense -> SpeedC;
  mm3C.MagSense   -> MagC;

  components LedsC;
  mm3C.Leds -> LedsC;
}
