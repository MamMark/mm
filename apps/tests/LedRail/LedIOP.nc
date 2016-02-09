/*
 * LedIOP provides GeneralIO interface to an Led.
 * I added this because on some platforms calling io.set() on Led
 * turns OFF the Led. This makes the Led always turn ON when set()
 * is called, and OFF when clr() is called.
 */

module LedIOP {
  provides interface GeneralIO;
  uses interface Led;
}
implementation {
  async command void GeneralIO.set() { call Led.on(); }
  async command void GeneralIO.clr() { call Led.off(); }
  async command void GeneralIO.toggle() { call Led.toggle(); }
  async command bool GeneralIO.get() { return FALSE; }          /* not implemented */
  async command void GeneralIO.makeInput() {}                   /* not implemented */
  async command bool GeneralIO.isInput() { return FALSE; }      /* not implemented */
  async command void GeneralIO.makeOutput() {}                  /* not implemented */
  async command bool GeneralIO.isOutput() { return TRUE; }      /* not implemented */
}
