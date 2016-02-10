
module MemsAppP {
  uses interface Boot;
  
  uses interface Timer<TMilli> as AccelTimer;
  uses interface Lis3dh as Accel;
  uses interface SplitControl as AccelControl;
  
  uses interface Timer<TMilli> as GyroTimer;
  uses interface L3g4200 as Gyro;
  uses interface SplitControl as GyroControl;
  
  uses interface Timer<TMilli> as MagTimer;
  uses interface Lis3mdl as Mag;
  uses interface SplitControl as MagControl;
}
implementation {
  event void Boot.booted() {
    /* Run all at 1sec interval so they contend for bus */
    call AccelTimer.startPeriodic(1000);
    call GyroTimer.startPeriodic(1000);
    call MagTimer.startPeriodic(1000);
  }

  event void AccelTimer.fired() {
    call AccelControl.start();
  }

  event void AccelControl.startDone(error_t error) {
    uint8_t id;
    call Accel.whoAmI(&id);
    call AccelControl.stop();
  }

  event void AccelControl.stopDone(error_t error) {
    nop();
  }

  event void GyroTimer.fired() {
    call GyroControl.start();
  }

  event void GyroControl.startDone(error_t error) {
    uint8_t id;
    call Gyro.whoAmI(&id);
    call GyroControl.stop();
  }

  event void GyroControl.stopDone(error_t error) {
    nop();
  }

  event void MagTimer.fired() {
    call MagControl.start();
  }

  event void MagControl.startDone(error_t error) {
    uint8_t id;
    call Mag.whoAmI(&id);
    call MagControl.stop();
  }

  event void MagControl.stopDone(error_t error) {
    nop();
  }
}
