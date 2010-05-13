
module FSBootP {
  uses {
    interface Boot as InBoot;
    interface Boot as FiniBoot;
  }
  provides {
    interface Boot as OutBoot;
  }
}

implementation {
  event void InBoot.booted() {
    signal OutBoot.booted();
  }

  event void FiniBoot.booted() {
    nop();
  }
}
