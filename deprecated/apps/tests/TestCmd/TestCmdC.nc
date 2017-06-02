
configuration TestCmdC {
}

implementation {
  components TestCmdP as App;
  components MainC;
  App -> MainC.Boot;

  components CmdHandlerC;
  App.CmdControl -> CmdHandlerC;
}

