/**
 * Copyright (c) 2017 Eric B. Decker
 * All rights reserved
 * @author Eric B. Decker <cire831@gmail.com>
 */

#include <TagnetTLV.h>

#ifndef GPS_COLLECT_RAW
#define GPS_COLLECT_RAW
#endif

configuration GPSmonitorC {
  provides interface TagnetAdapter<tagnet_gps_xyz_t> as InfoSensGpsXYZ;
  uses     interface GPSReceive;
}

implementation {
  components GPSmonitorP;
  InfoSensGpsXYZ = GPSmonitorP;
  GPSReceive     = GPSmonitorP;

  components PanicC;
  GPSmonitorP.Panic -> PanicC;

  components CollectC;
  GPSmonitorP.CollectEvent -> CollectC;
#ifdef GPS_COLLECT_RAW
  GPSmonitorP.Collect -> CollectC;
#endif
}
