#Set up environment variable to point to location of thread implementation
#After this is set up, run 'make telosc threads' to compile with thread support

#Replace with your absolute path to the root of mammark
if [ "z$MAMMARK_DIR" = "z" ] ; then
    MAMMARK_DIR="/home/cire/mm_t2/t2_mm3"
    TOSMAKE_PATH="$TOSMAKE_PATH $MAMMARK_DIR/support/make"
fi
export MAMMARK_DIR
export TOSMAKE_PATH
