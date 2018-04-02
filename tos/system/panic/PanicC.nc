/*
 * Copyright (c) 2008, 2012 Eric B. Decker
 * Copyright (c) 2017-2018, Eric B. Decker
 * @author Eric B. Decker
 */

#include "panic.h"

configuration PanicC {
  provides {
    interface Panic;
    interface PanicManager;
  }
}

implementation {
  components PanicP, PlatformC;
  Panic = PanicP;
  PanicManager = PanicP;
  PanicP.Rtc       -> PlatformC;
  PanicP.Platform  -> PlatformC;
  PanicP.SysReboot -> PlatformC;

  components PanicHelperP;

  components CollectC;
  PanicP.Collect -> CollectC;

  components FileSystemC as FS;
  PanicP.FS -> FS;

  components OverWatchC;
  PanicP.OverWatch -> OverWatchC;

  /* non-arbitrated, standalone SD used low level PANIC */
  components SD0C;
  PanicP.SDsa       -> SD0C;
  PanicP.SDraw      -> SD0C;

  /* arbitrated SD for use at task level */
  components new SD0_ArbC() as SD;
  PanicP.SDread     -> SD;
  PanicP.SDResource -> SD;

  components ChecksumM;
  PanicP.Checksum -> ChecksumM;
}
