configuration Hpl_MM_hwC {
  provides interface Hpl_MM_hw;
}

implementation {
  components Hpl_MM_hwP;
  Hpl_MM_hw = Hpl_MM_hwP;
}
