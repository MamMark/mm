/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

configuration FSBootC {}
implementation {
  components FSBootP as App;
  components MainC;

  App.InBoot -> MainC.Boot;

  components FileSystemC as FS;
  FS.Boot -> App.OutBoot;

  App.FiniBoot -> FS;
}
