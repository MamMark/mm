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

  components StreamStorageC;
  SDspP.BlockingSpiPacket -> StreamStorageC;

  components new TimerMilliC() as T0;
  SDspP.SD_reset_timer -> T0;

  components new TimerMilliC() as T1;
  SDspP.SD_read_timer -> T1;

  components HplMsp430UsciB0C as UsciC;
  SDspP.Umod -> UsciC;
  SDspP.UsciInterrupts -> UsciC;
}
