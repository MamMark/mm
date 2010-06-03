/*
 * Copyright (c) 2010 Eric B. Decker
 * All rights reserved.
 */

/**
 * @author Eric B. Decker <cire831@gmail.com>
 * @date March 21, 2010
 */

configuration CommBootC {
  provides interface Boot as CommBoot;
  uses interface Boot;
}
implementation {
  components CommBootP;

  CommBoot = CommBootP.CommBoot;
  Boot = CommBootP;

  components SerialActiveMessageC, PanicC;
  CommBootP.DockSerial -> SerialActiveMessageC;
  CommBootP.Panic -> PanicC;
}
