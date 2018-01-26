/*
 * Copyright (c) 2016 Eric B. Decker
 * All rights reserved.
 */

configuration LedsC {
  provides interface Leds;
}
implementation {
  components PlatformLedsC;

  Leds = PlatformLedsC;
}
