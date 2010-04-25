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
    interface StreamStorageWrite as SSW;
    interface StreamStorageFull  as SSF;
  }
}

implementation {
  components StreamStorageP as SS_P, MainC;
  SSW = SS_P;
  SSF = SS_P;
  MainC.SoftwareInit -> SS_P;

  components new SD_ArbC() as SD;
  SS_P.WriteResource -> SD;

  components SDspC, PanicC, LocalTimeMilliC;
  SS_P.SDwrite -> SDspC;
  SS_P.Panic -> PanicC;
  SS_P.LocalTime -> LocalTimeMilliC;

  components TraceC, CollectC;
  SS_P.Trace    -> TraceC;
  SS_P.LogEvent -> CollectC;

  components FileSystemC as FS;
  SS_P.FS -> FS;
}
