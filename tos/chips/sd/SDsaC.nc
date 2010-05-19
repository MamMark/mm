/**
 * Copyright @ 2010 Eric B. Decker, Carl Davis
 * @author Eric B. Decker
 * @author Carl Davis
 *
 * Configuration/wiring for SDsa (SD, standalone)
 *
 * read, write, and erase are for clients.
 * reset is only used by the power manager so isn't parameterized.  There should
 * be only one module that wires to it.  At some point add a exactly_once clause.
 */

configuration SDsaC {
  provides interface SDsa;
}

implementation {
  components SDsaP;
  SDsa = SDsaP;

  components SDspC;
  SDsaP.SDraw -> SDspC;

  components HplMsp430UsciB0C as UsciC;
  SDsaP.Usci -> UsciC;

  components Hpl_MM_hwC as HW;
  SDsaP.HW -> HW;
}
