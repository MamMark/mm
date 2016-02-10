configuration Lis3dhC {
  provides interface Lis3dh;
}
implementation {
  components Lis3dhP;
  Lis3dh = Lis3dhP;

  components MainC;
  Lis3dhP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  Lis3dhP.CS -> HplMsp430GeneralIOC.Port41;

  components new Msp430UsciSpiB0C() as Spi;
  Lis3dhP.SpiResource -> Spi.Resource;
  //Lis3dh.SpiBlock -> Spi.SpiBlock;
  Lis3dhP.SpiByte -> Spi.SpiByte;
}
