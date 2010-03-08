// $Id$

/**
 *
 **/

configuration SerialDirectAppC {}
implementation {
  components SerialDirectC as App, MainC;
  App.Boot -> MainC.Boot;

  components HplMsp430UsciA0C as Usci;
  App.Port -> Usci;
  App.PortInt -> Usci;
}


