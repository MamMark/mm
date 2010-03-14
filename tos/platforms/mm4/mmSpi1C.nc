#include "msp430usci.h"

generic configuration mmSpi1C() {

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
#warning "Enabling SPI DMA on SPI1_BUS"
  components Msp430SpiDma1P as SpiP;
#else
  components Msp430SpiNoDma1P as SpiP;
#endif

  Resource = SpiP.Resource[ CLIENT_ID ];
  SpiResourceConfigure = SpiP.ResourceConfigure[ CLIENT_ID ];
  SpiByte = SpiP.SpiByte;
  SpiPacket = SpiP.SpiPacket[ CLIENT_ID ];
//  Msp430SpiConfigure = SpiP.Msp430SpiConfigure[ CLIENT_ID ];

  components new Msp430UsciB1C() as UsciC;
//  SpiP.ResourceConfigure[ CLIENT_ID ] <- UsciC.ResourceConfigure;
  ResourceConfigure = UsciC.ResourceConfigure;
  SpiP.UsciResource[ CLIENT_ID ] -> UsciC.Resource;
  SpiP.UsciInterrupts -> UsciC.HplMsp430UsciInterrupts;
}
