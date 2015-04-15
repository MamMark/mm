configuration Lis3dhC {
  provides {
    interface SplitControl;
    interface Lis3dh;
  }
}
implementation {
  components new MemsCtrlP() as MemsP;

  components Lis3dhP;
  Lis3dh = Lis3dhP.Lis3dh;
  SplitControl = MemsP.SplitControl;
  Lis3dhP.MemsCtrl -> MemsP;

  components MainC;
  MemsP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  MemsP.CSN -> HplMsp430GeneralIOC.Port41;

  components new Msp430UsciSpiB0C() as Spi;
  MemsP.SpiResource -> Spi.Resource;
  MemsP.SpiBlock -> Spi.SpiBlock;

  components Pwr3V3C;
  MemsP.PwrReg -> Pwr3V3C.PwrReg;

  components PanicC;
  MemsP.Panic -> PanicC;
}
