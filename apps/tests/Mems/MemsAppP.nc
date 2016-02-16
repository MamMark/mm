
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
  } mems_sample_t;

  #define SAMPLE_COUNT 60
  #define SAMPLE_SIZE 6

  uint8_t m_accelSampleCount;
  uint8_t m_gyroSampleCount;
  uint8_t m_magSampleCount;

  mems_sample_t m_accelSamples[SAMPLE_COUNT];
  mems_sample_t m_gyroSamples[SAMPLE_COUNT];
  mems_sample_t m_magSamples[SAMPLE_COUNT];
  
  event void Boot.booted() {
    call AccelControl.start();
    call GyroControl.start();
    call MagControl.start();
  }

  event void AccelControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    id = 0;
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
			    SAMPLE_SIZE);
      m_accelSampleCount++;
    }
    if (m_accelSampleCount >= SAMPLE_COUNT) {
      call AccelTimer.stop();
      call AccelControl.stop();
    }
  }

  event void AccelControl.stopDone(error_t error) {
    nop();
    nop();
    nop();
  }

  event void GyroControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    id = 0;
    call Gyro.whoAmI(&id);
    dbg("MemsAppP", "Gyro id = %x\n", id);
    if (id != 0xd3) {
      call Panic.panic(PANIC_SNS, 2, id, 0, 0, 0);
    } else if (call Gyro.config100Hz() == SUCCESS) {
      call GyroTimer.startPeriodic(1000);
    }
  }

  event void GyroTimer.fired() {
    nop();
    nop();
    nop();
    if (call Gyro.xyzDataAvail()) {
      call Gyro.readSample((uint8_t *)(&m_gyroSamples[m_gyroSampleCount]),
			   SAMPLE_SIZE);
      m_gyroSampleCount++;
    }
    if (m_gyroSampleCount >= SAMPLE_COUNT) {
      call GyroTimer.stop();
      call GyroControl.stop();
    }
  }

  event void GyroControl.stopDone(error_t error) {
    nop();
  }

  event void MagControl.startDone(error_t error) {
    uint8_t id;
    nop();
    nop();
    nop();
    id = 0;
    call Mag.whoAmI(&id);
    dbg("MemsAppP", "Mag id = %u\n", id);
    if (id != 0x3d) {
      call Panic.panic(PANIC_SNS, 3, id, 0, 0, 0);
    } else if (call Mag.config10Hz() == SUCCESS) {
      call MagTimer.startPeriodic(1000);
    }
  }

  event void MagTimer.fired() {
    nop();
    nop();
    nop();
    if (call Mag.xyzDataAvail()) {
      call Mag.readSample((uint8_t *)(&m_magSamples[m_magSampleCount]),
			  SAMPLE_SIZE);
      m_magSampleCount++;
    }
    if (m_magSampleCount >= SAMPLE_COUNT) {
      call MagTimer.stop();
      call MagControl.stop();
    }
  }

  event void MagControl.stopDone(error_t error) {
    nop();
  }

  async event void Panic.hook() { }
}
