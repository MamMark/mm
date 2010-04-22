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
    interface StreamStorageWrite as SSW;
    interface StreamStorageRead  as SSR[uint8_t client_id];
    interface StreamStorageFull  as SSF;
//    interface SpiPacket;
  }
  uses interface Boot;
}

implementation {
  components StreamStorageP as SS_P, MainC;
  SSW = SS_P;
  SSR = SS_P;
  SSF = SS_P;
  MainC.SoftwareInit -> SS_P;

  components new BlockingBootC();
  BlockingBootC -> SS_P.BlockingBoot;

  Boot = SS_P.Boot;
  SSBoot = BlockingBootC;

  components new mmSpi0C() as SpiWrite;
  components new mmSpi0C() as SpiRead;
  SS_P.WriteResource -> SpiWrite;
  SS_P.ReadResource  -> SpiRead;
  SS_P.ResourceConfigure <- SpiWrite;
  SS_P.ResourceConfigure <- SpiRead;
  SS_P.SpiResourceConfigure -> SpiWrite;
//  SpiPacket = SpiWrite;

//  components new BlockingResourceC();
//  BlockingResourceC.Resource -> SpiC;

  components SDspC, PanicC, Hpl_MM_hwC, LocalTimeMilliC;
  SS_P.SDreset -> SDspC;
  SS_P.SDread  -> SDspC;
  SS_P.SDwrite -> SDspC;
  SS_P.SDerase -> SDspC;
  SS_P.Panic -> PanicC;
  SS_P.HW -> Hpl_MM_hwC;
  SS_P.LocalTime -> LocalTimeMilliC;

  components TraceC, CollectC;
  SS_P.Trace    -> TraceC;
  SS_P.LogEvent -> CollectC;
}
