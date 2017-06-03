/*
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved.
 */

uint32_t recv_count;

module CollectGPSP {
  uses {
    interface Boot;
    interface GPSReceive;
    interface Collect;
  }
}

implementation {

  event void Boot.booted() { }

  event void GPSReceive.msg_available(uint8_t *msg, uint16_t len,
        uint32_t arrival_ms, uint32_t mark_j) {
    dt_gps_t hdr;

    nop();
    recv_count++;
    hdr.len      = sizeof(hdr) + len;
    hdr.dtype    = DT_GPS_RAW_SIRFBIN;
    hdr.stamp_ms = arrival_ms;
    hdr.mark_j   = mark_j;
    hdr.chip     = CHIP_GPS_GSD4E;
    nop();
    call Collect.collect((void *) &hdr, sizeof(hdr), msg, len);
  }
}
