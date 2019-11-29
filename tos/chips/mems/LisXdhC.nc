configuration LisXdhC {
  provides {
    interface LisXdh;
  }
}
implementation {
  components LisXdhP, AccelRegC;
  LisXdh = LisXdhP;
  LisXdhP.SpiReg -> AccelRegC;
}
