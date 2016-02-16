configuration Lis3mdlC {
  provides {
    interface SplitControl;
    interface Lis3mdl;
  }
}
implementation {
  components new MemsCtrlP() as MemsP;

  components Lis3mdlP;
  Lis3mdl = Lis3mdlP.Lis3mdl;
  SplitControl = MemsP.SplitControl;
  Lis3mdlP.MemsCtrl -> MemsP;

  components MainC;
  MemsP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  MemsP.CSN -> HplMsp430GeneralIOC.Port46;

  components new Msp430UsciSpiB0C() as Spi;
  MemsP.SpiResource -> Spi.Resource;
  MemsP.SpiBlock -> Spi.SpiBlock;

  components Pwr3V3C;
  MemsP.PwrReg -> Pwr3V3C.PwrReg;

  components PanicC;
  MemsP.Panic -> PanicC;
}
