
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
   sdP.SDraw -> SDspC;

  components SDsaC;
  sdP.SDsa -> SDsaC;

  components FileSystemC as FS;
  sdP.FS_OutBoot -> FS;

  components Hpl_MM_hwC as HW;
  sdP.HW -> HW;

  components HplMsp430UsciB0C as UsciC;
  sdP.Usci -> UsciC;
}
