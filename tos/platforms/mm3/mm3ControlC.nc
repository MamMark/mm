/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration mm3ControlC {
  provides interface mm3Control;
}

implementation {
  components mm3ControlP, MainC;
  mm3Control = mm3ControlP;
  MainC.SoftwareInit -> mm3ControlP;

  components PanicC;
  mm3ControlP.Panic -> PanicC;
}
