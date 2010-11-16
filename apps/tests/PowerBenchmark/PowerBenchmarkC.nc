/**
 * Power benchmark configuration
 * Test program for PowerStats.
 *
 * Initially from CE259 class.
 *
 * @author John Jacobs <johnj@soe.ucsc.edu>
 **/

#include "StorageVolumes.h"

configuration PowerBenchmarkC {
}

implementation {

  components MainC, PowerBenchmarkC, LedsC, McuSleepC;

  components McuPowerStatsC;
  components new TimerMilliC() as TimerStats;
  components new LogStorageC(VOLUME_POWERLOG, TRUE);
  components UserButtonC;
  // Stats
  PowerBenchmarkC.LogWrite -> LogStorageC;
  PowerBenchmarkC.LogRead -> LogStorageC;
  PowerBenchmarkC.McuPowerStatsConsumer -> McuPowerStatsC;
  McuSleepC.McuPowerStatsProducer -> McuPowerStatsC;
  PowerBenchmarkC.McuPowerState -> McuSleepC;
  PowerBenchmarkC.Get -> UserButtonC;
  PowerBenchmarkC.Notify -> UserButtonC; 

  components new TimerMilliC() as TimerExtra;
  PowerBenchmarkC.TimerExtra -> TimerExtra;

  // ADC components
  components new TimerMilliC() as TimerADC;
  components new DemoSensorC() as Sensor,
    new DemoSensorNowC() as SensorNow,
    new DemoSensorStreamC() as SensorStream;

  PowerBenchmarkC -> MainC.Boot;
  PowerBenchmarkC.TimerStats -> TimerStats;
  PowerBenchmarkC.Leds -> LedsC;

  PowerBenchmarkC.ADCRead -> Sensor;
  PowerBenchmarkC.ADCReadNow -> SensorNow;
  PowerBenchmarkC.ADCReadNowResource -> SensorNow;
  PowerBenchmarkC.ADCReadStream -> SensorStream;  
  PowerBenchmarkC.TimerADC-> TimerADC;

  // Serial components
  components SerialActiveMessageC as TestSerialAM;
  components new TimerMilliC() as TimerSerial;

  PowerBenchmarkC.ControlSerial -> TestSerialAM;
  PowerBenchmarkC.TimerSerial -> TimerSerial;
  PowerBenchmarkC.AMSend -> TestSerialAM.AMSend[AM_MCUSTAT];
  PowerBenchmarkC.Packet -> TestSerialAM;
}
