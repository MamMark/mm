/*
 * Copyright (c) 2008, 2019, Eric B. Decker
 * All rights reserved.
 */

configuration RegimeC {
  provides interface Regime;
}
implementation {
  components RegimeP;
  Regime = RegimeP;
}
