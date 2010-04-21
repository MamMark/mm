#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <ctype.h>
#include <getopt.h>
#include <libgen.h>
#include <string.h>
#include <time.h>

#include <serialsource.h>
#include <sfsource.h>
#include <message.h>
#include "filesource.h"
#include "serialpacket.h"
#include "serialprotocol.h"

#include "gDTConstants.h"
#include "ParseSirf.h"
#include "GpsNavDataMsg.h"
#include "GpsTrackerDataMsg.h"
#include "GpsGeodeticDataMsg.h"
#include "GpsDevDataMsg.h"
#include "GpsSoftVersMsg.h"
#include "GpsClockStatusMsg.h"
#include "GpsPpsMsg.h"
#include "GpsAlmanacStatusMsg.h"
#include "DtGpsRawMsg.h"
#include "GpsErrorMsg.h"
#include "GpsUnkMsg.h"
#include "GpsNavLibDataMsg.h"

//From mmdump.c
extern int debug,
           verbose,
           write_data;

void
parseSirf(tmsg_t *msg) {
  uint8_t msg_ID;

  //Strip off gps raw header
  reset_tmsg(msg, ((uint8_t *)tmsg_data(msg)) +  dt_gps_raw_data_offset(0),\
	     dt_gps_raw_len_get(msg) - DT_HDR_SIZE_GPS_RAW);

  if (gps_unk_start1_get(msg) != 0xa0) {
    fprintf(stderr, "parseSirf: bad start seq\n");
    return;
  }

  if (gps_unk_start2_get(msg) != 0xa2) {
    fprintf(stderr, "parseSirf: bad start seq\n");
    return;
  }

  msg_ID = gps_unk_id_get(msg);

  switch(msg_ID) {
    case 2:			// Nav data
      parseNavData(msg);
      break;
    case 4:			// Tracker Data
      parseTrackerData(msg);
      break;
    case 5:			// Raw Tracker Data
      parseRawTracker(msg);
      break; 
    case 6:			// Software Vers.
      parseSoftVers(msg);
      break;
    case 7:			//Clock status
      parseClockStat(msg);
      break;
    case 9:			//CPU throughput
      knownMsg(msg_ID);
      break;
    case 10:			//Error
      parseErrorID(msg);
      break;
    case 11:			//Command Ack.
      parseCommAck(msg);
      break;
    case 12:			//Command Nack.
      parseCommNack(msg);
      break;
    case 13:			//Visible List
      parseVisList(msg);
      break;
    case 14:			//Almanac Data
      parseAlmData(msg);
      break;
    case 18:			//OkToSend
      parseOkToSend(msg);
      break;
    case 27:			//DGPS Status
      knownMsg(msg_ID);
      break;
    case 28:			//Nav. Lib. Measurement Data
      parseNavLibDataMeas(msg);
      break;
    case 41:			//Geodetic Nav. Data
      parseGeodeticData(msg);
      break;
    case 52:			//1 PPS Time
      parsePps(msg);
      break; 
    case 255:			//Development Data
      parseDevData(msg);
      break;
    default:
      parseUnkMsg(msg);      
      break;
  }
}


void
parseNavData(tmsg_t *msg) {
  int32_t xpos, ypos, zpos;
  float xvel, yvel, zvel;
  uint8_t mode1, mode2;
  uint8_t hdop;
  uint16_t week;
  double tow;
  uint8_t sats;
  uint8_t msgid;

  msgid = gps_nav_data_id_get(msg);

  xpos = gps_nav_data_xpos_get(msg);
  ypos = gps_nav_data_ypos_get(msg);
  zpos = gps_nav_data_zpos_get(msg);

  xvel = gps_nav_data_xvel_get(msg);
  yvel = gps_nav_data_yvel_get(msg);
  zvel = gps_nav_data_zvel_get(msg);

  mode1 = gps_nav_data_mode1_get(msg);
  hdop = gps_nav_data_hdop_get(msg);
  mode2 = gps_nav_data_mode2_get(msg);
  
  week = gps_nav_data_week_get(msg);
  tow = ((double)gps_nav_data_tow_get(msg))/100;

  sats = gps_nav_data_sats_get(msg);

  fprintf(stderr, "sirf nav data: ");
  fprintf(stderr, "x,y,z: %d,%d,%d  vel: %f,%f,%f\n",
	  xpos, ypos, zpos, xvel, yvel, zvel);
  fprintf(stderr, "  week: %d  TOW: %.2f  nSats: %d  HDOP: %d\n",
	 week, tow, sats, hdop);
  fprintf(stderr,"  mode-1: ");
  switch(mode1 & 0x07) {
    case(0):
      fprintf(stderr,"No nav soln.  ");
      break;
    case(1):
      fprintf(stderr,"1 sat soln.  ");
      break;
    case(2):
      fprintf(stderr,"2 sat soln.  ");
      break;
    case(3):
      fprintf(stderr,"3 sat soln.  ");
      break;
    case(4):
      fprintf(stderr,">3 sat soln.  ");
      break;
    case(5):
      fprintf(stderr,"2-D soln.  ");
      break;
    case(6):
      fprintf(stderr,"3-D soln.  ");
      break;  
    case(7):
      fprintf(stderr,"DR soln.  ");
      break;
    default:
      fprintf(stderr,"Bad PMODE.  ");
      break;
  }

  if (!(mode1 & 0x08))
      fprintf(stderr,"Full powr pos.  ");
  else fprintf(stderr,"Trickle powr pos.  ");

  switch(mode1 & 0x30) {
    case(0):
      fprintf(stderr,"No alt hold.  ");
      break;
    case(0x10):
      fprintf(stderr,"KF alt hold.  ");
      break;
    case(0x20):
      fprintf(stderr,"Alt from user input.  ");
      break;
    case(0x30):
      fprintf(stderr,"Always hold alt.  ");
      break;
    default:
      fprintf(stderr,"Bad ALTMODE.  ");
      break;
  }

  if (!(mode1 & 0x40))
    fprintf(stderr,"DOP mask not exceeded. ");
  else fprintf(stderr,"DOP mask exceeded. ");

  if (!(mode1 & 0x80))
    fprintf(stderr,"No diff corrections.\n");
  else fprintf(stderr,"Diff corrections applied.\n");

  fprintf(stderr,"  mode-2: ");

  if(mode2 & 0x01)
    fprintf(stderr,"DR in use. ");
  else if ((mode1 & 0x07) == 7)
    fprintf(stderr,"Vel DR. ");
  else fprintf(stderr,"DR error. ");

  if(mode2 & 0x02)
    fprintf(stderr, "Soln validated.  ");
  else fprintf(stderr, "Soln not validated.  ");

  if(mode2 & 0x04)
    fprintf(stderr, "Vel DR timeout. ");

  if(mode2 & 0x08)
    fprintf(stderr, "Soln edited by UI. ");

  if(mode2 & 0x10)
    fprintf(stderr, "Vel invalid. ");

  if(mode2  & 0x20)
    fprintf(stderr, "Alt hold enabled. ");
  else fprintf(stderr, "Alt hold disabled - 3D fix only. ");

  switch(mode2 & 0xC0) {
    case(0):
      fprintf(stderr,"GPS-only nav.\n");
      break;
    case(0x40):
      fprintf(stderr,"DR in calibration.\n");
      break;
    case(0x80):
      fprintf(stderr,"DR sensor errors.\n");
      break;
    case(0xC0):
      fprintf(stderr,"DR in test mode.\n ");
      break;
    default:
      fprintf(stderr,"Bad DR error status.\n");
      break;
  }
}


void
parseTrackerData(tmsg_t *msg) {
  int i, j;

  uint16_t week;
  double tow;
  uint8_t chans;
  uint8_t svid;
  float azm;
  float elv;
  uint16_t state;
  float c_no;

  week = gps_tracker_data_week_get(msg);
  tow = ((double)gps_tracker_data_tow_get(msg))/100;
  chans = gps_tracker_data_chans_get(msg);

  fprintf(stderr,"sirf tracker data: ");
  fprintf(stderr,"Week: %d TOW: %.2f Channels: %d\n", week, tow, chans);
  fprintf(stderr," Sat     Azim     Elev        State    C/No\n");
  for(i = 0; i < 180; i += 15){
    svid = gps_tracker_data_data_get(msg, i+0);
    azm = gps_tracker_data_data_get(msg, i+1)*1.5;
    elv = gps_tracker_data_data_get(msg, i+2)/2 ;
    state = gps_tracker_data_data_get(msg, i+4);
    for(j = i+5; j < i+15; j++) {
      c_no += gps_tracker_data_data_get(msg, j);
    }
    c_no = c_no/chans;
    fprintf(stderr, "  %2d  %-7f  %-7f    0x%05x  %f\n", svid, azm, elv, state, c_no);
  }
  fprintf(stderr, "\n");
}


void
parseRawTracker(tmsg_t *msg) {
  fprintf(stderr, "sirf raw tracker: not parsed\n");
}


void
parseSoftVers(tmsg_t *msg) {
  uint16_t len;
  int i;
  char c;

  fprintf(stderr, "sirf s/w version: ");
  len = gps_soft_version_data_len_get(msg) - 1;
  for (i = 0; i < len; i++) {
    c = gps_soft_version_data_data_get(msg,i);
    if (isprint(c))
      fprintf(stderr, "%c", c);
    else
      fprintf(stderr, "(%02x)", c);
  }
  fprintf(stderr, "\n");
}

void
parseClockStat(tmsg_t *msg) {
  uint16_t  week;
  double    tow;
  uint8_t   sats;
  uint32_t  drift;
  uint32_t  bias;
  double    gpstime; 

  week = gps_clock_status_data_week_get(msg);
  tow = ((double)gps_clock_status_data_tow_get(msg))/100;
  sats = gps_clock_status_data_sats_get(msg);
  drift = gps_clock_status_data_drift_get(msg);
  bias = gps_clock_status_data_bias_get(msg);
  gpstime = ((double)gps_clock_status_data_gpstime_get(msg))/1000;

  fprintf(stderr, "sirf clock status: week: %d  TOW: %f  Sats: %d\n", week, tow, sats);
  fprintf(stderr, "  Drift(Hz): %d  Bias(ns): %d   est. GPS TOW: %f\n", drift, bias, gpstime);
}

void
parseErrorID(tmsg_t *msg) {
  uint16_t submsg;

  submsg =  gps_error_data_submsg_get(msg);
  fprintf(stderr,"*** sirf error: error ID: 0x%04x\n", submsg);
}

void
parseCommAck(tmsg_t *msg) {
  uint8_t b;

  b = gps_unk_data_get(msg, 0);
  fprintf(stderr,"sirf cmd ack %d (0x%02x)\n", b, b);
}

void
parseCommNack(tmsg_t *msg) {
  uint8_t b;

  b = gps_unk_data_get(msg, 0);
  fprintf(stderr,"sirf cmd nack %d (0x%02x)\n", b, b);
}

void
parseVisList(tmsg_t *msg) {
  fprintf(stderr,"sirf visible sat list: not parsed\n");
}

void
parseAlmData(tmsg_t *msg) {
  uint8_t satid;
  uint16_t weekstatus;
  uint16_t week;
  uint16_t status;

  satid = gps_almanac_status_data_satid_get(msg);
  weekstatus = gps_almanac_status_data_weekstatus_get(msg);
  week = 0xFFC0 & weekstatus;
  status = 0x003F & weekstatus;

  fprintf(stderr,"sirf almanac data\n");
  fprintf(stderr,"Sat: %d, Week: %d Status: %s\n", satid, week,
	  (status ? "good" : "bad"));
}

void
parseOkToSend(tmsg_t *msg) {
  fprintf(stderr, "sirf ok to send: 0x%02x\n", gps_unk_data_get(msg, 0));
}

void
parseNavLibDataMeas(tmsg_t *msg) {
  uint8_t   chan;
  uint8_t   sat_id;
  uint8_t   sync_flags;
  uint16_t  time_in_track;
  double    mean_c_no = 0;

  chan = gps_nav_lib_data_chan_get(msg);
  sat_id = gps_nav_lib_data_sat_id_get(msg);
  sync_flags = gps_nav_lib_data_sync_flags_get(msg);
  time_in_track = gps_nav_lib_data_time_in_track_get(msg);

  mean_c_no += gps_nav_lib_data_c_no_1_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_2_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_3_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_4_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_5_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_6_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_7_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_8_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_9_get(msg);
  mean_c_no += gps_nav_lib_data_c_no_10_get(msg);
  mean_c_no = mean_c_no/10;

  fprintf(stderr, "sirf nav lib data measurements\n");
  fprintf(stderr, "Sat ID: %d Mean C/No: %f\n", sat_id, mean_c_no); 
  fprintf(stderr, "Channel: %d Time-in-track(ms): %d\n", chan, time_in_track);

  fprintf(stderr, "Integration Time(ms): ");
  if(sync_flags & 0x01) {
    fprintf(stderr, "10");
  }else{
    fprintf(stderr, "2");
  }

  fprintf(stderr, "  Synch State: ");
  switch(sync_flags & 0x06) {
    case(0x00):
      fprintf(stderr, "Not alligned."); break;
    case(0x02):
      fprintf(stderr, "Consistent code epoch align."); break;
    case(0x04):
      fprintf(stderr, "Consistent data bit align."); break;
    case(0x06):
      fprintf(stderr, "No millisecond errors"); break;
  }
  fprintf(stderr, "\n");

  fprintf(stderr, "Autocorrelation detection: ");
  switch(sync_flags & 0x18) {
    case(0x00):
      fprintf(stderr, "Verified not an autocorrelation."); break;
    case(0x08):
      fprintf(stderr, "Testing."); break;
    case(0x10):
      fprintf(stderr, "Strong signal, autocorr detect not run."); break;
    case(0x18):
      fprintf(stderr, "Not used."); break;
  }
  fprintf(stderr, "\n");
}


void
parseGeodeticData(tmsg_t *msg) {
  int i;
  uint16_t navvalid;
  uint16_t navtype;
  uint16_t week;
  double   tow; //div by 1000
  uint16_t year;
  uint8_t  mo;
  uint8_t  day;
  uint8_t  hr;
  uint8_t  min;
  float    sec;		//div by 1000
  uint32_t sat_mask;
  double   lat;		//div by 10e7
  double   lon;		//div by 10e7
  double   elipalt;	//div by 100
  double   mslalt;	//div by 100
  uint8_t  mapdatum;
  float    sog;		//div by 100
  float    cog;		//div by 100
  float    climb;	//div by 100
  double   ehpe;	//div by 100
  double   evpe;	//div by 100
  double   clockbias;	//div by 100
  double   clockdrift;	//div by 100
  uint8_t  nsats;
  float    hdop;	//div by 5

  navvalid = gps_geodetic_nav_valid_get(msg);
  navtype = gps_geodetic_nav_type_get(msg);
  week = gps_geodetic_week_get(msg);
  tow = ((double)gps_geodetic_tow_get(msg))/1000;
  year = gps_geodetic_utc_year_get(msg);
  mo = gps_geodetic_utc_month_get(msg);
  day = gps_geodetic_utc_day_get(msg);
  hr = gps_geodetic_utc_hour_get(msg);
  min = gps_geodetic_utc_min_get(msg);
  sec = ((double)gps_geodetic_utc_sec_get(msg))/1000;
  sat_mask = gps_geodetic_sat_mask_get(msg);
  lat = ((double)gps_geodetic_lat_get(msg))/10000000;
  lon = ((double)gps_geodetic_lon_get(msg))/10000000;
  elipalt = ((double)gps_geodetic_alt_elipsoid_get(msg))/100;
  mslalt = ((double)gps_geodetic_alt_msl_get(msg))/100;
  mapdatum = gps_geodetic_map_datum_get(msg);
  sog = ((float)gps_geodetic_sog_get(msg))/100;
  cog = ((float)gps_geodetic_cog_get(msg))/100;
  climb = ((float)gps_geodetic_climb_get(msg))/100;
  ehpe = ((double)gps_geodetic_ehpe_get(msg))/100;
  evpe = ((double)gps_geodetic_evpe_get(msg))/100;
  clockbias = ((double)gps_geodetic_clock_bias_get(msg))/100;
  clockdrift = ((double)gps_geodetic_clock_drift_get(msg))/100;
  nsats = gps_geodetic_num_svs_get(msg);
  hdop = ((float)gps_geodetic_hdop_get(msg))/5;

  fprintf(stderr, "sirf geodetic data: val: 0x%04x  type: 0x%04x\n", navvalid, navtype);
  if(navvalid == 0x0000)
    fprintf(stderr, "  Over determined.\n");
  else {
    fprintf(stderr, "  Sub-optimal navigation: ");
    if(navvalid & 0x0001)
      fprintf(stderr, "Soln < 5 sats. ");
    if(navvalid & 0x0008)
      fprintf(stderr, "Invalid DR data. ");
    if(navvalid & 0x0010)
      fprintf(stderr, "Invalid DR calibration. ");
    if(navvalid & 0x0020)
      fprintf(stderr, "No DR GPS-based calibration. ");
    if(navvalid & 0x0040)
      fprintf(stderr, "Invalid DR position. ");
    if(navvalid & 0x0080)
      fprintf(stderr, "Invalid heading. ");
    if(navvalid & 0x8000)
      fprintf(stderr, "No tracker data. ");
    if(navvalid & 0x7F06)
      fprintf(stderr, "Unknown reason. ");
    fprintf(stderr,"\n");
  }

  fprintf(stderr, "  Nav type: ");
  switch(navtype & 0x0007) {
    case(0x0):
      fprintf(stderr, "No fix. "); break;
    case(0x1):
      fprintf(stderr, "1 sat soln. "); break;
    case(0x2):
      fprintf(stderr, "2 sat soln. "); break;
    case(0x3):
      fprintf(stderr, "3 sat soln. "); break;
    case(0x4):
      fprintf(stderr, ">3 sat soln. "); break;
    case(0x5):
      fprintf(stderr, "2-D least sqr sln. "); break;
    case(0x6):
      fprintf(stderr, "3-d least sqr sln. "); break;
    case(0x7):
      fprintf(stderr, "DR soln. "); break;
  }

  if(navtype & 0x0008)
    fprintf(stderr, "Trickle pwr. ");
  switch(navtype & 0x30) {
    case(0x0):
      fprintf(stderr, "No alt hold. ");
      break;
    case(0x10):
      fprintf(stderr, "Hold alt from KF. ");
      break;
    case(0x20):
      fprintf(stderr, "Hold alt from user. ");
      break;
    case(0x30):
      fprintf(stderr, "Always hold user alt. ");
      break;
  }

  if(navtype & 0x0040)
    fprintf(stderr, "DOP exceeds limits. ");
  if(navtype & 0x0080)
    fprintf(stderr, "DGPS correction applied. ");
  if(navtype & 0x0100)
    fprintf(stderr, "Sensor DR. ");
  else if (navtype & 0x0007)
    fprintf(stderr, "Velocity DR. ");
  else
    fprintf(stderr, "DR error. ");
  if(navtype & 0x0200)
    fprintf(stderr, ">4 sat soln. ");
  if(navtype & 0x0400)
    fprintf(stderr, "Velocity DR timeout. ");
  if(navtype & 0x0800)
    fprintf(stderr, "Fix edited by MI. ");
  if(navtype & 0x1000)
    fprintf(stderr, "Invalid velocity. ");
  if(navtype & 0x2000)
    fprintf(stderr, "Alt. hold disabled. ");

  switch(navtype & 0xC000) {
    case(0x0):
      fprintf(stderr, "GPS nav only. "); break;
    case(0x4000):
      fprintf(stderr, "DR calibration from GPS. "); break;
    case(0x8000):
      fprintf(stderr, "DR sensor error. "); break;
    case(0xC000):
      fprintf(stderr, "DRin test.. "); break;
  }
  fprintf(stderr,"\n");

  fprintf(stderr, "  GPS xWk: %d  TOW: %.3f  ", week, tow);
  fprintf(stderr, "UTC: %2d/%02d/%04d %2d:%02d:%06.3f\n", mo, day, year, hr, min, sec);

  fprintf(stderr, "  %d Sats in soln.: ", nsats);
  for(i=1; i<32; i++) {
    if(sat_mask & 0x00000001)
      fprintf(stderr, "%d ", i);
    sat_mask = sat_mask >> 1;
  }
  fprintf(stderr, "\n");
  fprintf(stderr, "  Lat: %.7f   Lon: %.7f   Alt: %.2f  Datum: %d\n", lat, lon, mslalt, mapdatum);
  fprintf(stderr, "  SOG: %.2f   COG: %.2f   Climb: %.2f\n", sog, cog, climb);
  fprintf(stderr, "  HDOP: %.1f   Horz Err(m): %.2f   Vert Err(m): %.2f   Clock bias(m): %.2f   Clock drift(m/s): %.2f\n",
	  hdop, ehpe, evpe, clockbias, clockdrift);
}


void
parsePps(tmsg_t *msg) {
  uint16_t year;
  uint8_t  mo;
  uint8_t  day;
  uint8_t  hr;
  uint8_t  min;
  uint8_t  sec; 
  uint8_t  status;
    
  year = gps_pps_data_year_get(msg);
  mo = gps_pps_data_mo_get(msg);
  day = gps_pps_data_day_get(msg);
  hr = gps_pps_data_hr_get(msg);
  min = gps_pps_data_min_get(msg);
  sec = gps_pps_data_sec_get(msg);
  status = gps_pps_data_status_get(msg);

  fprintf(stderr, "sirf 1 pps time\n");
  fprintf(stderr, "Date/time: %d/%d/%d %d:%d:%d  ", mo, day, year, hr, min, sec);
  fprintf(stderr, "time %svalid, %s, %s\n",
	  (status & 1) ? "" : "in",
	  (status & 2) ? "UTC" : "GPS",
	  (status & 4) ? "current" : "stale");
}


void
parseDevData(tmsg_t *msg) {
  int i;
  uint16_t len;
  char c;

  if(verbose) {
    len = gps_dev_data_len_get(msg) - 1;
    fprintf(stderr, "sirf dev data: ");
    for (i = 0; i < len; i++) {
      c = gps_dev_data_data_get(msg, i);
      if (isprint(c))
	fprintf(stderr, "%c", c);
      else
	fprintf(stderr, "(%02x)", c);
    }
    fprintf(stderr, "\n");
  }
}

void
knownMsg(int id) {
  if (verbose) {
    fprintf(stderr,"sirf msg: (0x%02x) ", id);
    switch(id) {
      case 9:
	fprintf(stderr, "cpu throughput ");
	break;
      case 27:
	fprintf(stderr, "dgps status ");
	break;
    }
    fprintf(stderr,"(not parsed)\n");
  }
}


void
parseUnkMsg(tmsg_t *msg) {
  uint16_t len;
  uint8_t msgid;

  len = gps_unk_len_get(msg);
  msgid = gps_unk_id_get(msg);

  fprintf(stderr, "*** sirf unknown msg: %d (0x%02x) len: %d\n", msgid, msgid, len);
  if (debug > 1)
    hexprint(tmsg_data(msg), len);
}


void
hexprint(uint8_t *ptr, int len) {
  int i;

  for (i = 0; i < len; i++) {
    if ((i % 32) == 0) {
      if (i == 0)
	fprintf(stderr, "*** ");
      else
	fprintf(stderr, "\n    ");
    }
    fprintf(stderr, "%02x ", ptr[i]);
  }
  fprintf(stderr, "\n");
}
