/*
 * Copyright (c) 2008, 2019, Eric B. Decker
 * All rights reserved.
 */

/*
 * regime.h defines what the different regimes look like.
 * It is a platform dependent file and typically lives in
 * tos/platforms/<platform>/hardware/sensors
 */

#include "regime.h"

configuration RegimeC {
  provides interface Regime;
}
implementation {
  components RegimeP;
  Regime = RegimeP;
}
