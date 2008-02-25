#Set up environment variable to point to location of thread implementation
#After this is set up, run 'make telosc threads' to compile with thread support

#Replace with your absolute path to the root of mammark
MAMMARK_DIR="/Users/klueska/sensornets/tos/mammark"
TOSMAKE_PATH="$TOSMAKE_PATH $MAMMARK_DIR/support/make"
export MAMMARK_DIR
export TOSMAKE_PATH
