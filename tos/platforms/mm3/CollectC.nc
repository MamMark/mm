/**
 * Copyright @ 2008 Eric B. Decker
 * @author Eric B. Decker
 */

configuration CollectC {
  provides interface Collect;
}

implementation {
  components SerialCollectC;
  Collect = SerialCollectC;
}
