/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

//#include "hardware.h"

configuration PwrC {
  provides interface Pwr[uint8_t client_id];
}

implementation {
  components PwrP;

  Pwr = PwrP;
}
