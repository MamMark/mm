#Set up environment variable to point to location of thread implementation
#After this is set up, run 'make telosc threads' to compile with thread support

#Replace with your absolute path to the root of mammark
MM_ROOT="/Users/klueska/sensornets/tos/mammark"
TOSMAKE_PATH="$TOSMAKE_PATH $MM_ROOT/support/make"
export MM_ROOT
export TOSMAKE_PATH
