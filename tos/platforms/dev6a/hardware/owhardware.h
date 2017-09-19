/*
 * Copyright (c) 2017 Eric B. Decker
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
 * @author Eric B. Decker <cire831@gmail.com>
 */

/*
 * Defines for various OverWatch HW interface things.
 */

/*
 * ResetStatus
 *
 * ResetStatus is a mutated status made up of various h/w
 * reset/reboot status registers.
 *
 * OW_bits are bits on the h/w
 */

enum {

/* RSTCTL->HARDRESET_STAT */
#define OW_HARD_SYSRESET_BIT    0x00000001
#define OW_HARD_WD_TO_BIT       0x00000002
#define OW_HARD_WD_PW_BIT       0x00000004
#define OW_HARD_FLCTL_BIT       0x00000008
#define OW_HARD_OW_REBOOT_BIT   0x00000010
#define OW_HARD_CS_BIT          0x40000000
#define OW_HARD_PCM_BIT         0x80000000

  RST_SYSRESET  = 0x00000001,           /* core reset           */
  RST_WD_TO     = 0x00000002,           /* watchdog time out    */
  RST_WD_PW     = 0x00000004,           /* watchdog passwd viol */
  RST_FLCTL     = 0x00000008,           /* flash control fault  */
  RST_OW_REBOOT = 0x00000010,           /* overwatch reboot     */
  RST_CS        = 0x40000000,           /* clock system glitch  */
  RST_PCM       = 0x80000000,           /* power control module */

/* RSTCTL->SOFTRESET_STAT */
#define OW_SOFT_CPU_LOCKUP_BIT  0x00000001
#define OW_SOFT_SWD_TO_BIT      0x00000002
#define OW_SOFT_SWD_PW_BIT      0x00000004

  RST_CPU_LOCKUP= 0x00000020,           /* cpu lockup, oops          */
  RST_SWD_TO    = 0x00000040,           /* soft watchdog time out    */
  RST_SWD_PW    = 0x00000080,           /* soft watchdog passwd viol */

/* RSTCTL->PSSRESET_STAT */
#define OW_PSS_SVSMH_BIT        0x00000002
#define OW_PSS_BGREF_BIT        0x00000004
#define OW_PSS_VDDDET_BIT       0x00000008

  RST_SVSMH     = 0x00000100,           /* System Volt Supervisor, H */
  RST_BGREF     = 0x00000200,           /* Band Gap Ref fault        */
  RST_VDDDET    = 0x00000400,           /* VDD Detect fault          */

/* RSTCTL->PCMRESET_STAT */
#define OW_PCM_LPM35_BIT        0x00000001
#define OW_PCM_LPM45_BIT        0x00000002

  RST_LPM35_EXIT= 0x00000800,           /* POR due to LPM3.5 exit    */
  RST_LPM45_EXIT= 0x00001000,           /* POR due to LPM4.5 exit    */

/* RSTCTL->PINRESET_STAT */
#define OW_PIN_BIT              0x00000001

  RST_RSTNMI    = 0x00002000,           /* Reset/NMI pin             */

/* RSTCTL->REBOOTRESET_STAT */
#define OW_REBOOT_BIT           0x00000001

  RST_REBOOT    = 0x00004000,           /* Reboot */

/* RSTCTL->CSRESET_STAT */
#define OW_CS_DCORSHT_BIT       0x00000001

  RST_DCORSHT   = 0x00008000,           /* dco ext resistor fault    */
};
