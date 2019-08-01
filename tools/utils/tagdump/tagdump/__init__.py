"""
tagdump:  decode and display Tag Data Stream file
@author: Dan Maltbie/Eric B. Decker
"""

__version__ = '0.4.5'

# release: 0.4.5, core_rev: 21/100
#
# core_rev: 21/97
#       o add infrastructure for sensor display.
#       o support for tmp1x2 temp sensors, TmpPX
#       o sensor ids global, defines data format
#
# 0.4.5rc96   core_rev: 21/92
#       o add --noexport to derail exporting to influx.  Used to
#         look at tagdump data prior to being injected into influx.
#       o accept multiple version of influx.  (json_emitters).
#       o reorganize where arguments are parsed.  Do as early as
#         possible (when tagdumpargs is first imported).
#       o make arguments (args) a static global in tagdumpargs.
#       o control when warning messages about json and influxdb don't work
#         any verbosity or explicit export switch set.
#       o change ending record number from -x to -e
#       o add -x switch to set explicit export.  If database connection
#         not set up will cause an abort.
#       o collect all switch definition comments into tagdumpargs.py.
#
# 0.4.5rc92   core_rev: 21/92
# 0.4.5rc3    core_rev: 20/3
#       o restructure image_info, split into image_info_basic (fixe)
#         and image_info_plus, dynamic tlv based descriptors
#       o PANIC_SS_RECOV -> PANIC_PAN (panic code panic)
#       o be really really chatty when tagdump detects chksum errors
#       o 20/1, fix reboot size
#       o revised overwatch_control_block
#         added protection_status
#
# 0.4.4.dev1    19/8
#               GPS_STATS
#               FIRST_LOCK, TX_RESTART
#               add initial support for the TagNet data type (33)
#               support for SYNC_FLUSH
#
# 0.4.3         Core_Rev 19/0
#               reorder EVENTS
#
# 0.4.3.dev2    Core_Rev 18/6
#               Implementation of GPSmonitor Major/Minor state
#               Revised GPSmonitor state machine (v1)
#
# 0.4.2         Core_Rev 18/3
#               split Core_Rev into Core_Rev and Core_Minor
#               display mpm error always.
#
#               Implementation and display of GPSmonitor State transitions
#               Initial GPSmonitor state machine.
#               dump out monitor minor state changes
#
#               Improvements
#               - navtrack (number of sats > 20)
#               - gps_rx_errs hex rx_err, delta errs
#               - dump_hdr: add 'pre' to add error chars in front
#               - grab and display core_ver
#
# 0.4.1         move tagfile to tagcore
#               display rtctime using rtctime_str (basic_rtctime)
#               basic time is number of microsecs since the top of the hour.
#               add hourly time banner at the top of the hour.
#
# 0.4.0.dev3    CORE_REV 18
#
#               Core_Rev refactor.
#               rework image_info (remove vector_check, add image_desc)
#               rework of owcb, boot_time, prev_boot
#               collapse of decoders into headers
#               refactor, create tagcore.
#
# 0.2.2         DT_9 recsum
# 0.2.3         better summary
#               core_decoders
# 0.2.6         direct i/o for TagNet
# 0.2.9         (rc) first release of tagdump.  gps decoders
#               better reboot/fail instrumentation
# 0.2.10        (rc) fix summary, fix GPS_VERSION
#               better docs on recsum chksum computation
#               insist that computed checksum is 16 bits
# 0.2.11        ...
#
# 0.2.12        tweaks, fix gps version
#               add owcb.faults, owcb.subsys_disable.
#               fix definition of datetime_obj, add dt64_obj
#               add -x for end file position bound
#               tweak alignment message, include bytes
#               add LOWPWR to reboot record decode
#               add "-j -1" and "-j <neg>"
#               new reboot and sync layout
#               dt_rev 12
#
# 0.2.13        reorganize EVENTS
#               implement NOTE
#    gps stuff: add GPS_MPM and GPS_FULL_PWR EVENTS
#               decoders for sirf_pwr_mode_req and _rsp
#               decoder open/close session
#               decoder for statistics mid 225,6
#               add mids with sids for sirf_ (raw)
#               add GPS_BOOT_FAIL
#               gps cmd decoding
#
#    cmd line:  --tail,  --net,  -r -1
#               -s SYNC_DELTA, -s0, -s1, -s -1 (place holder)
#               version decoders and headers
#
#    refactor:  better organization to allow easier code sharing.
#               kill core_records, dt stuff into dt_defs
#               sirf stuff into sirf_defs.
#
#    refactor:  split dt level gps obj and decoders out of
#               sirf_decoder/header.  Move into core_records where
#               they belong.  rename gps_decoders/gps_headers to
#               sirf_decoders/gps_headers.  More accurate.
#
#               move sensor data type definitions from sensor_decoders
#               and sensor_headers into core files.  Nuke sensor files.
#
#    refactor:  split decode and printing code into decode and emitters.
#    refactor:  create special atoms to handle unusual cases.  swver, etc.
#    refactor:  make all low level sirf objs and routines, gps_ -> sirf_
#
#               implement sirf_vis (visible sat list).  use new
#               decoder/emitter structure.
#
#    refactor:  add populate.py, split decoders and emitters into seperate
#               files, wire together using populate.
#
#     bug fix:  handle eof detection properly in tagfile.
#
# 0.2.14        force record reading to read through the next quad alignment.
#               this plays nicely with the tagfuse sparse file system for
#               dblk.
#
# 0.3.0.dev3    Major Refactor.  Not backward compatable.
#               conversion to datetime.  prototype datetime.
#               rename datetime to rtctime.
#
# 0.3.0.dev4    sirf dump work, add additional emitters
# 0.3.0.dev7    add -t, --timeout TIMEOUT value for --tail/read timeout
#               handle extEphemeris packets (56, 232).
#               convert print to python3 print (future)
#
#               owcb, convert uptime and elapsed to 32 bit num secs needed.
#
