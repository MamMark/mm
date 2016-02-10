
module MemsAppP {
  uses interface Boot;
  uses interface Timer<TMilli> as AccelTimer;
  uses interface Timer<TMilli> as GyroTimer;
  uses interface Timer<TMilli> as MagTimer;

  uses interface Lis3dh as Accel;
  uses interface L3g4200 as Gyro;
  uses interface Lis3mdl as Mag;
}
implementation {
  event void Boot.booted() {
    /* Run all at 1sec interval so they contend for bus */
    call AccelTimer.startPeriodic(1000);
    call GyroTimer.startPeriodic(1000);
    call MagTimer.startPeriodic(1000);
  }

  event void AccelTimer.fired() {
    call Accel.whoAmI();
  }

  event void Accel.whoAmIDone (error_t status, uint8_t id) {
    nop();
    nop();
    nop();
  }

  event void GyroTimer.fired() {
    call Gyro.whoAmI();
  }

  event void Gyro.whoAmIDone (error_t status, uint8_t id) {
    nop();
    nop();
    nop();
  }

  event void MagTimer.fired() {
    call Mag.whoAmI();
  }

  event void Mag.whoAmIDone (error_t status, uint8_t id) {
    nop();
    nop();
    nop();
  }
}
