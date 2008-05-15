/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 * @date 5/8/2008
 *
 * Configuration wiring for StreamStorage.  See StreamStorageP for
 * more details on what StreamStorage does.
 *
 * Threaded TinyOS 2 implementation.
 */

#include "stream_storage.h"

configuration StreamStorageC {
  provides {
    interface Boot as SSBoot;
    interface StreamStorage as SS;
    interface BlockingSpiPacket;
  }
  uses interface Boot;
}

implementation {
  components StreamStorageP as SS_P, MainC;
  SS = SS_P;
  MainC.SoftwareInit -> SS_P;

  components new BlockingBootC();
  BlockingBootC -> SS_P.BlockingBoot;

  Boot = SS_P.Boot;
  SSBoot = BlockingBootC;

  /*
   * Not sure of the stack size needed here
   * If things seems to break make it bigger...
   *
   * We need to implement stack guards
   * This will also give us an idea of how deep the stacks have been
   */

  components new ThreadC(300);
  SS_P.SSThread -> ThreadC;
  
  components SemaphoreC;
  SS_P.Semaphore -> SemaphoreC;

  components new mm3BlockingSpi1C() as SpiC;
//  components new BlockingResourceC();
//  BlockingResourceC.Resource -> SpiC;
  SS_P.BlockingSPIResource -> SpiC;
  SS_P.ResourceConfigure <- SpiC;
  SS_P.SpiResourceConfigure -> SpiC;
  BlockingSpiPacket = SpiC;

  components SDC;
  SS_P.SD -> SDC;

  components PanicC;
  SS_P.Panic -> PanicC;

  components HplMM3AdcC;
  SS_P.HW -> HplMM3AdcC;

  components LocalTimeMilliC;
  SS_P.LocalTime -> LocalTimeMilliC;
}
