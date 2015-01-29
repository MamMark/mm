/*
 * test001
 *
 * bring clocks up
 *
 * toggle simple pin (P5.3)
 *
 * msp430-gcc -mdisable-watchdog -mmcu=msp430f5438a -o test001 test001.c
 * msp430-objcopy --output-target=ihex test001 test001.ihex
 */


/*
 * uniarch
 */
#include <msp430.h>
#include <inttypes.h>
#include "msp430f5438a.h"

typedef uint8_t bool;
#define TRUE  1
#define FALSE 0

/*
 * old-timey mspgcc4
 *
#include "io.h"
#include "msp430x54xx.h"
#include "msp430/common.h"
#include <isr_compat.h>
#include "signal.h"
*/

void setup_pins(void);
void init_board(void);
void timera_init(void);

int main(void)
{
  init_board();
  setup_pins();

  while(1) {
    P5OUT ^= 0x08;
  }

  timera_init();

  __enable_interrupt();

  // timer does not wake it from this...
  // LPM3;
}

/*
 * old-timey mspgcc4
 interrupt (TIMER0_A0_VECTOR) timera0_fired(void)
 */

/*
 *  uniarch
 */
__attribute__((interrupt(TIMER0_A0_VECTOR)))
  void timera0_fired(void)
{
  P5OUT ^= 0x08;
}

void timera_init(void)
{
  TA0CCTL0 = CCIE;                           // TRCCR0 interrupt enabled
  TA0CTL = TASSEL_1 | TAIE | TACLR;           // ACLK, upmode continuous
  TA0CCR0 = 1000;
  TA0CTL |= MC_2;

  TA0CCTL1 = CCIS0 | CCIE;
  TA0CCTL2 = 0;
}


#define XT1_DELTAS 16
uint16_t xt1_idx;
uint16_t xt1_deltas[XT1_DELTAS];
uint16_t xt1_cap;
bool cap;
uint16_t xt1_read;
uint16_t last_xt1, last_dco;

#define PWR_UP_SEC 16

uint16_t maj_xt1() {
  uint16_t a, b, c;

  a = TA0R; b = TA0R; c = TA0R;
  if (a == b) return a;
  if (a == c) return a;
  if (b == c) return b;
  while (1)
    nop();
  return 0;
}


void wait_for_32K() {
  uint16_t left;

  /*
   * TA0 -> XT1 32768   (just for fun and to compare against TA1 (1uis ticker)
   * TA1 -> SMCLK/1 (should be 1uis ticker)
   */
  TA0CTL = TACLR;			// also zeros out control bits
  TA1CTL = TACLR;
  TA0CTL = TASSEL__ACLK  | MC__CONTINOUS;	//  ACLK/1, continuous
  TA1CTL = TASSEL__SMCLK | MC__CONTINOUS;	// SMCLK/1, continuous

  /*
   * wait for about a sec for the 32KHz to come up and
   * stabilize.  We are guessing that it is stable and
   * on frequency after about a second but this needs
   * to be verified.
   *
   * FIX ME.  Need to verify stability of 32KHz.  It definitely
   * has a good looking waveform but what about its frequency
   * stability.  Needs to be measured.
   *
   * One thing to try is watching successive edges (ticks, TA0R, changing
   * by one) and seeing how many TA1 (1 uis) ticks have gone by.   When it is
   * around 30-31 ticks then we are in the right neighborhood.
   *
   * We should see about PWR_UP_SEC (16) * 64Ki * 1/1024/1024 seconds which just
   * happens to majikly equal 1 second.   whew!
   */

  xt1_cap = 16;
  left = PWR_UP_SEC;
  while (1) {
    if (TA1CTL & TAIFG) {
      /*
       * wrapped, clear IFG, and decrement major count
       */
      TA1CTL &= ~TAIFG;
      if (--left == 0)
        break;
      if (left <= xt1_cap) {
        cap = TRUE;
        xt1_cap = 0;			/* disable future capture triggers */
        xt1_idx = 0;
        last_xt1 = maj_xt1();
        last_dco = TA1R;
      }
    }
    if (cap) {
      xt1_read = maj_xt1();
      if (last_xt1 == xt1_read)
        continue;
      if (last_xt1 != xt1_read) {
        xt1_deltas[xt1_idx++] = TA1R - last_dco;
        last_xt1 = xt1_read;
        last_dco = TA1R;
        if (xt1_idx >= XT1_DELTAS) {
          cap = FALSE;
          nop();
        }
      }
    }
  }
  nop();
}


void setup_pins(void) {
  P5OUT = 0x00;
  P5DIR = 0x08;
  P5SEL = 0x00;   // 0 is iofunc

  /*
   * turn on XT1, 32KiHz, crystal and timing
   */
  P7SEL |= 3;
  UCSCTL6 &= ~(XT1OFF | XCAP_3);

  /* Disable FLL control */
  __bis_SR_register(SCG0);

  /*
   * Use XT1CLK as the FLL input: if it isn't valid, the module
   * will fall back to REFOCLK.  Use FLLREFDIV value 1 (selected
   * by bits 000)
   */
  UCSCTL3 = SELREF__XT1CLK;

  /*
   * The appropriate value for DCORSEL is obtained from the DCO
   * Frequency table of the device datasheet.  Find the DCORSEL
   * value from that table where the maximum frequency with DCOx=31
   * is closest to your desired DCO frequency.   (Where did this
   * come from?)   I've chosen next range up, don't want to run out
   * of head room.
   */

  UCSCTL0 = 0x0000;		     // Set lowest possible DCOx, MODx
  UCSCTL1 = DCORSEL_4;
  UCSCTL2 = FLLD_0 + 243;
  __bic_SR_register(SCG0);           // Enable the FLL control loop

  /*
   * ACLK is XT1/1, 32KiHz.
   * MCLK is set to DCOCLK/1.   8 MHz
   * SMCLK is set to DCOCLK/1.  8 MHz.
   * DCO drives TA1 for TMicro and is set to provide 1us ticks.
   * ACLK  drives TA0 for TMilli.  Jiffy clock (32KiHz)
   */
  UCSCTL4 = SELA__XT1CLK | SELS__DCOCLK | SELM__DCOCLK;
  UCSCTL5 = DIVA__1 | DIVS__1 | DIVM__1;

  /*
   * TA0 clocked off XT1, used for TMilli, 32KiHz.
   */
  TA0CTL = TASSEL__ACLK | TACLR | MC__CONTINOUS | TAIE;
  TA0R = 0;

  /*
   * TA1 clocked off SMCLK off DCO, /8, 1us tick
   */
  TA1CTL = TASSEL__SMCLK | ID__8 | TACLR | MC__CONTINOUS | TAIE;
  TA1R = 0;

  P11OUT = 0;
  P11DIR = 0x05;                           // ACLK, MCLK, SMCLK set out to pins
  P11SEL = 0x05;                           // P11.0,2 for debugging purposes.
}

void init_board(void) {
    SFRIE1 = 0;
    P1IE = 0;
    P2IE = 0;
    WDTCTL = WDTPW + WDTHOLD;              // Stop WDT
    TA0CTL = 0;
}
