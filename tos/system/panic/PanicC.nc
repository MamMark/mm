/*
 * Copyright (c) 2008, 2012 Eric B. Decker
 * Copyright (c) 2017, Eric B. Decker
 * @author Eric B. Decker
 */

#include "panic.h"

configuration PanicC {
  provides interface Panic;
}

implementation {
  components PanicP, PlatformC;
  Panic = PanicP;
  PanicP.Platform  -> PlatformC;
  PanicP.SysReboot -> PlatformC;

  components PanicHelperP;

  components CollectC;
  PanicP.Collect -> CollectC;

  components FileSystemC as FS;
  PanicP.FS -> FS;

  components LocalTimeMilliC;
  PanicP.LocalTime -> LocalTimeMilliC;

  components OverWatchC;
  PanicP.OverWatch -> OverWatchC;

  components SD0C, SSWriteC;
  PanicP.SSW   -> SSWriteC;
  PanicP.SDsa  -> SD0C;
  PanicP.SDraw -> SD0C;

  components ChecksumM;
  PanicP.Checksum -> ChecksumM;
}
