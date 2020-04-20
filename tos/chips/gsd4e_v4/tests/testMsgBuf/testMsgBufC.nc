configuration testMsgBufC {}
implementation {
  components testMsgBufP, MainC;
  testMsgBufP.Boot   -> MainC;

  components PlatformC, MsgBufP;
  components PanicC;
  MainC.SoftwareInit -> MsgBufP;
  MsgBufP.Panic      -> PanicC;

  testMsgBufP.GPSReceive -> MsgBufP;
  testMsgBufP.MsgBuf     -> MsgBufP;
  testMsgBufP.Platform   -> PlatformC;

//  components new TimerMilliC() as Timer;
//  testMsgBufP.testTimer -> Timer;

//  components LocalTimeMilliC;
//  testMsgBufP.LocalTime -> LocalTimeMilliC;
}
