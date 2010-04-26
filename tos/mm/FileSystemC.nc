/**
 * Copyright @ 2010 Eric B. Decker, Carl W. Davis
 * @author Eric B. Decker
 * @author Carl W. Davis
 * @date 4/23/2010
 *
 * Configuration wiring for FileSystem.  See FileSystemP for
 * more details on what FileSystem does.
 *
 * TinyOS 2 implementation.
 */

#include "file_system.h"

configuration FileSystemC {
  provides {
    interface FileSystem as FS;
  }
}

implementation {
  components FileSystemP as FS_P, MainC;
  FS = FS_P;
  MainC.SoftwareInit -> FS_P;

  components PanicC, LocalTimeMilliC;
  FS_P.Panic -> PanicC;
}
