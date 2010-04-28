
configuration TestTimerC {
}

implementation {
  components TestTimerP as App;
  components MainC, LedsC;
  App -> MainC.Boot;

  components new TimerMilliC() as Timer0;
  components new TimerMilliC() as Timer1;
  components new TimerMilliC() as Timer2;
  App.Timer0 -> Timer0;
  App.Timer1 -> Timer1;
  App.Timer2 -> Timer2;
}
