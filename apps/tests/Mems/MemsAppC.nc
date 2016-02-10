configuration MemsAppC {
}
implementation {
  components MemsAppP, MainC;
  MemsAppP.Boot -> MainC.Boot;

  components new TimerMilliC() as AccelTimer;
  components new TimerMilliC() as GyroTimer;
  components new TimerMilliC() as MagTimer;
  MemsAppP.AccelTimer -> AccelTimer;
  MemsAppP.GyroTimer -> GyroTimer;
  MemsAppP.MagTimer -> MagTimer;

  components Lis3dhC as Accel;
  MemsAppP.Accel -> Accel;

  components L3g4200C as Gyro;
  MemsAppP.Gyro -> Gyro;

  components Lis3mdlC as Mag;
  MemsAppP.Mag -> Mag;
}
