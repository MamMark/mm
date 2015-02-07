/**
  Turns the red led on and off.  To step this in gdb I set breakpoints
  on all lines, then did a 'step' following by a 'next'.  For some reason,
  'step' by itself was a no-op.
 **/

module WiggleP  @safe() {
  uses interface Boot;
  uses interface GeneralIO as Port10;
  uses interface GeneralIO as Port11;
}
implementation {
  event void Boot.booted() {
    atomic {
      P1OUT = 0;
      P1IV = 0;
      P1IE  |= BIT4;
      P1DIR |= BIT4;			/* set b4 to output */
      P1SEL &= ~(BIT4);			/* force to digital i/o */
      P1IES = 0;			/* all rising edge ints */
      P1IFG = 0;
    }
    P1OUT |= BIT4;			/* should cause the interrupt */
  }

  task void wiggletask() {
    // turn the red led on and off
    call Port10.set();
    call Port10.clr();
    call Port10.set();
    call Port10.clr();

    // turn the green led on and off
    call Port11.set();
    call Port11.clr();
    call Port11.set();
    call Port11.clr();
  }

  TOSH_SIGNAL(PORT1_VECTOR) {
    /*
     * we don't clear the interrupt, so we should go infinite
     * just for fun
     */
    post wiggletask();
  }
}
