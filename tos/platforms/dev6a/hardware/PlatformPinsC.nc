/*
 * Copyright (c) 2016 Eric B. Decker
 * All rights reserved.
 */

#include "msp432usci.h"

/*
 * Do any initilization for Gpio Pins in the system.
 *
 * Initial setting of the pin state is handled by __pin_init()
 * in startup.c.
 *
 * This module simply enables any Ports that need interrupts on
 * them.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

configuration PlatformPinsC {
} implementation {
  components PlatformC;
  components PlatformPinsP;

  PlatformC.PeripheralInit      -> PlatformPinsP;
}
