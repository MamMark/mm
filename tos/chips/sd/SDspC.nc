/**
 * Copyright @ 2010 Eric B. Decker, Carl Davis
 * @author Eric B. Decker
 * @author Carl Davis
 *
 * Configuration/wiring for SDsp (SD, split phase, event driven, no threads)
 *
 * read, write, and erase are for clients.
 * reset is only used by the power manager so isn't parameterized.  There should
 * be only one module that wires to it.  At some point add a exactly_once clause.
 */

configuration SDspC {
  provides {
    interface SDreset;
    interface SDread[uint8_t cid];
    interface SDwrite[uint8_t cid];
    interface SDerase[uint8_t cid];
    interface SDraw;
  }
}

implementation {
  components SDspP;
  SDreset = SDspP;
  SDread  = SDspP;
  SDwrite = SDspP;
  SDerase = SDspP;
  SDraw   = SDspP;

  components PanicC;
  SDspP.Panic -> PanicC;

  components new TimerMilliC() as SDTimer;
  SDspP.SDtimer -> SDTimer;

  components HplMsp430UsciB0C as UsciC;
  SDspP.Umod -> UsciC;
//  SDspP.UsciInterrupts -> UsciC;

  components LocalTimeMilliC as L;
  SDspP.lt -> L;
}
