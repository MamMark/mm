configuration HplMM3AdcC {
  provides interface HplMM3Adc;
}

implementation {
  components HplMM3AdcP;

  HplMM3Adc = HplMM3AdcP;
}
