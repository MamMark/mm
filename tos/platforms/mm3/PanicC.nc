/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration PanicC {
  provides interface Panic;
}

implementation {
  components PanicP, MainC;
  Panic = PanicP;
  MainC.SoftwareInit -> PanicP;
}
