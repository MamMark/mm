/*
 * See TmpPC for explanation of what's up with this tmp port
 */

configuration TmpXC {
  provides interface SimpleSensor<uint16_t>;
}

implementation {
  enum {
    TMP_ADDR   = 0x49,
  };

  components HplTmpC;
  SimpleSensor = HplTmpC.SimpleSensor[TMP_ADDR];
}
