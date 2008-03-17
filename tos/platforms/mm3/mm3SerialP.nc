module mm3SerialP {
  provides interface StdControl;
  provides interface Msp430UartConfigure;
  uses interface Resource;
}
implementation {
  
enum {
  //32KHZ = 32,768 Hz, 1MHZ = 1,048,576 Hz, 4MHZ = 4,194,304
  UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x4a, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
  //  UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x29, // from http://mspgcc.sourceforge.net/baudrate.html
};

  msp430_uart_union_config_t mm3_direct_serial_config = {
    {  ubr:   UBR_4MHZ_115200,
       umctl: UMCTL_4MHZ_115200,
       ssel: 0x02,		// smclk selected (DCO, 4MHz)
       pena: 0,			// no parity
       pev: 0,			// no parity
       spb: 0,			// one stop bit
       clen: 1,			// 8 bit data
       listen: 0,		// no loopback
       mm: 0,			// idle-line
       ckpl: 0,			// non-inverted clock
       urxse: 0,		// start edge off
       urxeie: 1,		// error interrupt enabled
       urxwie: 0,		// rx wake up disabled
       utxe : 1,		// tx interrupt enabled
       urxe : 1			// rx interrupt enabled
    }
  };

  command error_t StdControl.start(){
    return call Resource.immediateRequest();
  }

  command error_t StdControl.stop(){
    call Resource.release();
    return SUCCESS;
  }

  event void Resource.granted(){}

  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    return &mm3_direct_serial_config;
  }
  
}
