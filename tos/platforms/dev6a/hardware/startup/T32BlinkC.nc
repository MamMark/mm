
configuration T32BlinkC { }
implementation {
  components T32BlinkP, MainC, McuSleepC;
  T32BlinkP -> MainC.Boot;
  T32BlinkP.McuSleep -> McuSleepC;
}
