module PlatformPinsP {
  provides interface Init as PeriphInit;
  uses     interface Platform;
}
implementation {
  command error_t PeriphInit.init() {
    uint32_t nvic_index;
    uint32_t nvic_bitmask;

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
     *
     * We could do this one IRQn at a time using 6 calls to
     * NVIC_EnableIRQ but that is annoying.  So we do it all at once.
     * This works because all 6 PORTn_IRQn live in the 2nd NVIC ISER
     * control word.  Bit positions change.  But we compensate for that
     * with an enable mask.
     */
    nvic_index = PORT1_IRQn >> 5;
    nvic_bitmask  =
          1 << (PORT1_IRQn & 0x1f) |
          1 << (PORT2_IRQn & 0x1f) |
          1 << (PORT3_IRQn & 0x1f) |
          1 << (PORT4_IRQn & 0x1f) |
          1 << (PORT5_IRQn & 0x1f) |
          1 << (PORT6_IRQn & 0x1f);
    NVIC->ISER[nvic_index] = nvic_bitmask;
    NVIC_SetPriority(PORT1_IRQn, call Platform.getIntPriority(PORT1_IRQn));
    NVIC_SetPriority(PORT2_IRQn, call Platform.getIntPriority(PORT2_IRQn));
    NVIC_SetPriority(PORT3_IRQn, call Platform.getIntPriority(PORT3_IRQn));
    NVIC_SetPriority(PORT4_IRQn, call Platform.getIntPriority(PORT4_IRQn));
    NVIC_SetPriority(PORT5_IRQn, call Platform.getIntPriority(PORT5_IRQn));
    NVIC_SetPriority(PORT6_IRQn, call Platform.getIntPriority(PORT6_IRQn));

    return SUCCESS;
  }
}
