#include "msp430usart.h"

generic configuration mm3Spi1C() {

  provides {
    interface Resource;
    interface SpiByte;
    interface SpiPacket;
    interface ResourceConfigure as SpiResourceConfigure;
  }

  uses interface ResourceConfigure;
}

implementation {
  enum {
    CLIENT_ID = unique( MSP430_SPI1_BUS ),
  };

#ifdef ENABLE_SPI1_DMA
#warning "Enabling SPI DMA on USART1"
  components Msp430SpiDma1P as SpiP;
#else
  components Msp430SpiNoDma1P as SpiP;
#endif

  Resource = SpiP.Resource[ CLIENT_ID ];
  SpiResourceConfigure = SpiP.ResourceConfigure[ CLIENT_ID ];
  SpiByte = SpiP.SpiByte;
  SpiPacket = SpiP.SpiPacket[ CLIENT_ID ];
//  Msp430SpiConfigure = SpiP.Msp430SpiConfigure[ CLIENT_ID ];

  components new Msp430Usart1C() as UsartC;
//  SpiP.ResourceConfigure[ CLIENT_ID ] <- UsartC.ResourceConfigure;
  ResourceConfigure = UsartC.ResourceConfigure;
  SpiP.UsartResource[ CLIENT_ID ] -> UsartC.Resource;
  SpiP.UsartInterrupts -> UsartC.HplMsp430UsartInterrupts;

}
