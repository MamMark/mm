/**
 * Copyright @ 2010 Eric B. Decker, Carl Davis
 * @author Eric B. Decker
 * @author Carl Davis
 *
 * Configuration/wiring for SDsp (SD, split phase, event driven, no threads)
 *
 * read, write, and erase are for clients.
 *
 * Wire ResourceDefaultOwner so the DefaultOwner handles power up/down when not
 * clients are using the resource.
 *
 * SD_Arb provides an arbitrated interface for clients.  This is wired into
 * Msp430UsciShareB0P and is used as a dedicated SPI device.  We wire the
 * SDsp default owner code into Msp430UsciShareB0P so it can pwr the SD
 * up and down as it is used by clients.
 */

configuration SDspC {
  provides {
    interface SDread[uint8_t cid];
    interface SDwrite[uint8_t cid];
    interface SDerase[uint8_t cid];
    interface SDsa;
    interface SDraw;
  }
}

implementation {
  components SDspP;
  SDread   = SDspP;
  SDwrite  = SDspP;
  SDerase  = SDspP;
  SDsa     = SDspP;
  SDraw    = SDspP;

  components MainC;
  MainC.SoftwareInit -> SDspP;

  components PanicC;
  SDspP.Panic -> PanicC;

  components new TimerMilliC() as SDTimer;
  SDspP.SDtimer -> SDTimer;

  components SPI0_OwnerC;
  SDspP.ResourceDefaultOwner -> SPI0_OwnerC;
  SDspP.Usci -> SPI0_OwnerC;

  components Hpl_MM_hwC as HW;
  SDspP.HW -> HW;

  components LocalTimeMilliC as L;
  SDspP.lt -> L;
}
