configuration MemsTestC {
}
implementation {
  components MemsTestP, SystemBootC;
  MemsTestP.Boot -> SystemBootC.Boot;

  components LisXdhC as Accel;
  components new TimerMilliC() as AccelTimer;
  MemsTestP.Accel      -> Accel;
  MemsTestP.AccelTimer -> AccelTimer;

#ifdef notdef
  components L3g4200C as Gyro;
  components new TimerMilliC() as GyroTimer;
  MemsTestP.Gyro       -> Gyro;
  MemsTestP.GyroTimer  -> GyroTimer;

  components Lis3mdlC as Mag;
  components new TimerMilliC() as MagTimer;
  MemsTestP.Mag -> Mag;
  MemsTestP.MagTimer -> MagTimer;
#endif

  components PanicC;
  MemsTestP.Panic -> PanicC;
}
