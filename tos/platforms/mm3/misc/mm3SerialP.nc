
#ifdef TEST_GPS
#define DC_SPEED 4800
#else
#define DC_SPEED 57600
#endif

module mm3SerialP {
  provides {
    interface StdControl;
    interface Msp430UartConfigure;

    interface ResourceConfigure;
  }
  uses {
    interface HplMsp430Usart as Usart;
  }
}
implementation {
  
enum {
  //32KHZ = 32,768 Hz, 1MHZ = 1,048,576 Hz, 4MHZ = 4,194,304

  UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x4a, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x29, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_57600=0x0048, UMCTL_4MHZ_57600=0xfb, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_57600=0x0048, UMCTL_4MHZ_57600=0x7b, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_9600=0x01b4, UMCTL_4MHZ_9600=0xdf, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_9600=0x01b4, UMCTL_4MHZ_9600=0xdf, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_4800=0x0369, UMCTL_4MHZ_4800=0xfb, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
};

  msp430_uart_union_config_t mm3_direct_serial_config = {
    {
#if (DC_SPEED == 115200)
       ubr:   UBR_4MHZ_115200,
       umctl: UMCTL_4MHZ_115200,
#elif (DC_SPEED == 57600)
       ubr:   UBR_4MHZ_57600,
       umctl: UMCTL_4MHZ_57600,
#elif (DC_SPEED == 9600)
       ubr:   UBR_4MHZ_9600,
       umctl: UMCTL_4MHZ_9600,
#elif (DC_SPEED == 4800)
       ubr:   UBR_4MHZ_4800,
       umctl: UMCTL_4MHZ_4800,
#else
#error "DC_SPEED not defined properly"
#endif
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
    return SUCCESS;
  }

  command error_t StdControl.stop(){
    return SUCCESS;
  }

  async command msp430_uart_union_config_t* Msp430UartConfigure.getConfig() {
    return &mm3_direct_serial_config;
  }

  async command void ResourceConfigure.configure() {
    call Usart.setModeUart(&mm3_direct_serial_config);
  }

  async command void ResourceConfigure.unconfigure() {
  }
  
}
