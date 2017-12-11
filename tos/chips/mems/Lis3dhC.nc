configuration Lis3dhC {
  provides {
    interface Lis3dh;
  }
}
implementation {
  components Lis3dhP, AccelRegC;
  Lis3dh = Lis3dhP;
  Lis3dhP.SpiReg -> AccelRegC;
}
