/**
 * Copyright @ 2016 Dan Maltbie
 * @author Dan Maltbie
 * All rights reserved.
 */

configuration Si446xCmdC {
  provides interface Si446xCmd;
}
implementation {
  components Si446xCmdP;
  Si446xCmd = Si446xCmdP;
  components TraceC;
  Si446xCmdP.Trace -> TraceC;
  components PanicC;
  Si446xCmdP.Panic -> PanicC;

  components HplSi446xC;
  Si446xCmdP.FastSpiByte -> HplSi446xC;
  Si446xCmdP.SpiByte     -> HplSi446xC;
  Si446xCmdP.SpiBlock    -> HplSi446xC;

#ifdef REQUIRE_PLATFORM
  components PlatformC;
  Si446xCmdP.Platform    -> PlatformC;
#endif

  Si446xCmdP.LocalTime-> HplSi446xC.LocalTimeRadio;

  Si446xCmdP.HW -> HplSi446xC;    /* Si446xInterface (hw interface) */

}

