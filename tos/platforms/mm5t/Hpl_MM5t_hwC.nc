configuration Hpl_MM5t_hwC {
  provides interface Hpl_MM5t_hw;
}

implementation {
  components Hpl_MM5t_hwP;
  Hpl_MM5t_hw = Hpl_MM5t_hwP;
}
