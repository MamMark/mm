/*
 * Copyright (c) 2017 Daniel J. Maltbie, Eric B. Decker
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
 */

#ifndef __OVERWATCH_H__
#define __OVERWATCH_H__

/*
 * ow_boot_mode_t
 *
 * The Overwatcher supports three possible bootable instances:
 *
 * NIB        Normal Image Block (Bank 1).
 *            The installable application code is in bank 1 of
 *            Flash (upper 128K)
 *
 * OWT        Overwatcher TinyOS.
 *            The Golden Image implementing the Overwatch
 *            functionality.  OWT is OverWatch Tinyos.  It is
 *            a specialized application and support infrastructure
 *            for implementing Overwatch functionality.
 *
 * GOLD       Factory installed "Golden" image of the Tag
 *            application code.  Handles Chirp mode?
 *            When all else fails this is the image we run.
 */
typedef enum {
  OW_BOOT_OWT   = 0,                    //  [default]
  OW_BOOT_GOLD  = 1,
  OW_BOOT_NIB   = 2,
} ow_boot_mode_t;


/*
 * ow_request_t
 *
 * When a running image needs to make a request of Overwatch
 * these are the possible requests that can be made.
 *
 * REQ_INSTALL  Install new code image into the NIB (Bank 1).
 *              Image is marked as active in the Image Directory.
 *
 * REQ_REBOOT   Reboot the current ow_boot_mode, test for too
 *              many boot failures and fall back accordingly.
 *
 * REQ_OWT      Boot into the Overwatch TinyOS application.
 * REQ_GOLD     Boot into the Golden image (bank 0).
 * REQ_NIB      Boot into the Normal Image Block (bank 1).
 */
typedef enum  {
  OW_REQ_NONE           = 0,            //   [default]
  OW_REQ_INSTALL        = 1,
  OW_REQ_REBOOT         = 2,
  OW_REQ_OWT            = 3,
  OW_REQ_GOLD           = 4,
  OW_REQ_NIB            = 5,
} ow_request_t;


/*
 * OWT implements the following actions.  For various reasons
 * these actions must be handled using TinyOS code.
 *
 * ACT_INIT     The OW control block reinialized and we must
 *              determine what is a reasonable boot state.
 *              This information is out on the SD and we need
 *              to ask the ImageManager for the current state.
 *
 * ACT_INSTALL  OWT will install the SD image marked as active into
 *              the NIB and reboot.
 *
 * ACT_EJECT      The currently executing image (must be NIB) has had
 *              too many problems.  Mark it as ejected, and make the
 *              Backup Image (if present) as the new active.  (Will
 *              need to be installed.
 *
 *              If not backup is available, then run the Golden
 *              image.
 */
typedef enum  {
  OWT_ACT_INIT          = 0,            //   [default]
  OWT_ACT_INSTALL       = 1,
  OWT_ACT_EJECT         = 2,
} owt_action_t;


typedef enum {
  OWE_OK             = 0,
  OWE_PANIC,
  OWE_HARD_FAULT,
} ow_reboot_reasion_t;

/*
 * ow_control_block_t
 *
 * 
 */
typedef struct {
  uint32_t           ow_sig;
  uint32_t           cycle;
  uint32_t           time;
  ow_request_t       ow_req;
  ow_reboot_reasion_t reboot_reason;
  uint8_t            ow_from_nib;
  ow_boot_mode_t     ow_boot_mode;
  owt_action_t       owt_action;
} ow_control_block_t;

/*
 * OW_SIG
 *
 * Used to verify ow_control_block has been initialized.
 * First initialized upon Power-On Reset or when memory
 * corruption has been detected.
 */
#define OW_SIG 0xFABAFABA

/*
 * The ow_control_block lives in a well-defined section of SRAM and
 * is outside of any areas initialized by the operating system.
 *
 */
ow_control_block_t ow_control_block __attribute__ ((section(".overwatch_data")));

#endif  /* __OVERWATCH_H__ */
