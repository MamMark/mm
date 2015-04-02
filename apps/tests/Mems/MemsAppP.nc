
module MemsAppP {
  uses interface Boot;
  uses interface Panic;
  
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
  typedef struct {
    uint8_t xLow;
    uint8_t xHigh;
    uint8_t yLow;
    uint8_t yHigh;
    uint8_t zLow;
    uint8_t zHigh;
  } accel_sample_t;

  #define ACCEL_SAMPLE_COUNT 60
  #define ACCEL_SAMPLE_SIZE 6

  uint8_t m_accelSampleCount;

  accel_sample_t m_accelSamples[ACCEL_SAMPLE_COUNT];
  
  event void Boot.booted() {
    call AccelControl.start();
  }

  event void AccelControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    call Accel.whoAmI(&id);
    if (id != 0x33) {
      call Panic.panic(PANIC_SNS, 1, id, 0, 0, 0);
    } else if (call Accel.config1Hz() == SUCCESS) {
      call AccelTimer.startPeriodic(500);
    }
  }

  event void AccelTimer.fired() {
    nop();
    nop();
    nop();
    if (call Accel.xyzDataAvail()) {
      call Accel.readSample((uint8_t *)(&m_accelSamples[m_accelSampleCount]),
			    ACCEL_SAMPLE_SIZE);
      m_accelSampleCount++;
    }
    if (m_accelSampleCount >= ACCEL_SAMPLE_COUNT) {
      call AccelTimer.stop();
      call AccelControl.stop();
    }
  }

  event void AccelControl.stopDone(error_t error) {
    nop();
    nop();
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

  async event void Panic.hook() { }
}
