/**
 * Copyright (c) 2016-2017 Dan Maltbie
 * Copyright (c) 2017 Eric B. Decker
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

  components PlatformC;
  Si446xCmdP.Platform    -> PlatformC;

  Si446xCmdP.HW -> HplSi446xC;    /* Si446xInterface (hw interface) */
}
