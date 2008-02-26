/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration RegimeC {
  provides interface Regime;
}
implementation {
  components MainC, RegimeP;
  MainC.SoftwareInit -> RegimeP;
  Regime = RegimeP;
}
