/* -*- mode:c; indent-tabs-mode: nil; c-basic-offset: 2 -*-
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

configuration mm3RegimeC {
  provides interface mm3Regime;
}
implementation {
  components MainC, mm3RegimeP;
  MainC.SoftwareInit -> mm3RegimeP;
  mm3Regime = mm3RegimeP;
}
