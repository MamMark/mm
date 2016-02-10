configuration MemsAppC {
}
implementation {
  components MemsAppP, MainC;
  MemsAppP.Boot -> MainC.Boot;

  components new TimerMilliC() as AccelTimer;
  MemsAppP.AccelTimer -> AccelTimer;
  components Lis3dhC as Accel;
  MemsAppP.Accel -> Accel;
  MemsAppP.AccelControl -> Accel;

  components new TimerMilliC() as GyroTimer;
  MemsAppP.GyroTimer -> GyroTimer;
  components L3g4200C as Gyro;
  MemsAppP.Gyro -> Gyro;
  MemsAppP.GyroControl -> Gyro;

  components new TimerMilliC() as MagTimer;
  MemsAppP.MagTimer -> MagTimer;
  components Lis3mdlC as Mag;
  MemsAppP.Mag -> Mag;
  MemsAppP.MagControl -> Mag;
}
