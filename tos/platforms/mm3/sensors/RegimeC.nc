/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "regime.h"

configuration RegimeC {
  provides interface Regime;
}
implementation {
  components RegimeP;
  Regime = RegimeP;
}
