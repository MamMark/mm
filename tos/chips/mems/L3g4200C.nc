configuration L3g4200C {
  provides {
    interface SplitControl;
    interface L3g4200;
  }
}
implementation {
  components new MemsCtrlP() as MemsP;

  components L3g4200P;
  L3g4200 = L3g4200P.L3g4200;
  SplitControl = MemsP.SplitControl;
  L3g4200P.MemsCtrl -> MemsP;

  components MainC;
  MemsP.Init <- MainC.SoftwareInit;
  
  components HplMsp430GeneralIOC;
  MemsP.CSN -> HplMsp430GeneralIOC.Port44;

  components new Msp430UsciSpiB0C() as Spi;
  MemsP.SpiResource -> Spi.Resource;
  MemsP.SpiBlock -> Spi.SpiBlock;

  components Pwr3V3C;
  MemsP.PwrReg -> Pwr3V3C.PwrReg;

  components PanicC;
  MemsP.Panic -> PanicC;
}
