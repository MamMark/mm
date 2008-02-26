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

  components mm3RegimeC;
  mm3C.Regime -> mm3RegimeC;

  components mm3BattC, mm3TempC, mm3SalC, mm3AccelC, mm3PTempC,
    mm3PressC, mm3SpeedC, mm3MagC;
  mm3C.BattSense  -> mm3BattC;
  mm3C.TempSense  -> mm3TempC;
  mm3C.SalSense   -> mm3SalC;
  mm3C.AccelSense -> mm3AccelC;
  mm3C.PTempSense -> mm3PTempC;
  mm3C.PressSense -> mm3PressC;
  mm3C.SpeedSense -> mm3SpeedC;
  mm3C.MagSense   -> mm3MagC;


  components LedsC;
  mm3C.Leds -> LedsC;
}
