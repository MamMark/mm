/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
*/

#include "panic.h"

configuration PanicC {
  provides interface Panic;
}

implementation {
  components PanicP, MainC;
  Panic = PanicP;
  MainC.SoftwareInit -> PanicP;

  components LocalTimeMilliC, CollectC;
  PanicP.LocalTime -> LocalTimeMilliC;
  PanicP.Collect -> CollectC;

  components SDspP;
  PanicP.SDsa -> SDspP;

  components SSWriteC;
  PanicP.SSW -> SSWriteC;
}
