/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

configuration TestSDArbC {}

implementation {
  components TestSDArbP as App;
  components MainC;
  App.Boot -> MainC.Boot;

  components new SD_ArbC() as SD;
  App.Resource -> SD;
  App.SDread   -> SD;
  App.SDwrite  -> SD;
  App.SDerase  -> SD;

  components FileSystemC as FS;
  App.FS_OutBoot -> FS;
  App.Out_Boot   <- FS;
}
