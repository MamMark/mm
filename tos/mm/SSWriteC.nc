/**
 * Copyright @ 2008, 2010, 2017 Eric B. Decker
 * @author Eric B. Decker
 * @date 5/14/2010
 *
 * Configuration wiring for stream storage write (SSWrite).  See
 * SSWriteP for more details on how stream storage works.
 *
 * StreamStorageWrite is split phase and interfaces to a split phase
 * SD mass storage driver.
 */

#include "stream_storage.h"

configuration SSWriteC {
  provides {
    interface SSWrite       as SSW;
    interface StreamStorage as SS;
  }
}

implementation {
  components SSWriteP as SSW_P, MainC;
  SSW = SSW_P;
  SS  = SSW_P;
  MainC.SoftwareInit -> SSW_P;

  components new SD0_ArbC() as SD;
  components SD0C;
  SSW_P.SDResource -> SD;
  SSW_P.SDwrite    -> SD;
  SSW_P.SDsa       -> SD0C;

  components PanicC, LocalTimeMilliC;
  SSW_P.Panic      -> PanicC;
  SSW_P.LocalTime  -> LocalTimeMilliC;

  components TraceC, CollectC;
  SSW_P.Trace        -> TraceC;
  SSW_P.CollectEvent -> CollectC;

  components DblkManagerC;
  SSW_P.DblkManager -> DblkManagerC;
}
