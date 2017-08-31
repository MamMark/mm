/**
 * Copyright (c) 2017 Eric B. Decker
 * Copyright (c) 2010 Eric B. Decker, Carl W. Davis
 * @author Eric B. Decker
 * @author Carl W. Davis
 * @date 4/23/2010
 *
 * Configuration wiring for FileSystem.  See FileSystemP for
 * more details on what FileSystem does.
 */

#include <fs_loc.h>

configuration FileSystemC {
  provides {
    interface Boot       as Booted;     /* out Booted signal */
    interface FileSystem as FS;
  }
  uses interface Boot;			/* incoming signal */
}
implementation {
  components FileSystemP as FS_P;

  /* exports, imports */
  FS     = FS_P;
  Booted = FS_P;
  Boot   = FS_P;

  components new SD0_ArbC() as SD, SSWriteC;

  FS_P.SSW        -> SSWriteC;
  FS_P.SDResource -> SD;
  FS_P.SDread     -> SD;

  components PanicC;
  FS_P.Panic -> PanicC;
}
