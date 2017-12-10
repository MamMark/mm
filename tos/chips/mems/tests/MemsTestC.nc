configuration MemsTestC {
}
implementation {
  components MemsTestP, MainC;
  MemsTestP.Boot -> MainC.Boot;

  components new TimerMilliC() as AccelTimer;
  MemsTestP.AccelTimer -> AccelTimer;

  components Lis3dhC as Accel;
  MemsTestP.Accel -> Accel;
  MemsTestP.AccelControl -> Accel;

  components new TimerMilliC() as GyroTimer;
  MemsTestP.GyroTimer -> GyroTimer;

  components L3g4200C as Gyro;
  MemsTestP.Gyro -> Gyro;
  MemsTestP.GyroControl -> Gyro;

  components new TimerMilliC() as MagTimer;
  MemsTestP.MagTimer -> MagTimer;

  components Lis3mdlC as Mag;
  MemsTestP.Mag -> Mag;
  MemsTestP.MagControl -> Mag;

  components PanicC;
  MemsTestP.Panic -> PanicC;
}
