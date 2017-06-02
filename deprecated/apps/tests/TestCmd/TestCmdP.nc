
module TestCmdP {
  uses {
    interface StdControl as CmdControl;
    interface Boot;
  }
}

implementation {
  event void Boot.booted() {
    call CmdControl.start();
  }
}
