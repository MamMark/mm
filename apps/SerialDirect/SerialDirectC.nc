// $Id$

/**
 *
 **/

configuration SerialDirectC {}
implementation {
  components SerialDirectP as App, MainC;
  App.Boot -> MainC.Boot;

  components HplMsp430UsciA1C as Usci;
  App.Port -> Usci;
  App.PortInt -> Usci;

  components SDspC;
  App.SDread -> SDspC;
}


