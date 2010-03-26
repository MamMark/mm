#include "msp430usci.h"

generic configuration mmSpi0C() {
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
    CLIENT_ID = unique(MSP430_SPI0_BUS),
  };

#ifdef ENABLE_SPI0_DMA
#warning "Enabling DMA for SPI0 (usciB0)"
  components Msp430Spi0DmaP as SpiP;
#else
  components Msp430Spi0NoDmaP as SpiP;
#endif

  Resource = SpiP.Resource[CLIENT_ID];
  SpiResourceConfigure = SpiP.ResourceConfigure[CLIENT_ID];
  SpiByte = SpiP.SpiByte;
  SpiPacket = SpiP.SpiPacket[CLIENT_ID];
//  Msp430SpiConfigure = SpiP.Msp430SpiConfigure[CLIENT_ID];

  components new Msp430UsciB0C() as UsciC;
//  SpiP.ResourceConfigure[CLIENT_ID] <- UsciC.ResourceConfigure;
  ResourceConfigure = UsciC.ResourceConfigure;
  SpiP.UsciResource[CLIENT_ID] -> UsciC.Resource;
  SpiP.UsciInterrupts -> UsciC.HplMsp430UsciInterrupts;
}
