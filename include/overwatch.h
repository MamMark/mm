/*
 * Copyright (c) 2017-2018, Daniel J. Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *          Daniel J. Maltbie <dmaltbie@danome.com>
 */

#ifndef __OVERWATCH_H__
#define __OVERWATCH_H__

#ifndef PACKED
#define PACKED __attribute__((__packed__))
#endif

/*
 * definintions for NIB access
 *
 * NIB_BASE:    where the NIB image starts
 * NIB_INFO:    where the NIB's image_info block starts
 * NIB_VEC_COUNT: count of how many vectors need to be summed when verifing
 *              the NIBs vector table.  Each entry is 4 bytes wide.
 */

#define NIB_BASE        0x00020000
#define NIB_INFO        (NIB_BASE + 0x140)
#define NIB_VEC_COUNT   (64 + 14 + 2)
#define NIB_VEC_BYTES   (NIB_VEC_COUNT * 4)


/*
 * ow_boot_mode_t
 *
 * The OverWatcher supports three possible bootable instances:
 *
 * GOLD       Factory installed "Golden" image of the Tag
 *            application code.  Handles Chirp mode?
 *            When all else fails this is the image we run.
 *
 * OWT        OverWatch TinyOS.
 *            The Golden Image implementing the OverWatch
 *            functionality.  OWT is OverWatch Tinyos.  It is
 *            a specialized application and support infrastructure
 *            for implementing OverWatch functionality.
 *
 * NIB        Normal Image Block (Bank 1).
 *            The installable application code is in bank 1 of
 *            Flash (upper 128K)
 */

typedef enum {
  OW_BOOT_GOLD  = 0,
  OW_BOOT_OWT   = 1,
  OW_BOOT_NIB   = 2,
} ow_boot_mode_t;


/*
 * ow_request_t
 *
 * When a running image needs to make a request of OverWatch
 * these are the possible requests that can be made.
 *
 * REQ_BOOT     boot according to boot_mode
 *
 * REQ_INSTALL  Install new code image into the NIB (Bank 1).
 *              Image is marked as active in the Image Directory.
 *
 * REQ_REBOOT   Running image crashed.  Reboot the current ow_boot_mode,
 *               test for too many boot failures and fall back accordingly.
 */

typedef enum  {
  OW_REQ_BOOT           = 0,            /* just boot, see ow_boot_mode */
  OW_REQ_INSTALL        = 1,
  OW_REQ_FAIL           = 2,            /* crash, rebooting */
} ow_request_t;


/*
 * OWT implements the following actions.  For various reasons
 * these actions must be handled using TinyOS code.
 *
 * ACT_INIT     The OW control block has been reinitialized and we must
 *              determine what is our current boot state.  This information
 *              is out on the SD so we need to ask the ImageManager for the
 *              current state.
 *
 * ACT_INSTALL  OWT will install the SD image marked as active into
 *              the NIB and reboot.
 *
 * ACT_EJECT    The currently executing image (it must be the NIB) has
 *              had too many problems.  Mark it as ejected, and make the
 *              Backup Image (if present) as the new active.  (Will
 *              need to be installed.
 *
 *              If no backup is available, then run the Golden image.
 */

typedef enum  {
  OWT_ACT_NONE = 0,
  OWT_ACT_INIT,
  OWT_ACT_INSTALL,
  OWT_ACT_EJECT,
} owt_action_t;


/* Reboot reasons */
typedef enum {
  ORR_NONE              = 0,
  ORR_FAIL,                             /* catch all for the time being          */
  ORR_OWCB_CLOBBER,                     /* lost the control block, full pwr fail */
  ORR_STRANGE,                          /* low level strangness                  */
  ORR_FORCED,                           /* forced boot mode                      */
  ORR_TIME_SKEW,                        /* rebooted because too much time skew   */
  ORR_USER_REQUEST,                     /* user requested reboot                 */
  ORR_PANIC,                            /* hem, something blew up                */
  ORR_LOW_PWR,                          /* reboot, switching from low to normal  */
} ow_reboot_reason_t;


/*
 * OW_SIG
 *
 * Used to identify that the ow_control_block has been properly
 * initialized.  If the sig is valid we assume it is sane.  If we want to
 * be extra paranoid we can checksum it.  But that is a pain.
 */
#define OW_SIG      0xFABAFABA
#define OW_BASE_UNK 0xFFFFFFFF


/*
 * OW_RPT_FLAGS (OWRF)
 */

enum {
  OWRF_LAUNCH  = 1,                     /* in process of an image launch */
                                        /* gets cleared when reboot record is written */
};


/*
 * fault bits.  Indicate various subsystems failed.
 */
enum {
  OW_FAULT_DCOR    = 1,                 /* DCO calibration resistor failed            */
  OW_FAULT_32K     = 2,                 /* main time base failed, running on backup   */
  OW_FAULT_LOW_PWR = 4,                 /* in low power mode, no sd, no 3V3 rail      */
  OW_FAULT_POR     = 0x80000000,        /* full power on reset                        */
};


/*
 * Subsystem Disable.
 *
 * When bit set the subsystem isn't working, don't mess with it.
 */


/*
 * ow_control_block_t
 */
typedef struct {
  uint32_t           ow_sig;
  uint32_t           ow_rpt_flags;      /* reporting flags */
  uint64_t           uptime;            /* req input, time since last boot */
  uint32_t           reset_status;      /* recognized stati                */
  uint32_t           reset_others;      /* unindentified other stati       */
  uint32_t           from_base;         /* base address of where from      */
  uint32_t           fail_count;        /* how many times nib failed       */

  uint32_t           fault_mask_gold;   /* indicate faults                 */
  uint32_t           fault_mask_nib ;   /* indicate faults                 */
  uint32_t           subsys_disable;    /* what's turned off               */

  uint32_t           ow_sig_b;

  ow_request_t       ow_req;            /* B - req input */
  ow_reboot_reason_t reboot_reason;     /* B - req input */

  ow_boot_mode_t     ow_boot_mode;      /* B - control knob */
  owt_action_t       owt_action;        /* B - input to OWT, further actions */

  /*
   * Persistent storage.
   *
   * OverWatch keeps track of some system parameters.
   * This is persistent in that it survives across reboots.
   * However it is not nonvolitle ram and doesn't survive
   * across power fails.
   *
   * "elapsed" keeps a running total of how long we have been
   * up since last full pwr cycle (full means we lost RAM).
   *
   * elapsed is a 64 bit time and needs to be 2quad aligned.
   */

  uint32_t           reboot_count;      /* reboots since pwr came up      */
  uint64_t           elapsed;           /* total time since pwr on, 2quad */

  uint32_t           strange;           /* strange shit */
  uint32_t           strange_loc;
  uint32_t           vec_chk_fail;
  uint32_t           image_chk_fail;

  uint32_t           ow_sig_c;
} PACKED ow_control_block_t;


/*
 * The ow_control_block lives in a well-defined section of SRAM and
 * is outside of any areas utilized by any of the typical software modules.
 *
 * ow_control_block_t ow_control_block __attribute__ ((section(".overwatch_data")));
 *
 * typically the ow_control_block will reside in OverWatchP.  Outside the implementation
 * block as it needs to be found by other modules and the startup code.
 */

#endif  /* __OVERWATCH_H__ */
