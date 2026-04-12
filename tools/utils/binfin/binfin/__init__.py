"""
binfin: Update MamMark (mm) META_INFO data
@author: Eric B. Decker
@author: R. Li Fo Sjoe
"""

__version__ = '1.1.2'

# 1.1.2         buffer passed to tagcore.tlv processing needs to
#               be a bytearray vs. string.  Compatibility problem
#               standalone binfin vs. tlv use via tagdump.
#
# 1.1.1         if dev board print hw_m in hex (> 0x80)
#               tagcore ImageInfo change.
# 1.1.0         url0 and url1 for repo urls
# 1.0.0         release
# 0.1.4         rework core binfin to deal with plus tlvs as reworked.
#               rework options, add -c (clear), -d (desc), --version,
#               add -w write.  add logic handling write and no write.
#               --repo0, --repo1
#
#               use qprint(), eprint().
#
#               improve debugging output.
#
# 0.1.2rc1      Switch to argparse/bininfo integrated
# 0.1.1rc0      Release Candidate
#               correctly handles NIB vs GOLDEN offsets.
# 0.1.0.dev0    Initial Release
