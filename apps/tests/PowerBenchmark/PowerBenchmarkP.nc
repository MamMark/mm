/** Power benchmark implementation
 *
 * @author John Jacobs <johnj@soe.ucsc.edu>
 **/

#include <Timer.h>
#include "TestSerial.h"
#include <UserButton.h>

module PowerBenchmarkpP {
  // general use interfaces
  uses {
    interface Leds;
    interface Boot;
    interface Timer<TMilli> as TimerExtra;
  }
  // interfaces used for stats
  uses {
    interface Timer<TMilli> as TimerStats;
    interface LogWrite;
    interface LogRead;
    interface McuPowerStatsConsumer;
    interface McuPowerState;
    interface Get<button_state_t>;
    interface Notify<button_state_t>;
  }
  // interfaces used for dumping stats to serial link
  uses {
    interface SplitControl as ControlSerial;
    interface AMSend;
    interface Timer<TMilli> as TimerSerial;
    interface Packet;
  }
  // interfaces used for ADC test
  uses {
    interface Timer<TMilli> as TimerADC;
    interface Read<uint16_t> as ADCRead;
    interface ReadNow<uint16_t> as ADCReadNow;
    interface Resource as ADCReadNowResource;
    interface ReadStream<uint16_t> as ADCReadStream;
  }
}

implementation {

  /* These parameters control how often each of the various tasks run.
  */
  // how often the ADC test runs
  uint16_t adc_period = 1000;
  // how many bytes the ADC test attempts to read from the internal voltage sensor
  uint16_t adc_length = 1000;
  // how often the stats collection loop runs
  uint16_t stats_period = 10000;
  // how often the CPU spin loop test runs
  uint16_t cpuload_period = 1000;
  // how many interations the CPU spin loop test performs
  uint16_t cpuload_length = 1000;

  // how long to pause between sending each dump packet
  uint16_t dump_period = 50;


  /* These flags are used to indicate which tasks are currently running.
 */
  // whether the stats collection loop is currently running
  bool stats_running = FALSE;
  // whether the "serial" test is running
  bool serial_running = FALSE;

  bool dump_running = FALSE;
  bool dump_endmarked = FALSE;
  bool dump_stats_ready = FALSE;

  // this is used to hold a copy of the next "dumped" stats packet to be sent in dump mode
  mcustat_t m_stats;

  void startBenchmark();
  void readStats();
  void preparePacket(void *src, int len);
  void sendPacket();

  event void Boot.booted() {
    // erase
    call Notify.enable();
    call Leds.led2On();
    if (call LogWrite.erase() != SUCCESS) {
      call Leds.led2On();
      return;
    }
  }

  event void LogWrite.eraseDone(error_t error) {
    startBenchmark();
  }

  void startBenchmark() {
    call TimerStats.startPeriodic( stats_period );
    call TimerADC.startPeriodic(adc_period);
    call TimerExtra.startPeriodic(cpuload_period);
  }


  /*  ADC  */

#define BUF_SIZE 100
  uint16_t adcbuf[BUF_SIZE];
  bool streamSuccess;
  
  event void TimerADC.fired() {
    streamSuccess = FALSE;
    call ADCRead.read();
    call ADCReadStream.postBuffer(adcbuf, BUF_SIZE);
    call ADCReadStream.read(adc_length);
    //call ADCReadNowResource.request();
  }
  
  event void ADCRead.readDone(error_t result, uint16_t data) {
    call Leds.led1Toggle();
  }

  event void ADCReadNowResource.granted() {
    call ADCReadNow.read();
  }
  
  async event void ADCReadNow.readDone(error_t result, uint16_t data) {
    call ADCReadNowResource.release();
  }

  event void ADCReadStream.bufferDone( error_t result, uint16_t* buffer, uint16_t count ) {
  }

  event void ADCReadStream.readDone(error_t result, uint32_t actualPeriod) {
  }

  /*  SERIAL  */
  message_t serialpacket;
  bool serial_locked = FALSE;

  event void ControlSerial.startDone(error_t err) {
    if (err == SUCCESS) {
      if (!dump_running) {
        atomic serial_running = TRUE;
      }
    }
    else {
      call ControlSerial.start();
    }
  }

  event void ControlSerial.stopDone(error_t err) {
      atomic serial_running = FALSE;
  }

  event void TimerSerial.fired() {
    if (dump_running) {
      if (!dump_endmarked) { return; }
      if (!dump_stats_ready) {
        readStats();
      }
      else {
        preparePacket(&m_stats, sizeof(mcustat_t));
        sendPacket();
        if (m_stats.state == STATE_END) {
          call TimerSerial.stop();
        }
      }
    }
  }

  event void AMSend.sendDone(message_t* bufPtr, error_t error) {
    serial_locked = FALSE;
    if (bufPtr != &serialpacket) {
      atomic dump_running = FALSE;
      // error #6
      call Leds.set(6);
    }
    else if (dump_running) {
      atomic dump_stats_ready = FALSE;
    }
  }

  /*  STATS  */
  task void updateStats() {
    call McuPowerStatsConsumer.updateStats();
  }

  event void TimerStats.fired() {
    call McuPowerState.update();
    post updateStats();
  }

  event void McuPowerStatsConsumer.statsUpdated(mcustat_t *stats, bool updates) {
    if (!updates) { return; }
    call Leds.led0Toggle();
    if (!stats_running) {
      stats_running = TRUE;
      if (call LogWrite.append(stats, MCUSTATS_NUM_STATS*sizeof(mcustat_t)) != SUCCESS) {
        // TODO:  HANDLE ERROR?
        stats_running = FALSE;
      }
    }
  }

  error_t writeEndOfLog() {
    mcustat_t endMarker;
    endMarker.state = STATE_END;
    return call LogWrite.append(&endMarker, sizeof(mcustat_t));
  }

  event void LogWrite.appendDone(void* buf, storage_len_t len, bool recordsLost, error_t error) {
    if (dump_running) {
      dump_endmarked = TRUE;
    }
    else if (stats_running) {
      stats_running = FALSE;
    }
  }

  event void LogWrite.syncDone(error_t error) {}

  event void Notify.notify( button_state_t state ) {
    if ( state == BUTTON_PRESSED ) {
    }
    else if ( state == BUTTON_RELEASED ) {
      if (dump_running == FALSE) {
        call TimerStats.stop();
	call TimerADC.stop();
	call TimerExtra.stop();
	call TimerSerial.stop();
        dump_running = TRUE;
        if (writeEndOfLog() == SUCCESS) {
          call Leds.led1On();
          call ControlSerial.start();
          call TimerSerial.startPeriodic(dump_period);
        }
      }
      else {
        call TimerSerial.stop();
        dump_running = FALSE;
	startBenchmark();
      }
    }
  }

  void preparePacket(void *src, int len) {
    void *payload = (void *)call Packet.getPayload(&serialpacket, len);
    if (payload == NULL) { 
      dump_running = FALSE;
      // error #3
      call Leds.set(3);
      return; 
    }
    if (call Packet.maxPayloadLength() < len) { 
      dump_running = FALSE;
      // error #4
      call Leds.set(4);
      return; 
    }
    memcpy(payload, src, len);
  }

  void sendPacket() {
    if (call AMSend.send(AM_BROADCAST_ADDR, &serialpacket, sizeof(mcustat_t)) != SUCCESS) {
      dump_running = FALSE;
      // error #5
      call Leds.set(5);
    }
    else {
      call Leds.led1Toggle();
    }
  }

  void readStats() {
    if ( call LogRead.read(&m_stats, sizeof(mcustat_t)) != SUCCESS ) {
      dump_running = FALSE;
      // error #2
      call Leds.set(2);
    }
  }

  event void LogRead.readDone(void* buf, storage_len_t len, error_t err) {
    if (dump_running) {
      if ( (len >= sizeof(mcustat_t)) && (buf == &m_stats) ) {
        atomic dump_stats_ready = TRUE;
      }
      else {
        // success
        dump_running = FALSE;
        call Leds.set(1);
        call TimerSerial.stop();
      }
    }
  }

  event void LogRead.seekDone(error_t error) {
  }

  event void TimerExtra.fired() {
    // 
    int i, j;
    for (i = 0; i < cpuload_length ; i++) {
      j *= i;
    }
    call Leds.led2Toggle();
  }

}
