/**
 * Copyright @ 2008, 2010, 2017 Eric B. Decker
 * @author Eric B. Decker
 * @date 5/14/2010
 *
 * Configuration wiring for stream storage write (SSWrite).  See
 * SSWriteP for more details on how stream storage works.
 *
 * Stream storage is split phase and interfaces to a split phase
 * SD mass storage driver.
 */

#include "stream_storage.h"

configuration SSWriteC {
  provides {
    interface SSWrite as SSW;
    interface SSFull  as SSF;
  }
}

implementation {
  components SSWriteP as SS_P, MainC;
  SSW = SS_P;
  SSF = SS_P;
  MainC.SoftwareInit -> SS_P;

  components new SD0_ArbC() as SD;
  SS_P.SDResource -> SD;
  SS_P.SDwrite -> SD;

  components PanicC, LocalTimeMilliC;
  SS_P.Panic -> PanicC;
  SS_P.LocalTime -> LocalTimeMilliC;

  components TraceC, CollectC;
  SS_P.Trace    -> TraceC;
  SS_P.CollectEvent -> CollectC;

  components DblkManagerC;
  SS_P.DblkManager -> DblkManagerC;
}
