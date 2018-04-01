"""
tagdump:  decode and display Tag Data Stream file
@author: Dan Maltbie/Eric B. Decker
"""

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
# 0.3.0.dev0    Major Refactor.  Not backward compatable.
#               conversion to datetime.  prototype datetime.
#
#               owcb, convert uptime and elapsed to 32 bit num secs needed.
#

__version__ = '0.3.0.dev0'
