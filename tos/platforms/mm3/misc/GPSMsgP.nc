/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker (cire831@gmail.com)
 * @date 28 May 2008
 */

/*
 * GPS Message level states.  Where in the message is the state machine
 */
typedef enum {
  GPSM_START = 1,
  GPSM_START_2,
  GPSM_LEN,
  GPSM_LEN_2,
  GPSM_PAYLOAD,
  GPSM_CHK,
  GPSM_CHK_2,
  GPSM_END,
  GPSM_END_2,
} gpsm_state_t;


module GPSMsgP {
  provides {
    interface StdControl as GPSMsgControl;
    interface GPSByte;
  }
}

implementation {

  norace gpsm_state_t gpsm_state;	/* message collection state */
  norace uint16_t     gpsm_length;	/* length of payload */
  norace uint16_t     gpsm_cur;	        /* where we are in the payload */
  norace uint16_t     gpsm_cur_chksum;	/* running chksum of payload */

#define GPS_OVR_SIZE 16

  uint8_t gps_msg[GPS_BUF_SIZE];
  uint8_t *gpsm_ptr;
  uint8_t gps_overflow[GPS_OVR_SIZE];
  bool on_overflow;

  /*
   *
   */
  task void gps_msg_task() {
    nop();
  }


  command error_t GPSMsgControl.start() {
    gpsm_state = GPSM_START;
    gpsm_length = 0;
    gpsm_cur = 0;
    gpsm_cur_chksum = 0;
    memset(gps_msg, 0, sizeof(gps_msg));
    gpsm_ptr = gps_msg;
    on_overflow = FALSE;
    return SUCCESS;
  }


  command error_t GPSMsgControl.stop() {
    nop();
    return SUCCESS;
  }


  async command void GPSByte.byte_avail(uint8_t byte) {
    nop();
  }
}
