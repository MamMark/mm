configuration LisXdhC {
  provides interface LisXdh;
}
implementation {

  /* accelerometer driver */
  components LisXdhP;

  /* platform register export */
  components AccelRegC;

  LisXdh = LisXdhP;
  LisXdhP.SpiReg -> AccelRegC;
}
