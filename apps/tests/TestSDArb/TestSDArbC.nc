/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 */

configuration TestSDArbC {}

implementation {
  components TestSDArbP as App;
  components MainC;
  App.Boot -> MainC.Boot;

  components new SD_ArbC();
  App.Resource -> SD_ArbC;

  components SDspC, FileSystemC as FS;
  App.SDread -> SDspC;
  App.FS_OutBoot -> FS;
}
