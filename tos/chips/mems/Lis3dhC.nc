configuration Lis3dhC {
  provides interface SplitControl;
  provides interface Lis3dh;
}
implementation {
  components Lis3dhP;
  Lis3dh = Lis3dhP.Lis3dh;
  SplitControl = Lis3dhP.SplitControl;

  components MainC;
  Lis3dhP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  Lis3dhP.CS -> HplMsp430GeneralIOC.Port41;

  components new Msp430UsciSpiB0C() as Spi;
  Lis3dhP.SpiResource -> Spi.Resource;
  Lis3dhP.SpiBlock -> Spi.SpiBlock;
  Lis3dhP.SpiByte -> Spi.SpiByte;

  components Pwr3V3C;
  Lis3dhP.PwrReg -> Pwr3V3C.PwrReg;
}
