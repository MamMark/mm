
configuration TestTimerAppC {
}

implementation {
  components MainC, TestTimerC, LedsC;
  TestTimerC -> MainC.Boot;

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  TestTimerC.Timer0 -> Timer0;
  TestTimerC.Timer1 -> Timer1;
  TestTimerC.Timer2 -> Timer2;
}

