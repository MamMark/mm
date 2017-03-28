/*
 * Copyright (c) 2008, 2010 Eric B. Decker
 * Copyright (c) 2008 Stanford University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 *
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 *
 * - Neither the name of the copyright holders nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 *
 * @author Kevin Klues <klueska@cs.stanford.edu>
 * @date March 3rd, 2008
 *
 * @author Eric B. Decker <cire831@gmail.com>
 * @date May 5th, 2008
 * reworked Apr 21st, 2010
 *
 * Sequence the bootup.  Components that should fire up when the
 * system is completely booted should wire to SystemBootC.Boot.
 *
 * 1) Bring up the comm stack first so we can watch
 *    what is happening via the Debug port.
 * 2) Bring up the SD/StreamStorage
 * 3) Collect initial status information (Restart and Version)  mmSync
 * 4) Bring up the GPS.  (GPS assumes SS is up)
 *
 * Originally Serial/Radio, StreamStorage, and GPS all used the same
 * hardware path, so they were serialized.  With new hardware there
 * are independent h/w paths.  We could possibly interleave but it
 * is simpler to debug serially.  Also there is only one cpu so unclear
 * how to increase the parallelism.  If the boot up time is an issue
 * this can be addressed later.
 */

#error using tos/system/SystemBootC, should use platform SystemBootC

configuration SystemBootC {
  provides interface Boot;
  uses interface Init as SoftwareInit;
}

implementation {
  components MainC;
  SoftwareInit = MainC.SoftwareInit;

  components CommBootC;
  components FileSystemC as FS;
  components mmSyncC;
#ifdef GPS_TEST
  components GPSC;
#endif

  CommBootC.Boot -> MainC;	// Main kicks Comm (serial/radio)
  FS.Boot -> CommBootC;		//    which kicks FileSystem bootstrap
  mmSyncC.Boot -> FS;		//        then write initial status
#ifdef GPS_TEST
  GPSC.Boot -> mmSyncC;		//            and then GPS.
  Boot = GPSC;			// bring up everyone else
#else
  Boot = mmSyncC;
#endif
}
