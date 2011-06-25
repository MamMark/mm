configuration Msp430ClockC {
  provides interface Init;
  provides interface Msp430ClockInit;
}

implementation {
  components Msp430ClockP, Msp430TimerC;

  Init = Msp430ClockP;
  Msp430ClockInit = Msp430ClockP;
}
