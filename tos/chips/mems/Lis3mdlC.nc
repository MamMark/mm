configuration Lis3mdlC {
  provides interface Lis3mdl;
}
implementation {
  components Lis3mdlP;
  Lis3mdl = Lis3mdlP;

  components MainC;
  Lis3mdlP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  Lis3mdlP.CS -> HplMsp430GeneralIOC.Port46;

  components new Msp430UsciSpiB0C() as Spi;
  Lis3mdlP.SpiResource -> Spi.Resource;
  //Lis3mdl.SpiBlock -> Spi.SpiBlock;
  Lis3mdlP.SpiByte -> Spi.SpiByte;
}
