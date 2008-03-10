#ifndef _H_hardware_h
#define _H_hardware_h

/*
 * This is the do nothing layer for use on the TelosB.  It makes the
 * h/w interface layer do nothing.
 */

#include "msp430hardware.h"

/*
 * Use the led pins as defined on the telosb
 */
TOSH_ASSIGN_PIN(RED_LED,    5, 4);
TOSH_ASSIGN_PIN(GREEN_LED,  5, 5);
TOSH_ASSIGN_PIN(YELLOW_LED, 5, 6);


// need to undef atomic inside header files or nesC ignores the directive
#undef atomic

void TOSH_MM3_B_PIN_STATE(void) {
  atomic {
    SVSCTL = 0;			/* for now, disable SVS */
    U0CTL = SWRST;		/* hold USART0 in reset */
    U1CTL = SWRST;		/* and  USART1 as well  */
    ME1 = 0;
    ME2 = 0;

    TOSH_MAKE_RED_LED_OUTPUT();
    TOSH_MAKE_GREEN_LED_OUTPUT();
    TOSH_MAKE_YELLOW_LED_OUTPUT();
  }
}

#endif // _H_hardware_h
