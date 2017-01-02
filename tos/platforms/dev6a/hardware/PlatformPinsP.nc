module PlatformPinsP {
  provides interface Init;
}
implementation {
  command error_t Init.init() {

    /*
     * clear any pendings.
     *
     * PA, PB, and PC, cover the 1st 6 8 bit ports.
     */
    PA->IFG = 0;                /* P1 and P2 */
    PB->IFG = 0;                /* P3 and P4 */
    PC->IFG = 0;                /* P5 and P6 */

    /*
     * Enable NVIC interrupts for any Ports that interrupts occur on.
     *
     * This does not enable the actual interrupt.  Still controlled via IE
     * on each Port bit
     */
    NVIC_EnableIRQ(PORT1_IRQn);
    NVIC_EnableIRQ(PORT2_IRQn);
    NVIC_EnableIRQ(PORT3_IRQn);
    NVIC_EnableIRQ(PORT4_IRQn);
    NVIC_EnableIRQ(PORT5_IRQn);
    NVIC_EnableIRQ(PORT6_IRQn);

    return SUCCESS;
  }
}
