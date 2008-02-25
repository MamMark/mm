
#define MM3_PWR   "mm3Pwr_Resource"

configuration mm3AppC
{
}
implementation
{
  components MainC, mm3C;
  mm3C -> MainC.Boot;
  MainC.SoftwareInit -> mm3C;

  components HplMM3AdcC;
  mm3C.HW-> HplMM3AdcC.HplMM3Adc;

  components mm3RegimeC;
  mm3C.Regime -> mm3RegimeC;

#ifdef notdef
  components mm3PwrC;
  mm3C.C1 -> mm3PwrC.mm3Pwr[1];
  mm3C.C2 -> mm3PwrC.mm3Pwr[2];
#endif

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

  enum {
    SENSOR_NONE = unique(MM3_PWR),
    SENSOR_ONE  = unique(MM3_PWR),
    SENSOR_TWO  = unique(MM3_PWR),
  };


  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
//  components new Alarm32khz32C() as Alarm2;
  mm3C.Timer1 -> Timer1;
  mm3C.Timer2 -> Timer2;
//  mm3C.Alarm2 -> Alarm2;

  components LedsC;
  mm3C.Leds -> LedsC;

  components RandomMlcgC;
  mm3C.Random   -> RandomMlcgC;
  mm3C.SeedInit -> RandomMlcgC;
}
