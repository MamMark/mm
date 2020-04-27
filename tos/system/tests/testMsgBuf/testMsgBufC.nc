configuration testMsgBufC {}
implementation {
  components testMsgBufP, MainC;
  testMsgBufP.Boot   -> MainC;

  components PlatformC, MsgBufP;
  components PanicC;
  MainC.SoftwareInit -> MsgBufP;
  MsgBufP.Panic      -> PanicC;
  MsgBufP.Rtc        -> PlatformC;

  testMsgBufP.MsgReceive -> MsgBufP;
  testMsgBufP.MsgBuf     -> MsgBufP;
  testMsgBufP.Platform   -> PlatformC;
}
