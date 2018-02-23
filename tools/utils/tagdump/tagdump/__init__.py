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
# 0.2.12        tweaks, fix gps version
#               add owcb.faults, owcb.subsys_disable.
#               fix definition of datetime_obj, add dt64_obj
#               add -x for end file position bound
#               tweak alignment message, include bytes
#               add LOWPWR to reboot record decode
#               add "-j -1" and "-j <neg>"
#               new reboot and sync layout
#               dt_rev 12
# 0.2.12.dev0-dev10
# 0.2.13        reorganize EVENTS
#               add GPS_MPM and GPS_FULL_PWR EVENTS
#               decoders for gps_pwr_mode_req and _rsp
#               decoder for statistics mid 225,6
#               add GPS_BOOT_FAIL
#               add mids with sids for gps_raw
#               gps cmd decoding
#
__version__ = '0.2.12.dev10'
