
configuration TestCmdAppC {
}

implementation {
  components MainC, TestCmdC, LedsC;
  TestCmdC -> MainC.Boot;

  components CmdHandlerC;
  TestCmdC.CmdControl -> CmdHandlerC;
}

