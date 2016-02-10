
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
    nop();
    nop();
    nop();
    call AccelControl.start();
  }

  event void AccelControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    call Accel.whoAmI(&id);
    dbg("MemsAppP", "Accel id = %x\n", id);
    call AccelControl.stop();
  }

  event void AccelControl.stopDone(error_t error) {
    nop();
  }

  event void GyroTimer.fired() {
    nop();
    nop();
    nop();
    call GyroControl.start();
  }

  event void GyroControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    call Gyro.whoAmI(&id);
    dbg("MemsAppP", "Gyro id = %x\n", id);
    call GyroControl.stop();
  }

  event void GyroControl.stopDone(error_t error) {
    nop();
  }

  event void MagTimer.fired() {
    nop();
    nop();
    nop();
    call MagControl.start();
  }

  event void MagControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    call Mag.whoAmI(&id);
    dbg("MemsAppP", "Mag id = %u\n", id);
    call MagControl.stop();
  }

  event void MagControl.stopDone(error_t error) {
    nop();
  }
}
