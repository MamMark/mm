
/*
 * Copyright @ 2010 Carl W. Davis, Eric B. Decker
 * @author Carl W. Davis
 * @author Eric B. Decker
 *
 * Configuration and wiring for sdP for backdoor commands to the SD card.
 */


configuration sdC {}

implementation {
  components sdP;
  components MainC;
  sdP.Boot -> MainC;

 components SDspC;
   //sdP.SDread  -> SDspC.SDread[0];
   //sdP.SDreset -> SDspC;
   sdP.SDraw -> SDspC;

  components FileSystemC as FS;
  sdP.FS_OutBoot -> FS;

  components SD_PwrConfigC as Pwr;
  sdP.PwrMgr <- Pwr;
}
