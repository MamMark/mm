/**
 * Copyright @ 2010 Eric B. Decker, Carl Davis
 * @author Eric B. Decker
 * @author Carl Davis
 *
 * Configuration/wiring for SD_nt (SD, no threads, fully event driven)
 */

configuration SDspC {
  provides {
    interface SDreset;
    interface SDread;
    interface SDwrite;
    interface SDerase;
  }
}
implementation {
  components SDspP, MainC;
  SDreset = SDspP;
  SDread  = SDspP;
  SDwrite = SDspP;
  SDerase = SDspP;
  MainC.SoftwareInit -> SDspP;

  components PanicC;
  SDspP.Panic -> PanicC;

  components new TimerMilliC() as SDTimer;
  SDspP.SDtimer -> SDTimer;

  components HplMsp430UsciB0C as UsciC;
  SDspP.Umod -> UsciC;
  SDspP.UsciInterrupts -> UsciC;

  components LocalTimeMilliC as L;
  SDspP.lt -> L;
}
