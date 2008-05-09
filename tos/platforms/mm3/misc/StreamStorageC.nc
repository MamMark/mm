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
  }
  uses interface Boot;
}

implementation {
  components StreamStorageP as SSP, MainC;
  SS = SSP;
  MainC.SoftwareInit -> SSP;

  components new BlockingBootC();
  BlockingBootC -> SSP.BlockingBoot;

  Boot = SSP.Boot;
  SSBoot = BlockingBootC;

  /*
   * Not sure of the stack size needed here
   * If things seems to break make it bigger...
   *
   * We need to implement stack guards
   * This will also give us an idea of how deep the stacks have been
   */

  components new ThreadC(300); 
  SSP.Thread -> ThreadC;
  
  components SemaphoreC;
  SSP.Semaphore -> SemaphoreC;

  
  components new Msp430Spi1C() as SpiC;
  components new BlockingResourceC();
  BlockingResourceC.Resource -> SpiC;
  SSP.BlockingSPIResource -> BlockingResourceC;

  components SDC;
  SSP.SD -> SDC;

  components PanicC;
  SSP.Panic -> PanicC;

  components HplMM3AdcC;
  SSP.HW -> HplMM3AdcC;
}
