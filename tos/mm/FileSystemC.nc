/**
 * Copyright @ 2010 Eric B. Decker, Carl W. Davis
 * @author Eric B. Decker
 * @author Carl W. Davis
 * @date 4/23/2010
 *
 * Configuration wiring for FileSystem.  See FileSystemP for
 * more details on what FileSystem does.
 */

#include "file_system.h"

configuration FileSystemC {
  provides {
    interface FileSystem as FS;
    interface Boot as OutBoot;		/* out Booted signal */
  }
  uses {
    interface Boot;			/* incoming signal */
  }
}

implementation {
  components FileSystemP as FS_P, MainC;
  MainC.SoftwareInit -> FS_P;

  /* exports, imports */
  FS      = FS_P;
  OutBoot = FS_P;
  Boot    = FS_P;

  components new SD0_ArbC() as SD, SSWriteC;

  FS_P.SSW        -> SSWriteC;
  FS_P.SDResource -> SD;
  FS_P.SDread     -> SD;

#ifdef ENABLE_ERASE
  FS_P.SDerase    -> SD;
#endif

  components PanicC;
  FS_P.Panic -> PanicC;
}
