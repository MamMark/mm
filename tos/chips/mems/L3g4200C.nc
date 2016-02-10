configuration L3g4200C {
  provides interface SplitControl;
  provides interface L3g4200;
}
implementation {
  components L3g4200P;
  L3g4200 = L3g4200P.L3g4200;
  SplitControl = L3g4200P.SplitControl;

  components MainC;
  L3g4200P.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  L3g4200P.CS -> HplMsp430GeneralIOC.Port44;

  components new Msp430UsciSpiB0C() as Spi;
  L3g4200P.SpiResource -> Spi.Resource;
  L3g4200P.SpiBlock -> Spi.SpiBlock;
  L3g4200P.SpiByte -> Spi.SpiByte;

  components Pwr3V3C;
  L3g4200P.PwrReg -> Pwr3V3C.PwrReg;
}
