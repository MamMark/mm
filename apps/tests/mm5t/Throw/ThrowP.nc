module ThrowP  @safe() {
  uses interface Boot;
  uses interface GpioInterrupt as Port14;
}
implementation {
  event void Boot.booted() {
    //    call Port14.disable();
  }

  async event void Port14.fired() {
  }
}
