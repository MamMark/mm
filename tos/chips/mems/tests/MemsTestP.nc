
module MemsTestP {
  uses interface Boot;
  uses interface Panic;

  uses interface Timer<TMilli> as AccelTimer;
  uses interface Lis3dh as Accel;

#ifdef notdef
  uses interface Timer<TMilli> as GyroTimer;
  uses interface L3g4200 as Gyro;

  uses interface Timer<TMilli> as MagTimer;
  uses interface Lis3mdl as Mag;
#endif
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
    m_magSampleCount = call Accel.whoAmI();
    call Accel.config1Hz();
    call AccelTimer.startPeriodic(500);

#ifdef notdef
    id = call Gyro.whoAmI();
    call Gyro.config100Hz();
    call GyroTimer.startPeriodic(1000);

    id = call Mag.whoAmI();
    call Mag.config10Hz();
    call MagTimer.startPeriodic(1000);
#endif
  }


  event void AccelTimer.fired() {
    nop();
    if (call Accel.xyzDataAvail()) {
      call Accel.readSample((uint8_t *)(&m_accelSamples[m_accelSampleCount]),
			    SAMPLE_SIZE);
      m_accelSampleCount++;
    }
    if (m_accelSampleCount >= SAMPLE_COUNT) {
      call AccelTimer.stop();
    }
  }


#ifdef notdef
  event void GyroTimer.fired() {
    nop();
    if (call Gyro.xyzDataAvail()) {
      call Gyro.readSample((uint8_t *)(&m_gyroSamples[m_gyroSampleCount]),
			   SAMPLE_SIZE);
      m_gyroSampleCount++;
    }
    if (m_gyroSampleCount >= SAMPLE_COUNT) {
      call GyroTimer.stop();
    }
  }


  event void MagTimer.fired() {
    nop();
    if (call Mag.xyzDataAvail()) {
      call Mag.readSample((uint8_t *)(&m_magSamples[m_magSampleCount]),
			  SAMPLE_SIZE);
      m_magSampleCount++;
    }
    if (m_magSampleCount >= SAMPLE_COUNT) {
      call MagTimer.stop();
    }
  }
#endif

  async event void Panic.hook() { }
}
