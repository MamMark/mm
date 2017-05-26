configuration testMsgBufC {}
implementation {
  components testMsgBufP, MainC;
  testMsgBufP.Boot   -> MainC;

  components PlatformC, GPSMsgBufP;
  components PanicC;
  MainC.SoftwareInit -> GPSMsgBufP;
  GPSMsgBufP.Panic   -> PanicC;

  testMsgBufP.GPSReceive -> GPSMsgBufP;
  testMsgBufP.GPSBuffer  -> GPSMsgBufP;
  testMsgBufP.Platform   -> PlatformC;

//  components new TimerMilliC() as Timer;
//  testMsgBufP.testTimer -> Timer;

//  components LocalTimeMilliC;
//  testMsgBufP.LocalTime -> LocalTimeMilliC;
}
