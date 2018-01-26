/*
 * Copyright (c) 2017 Eric B. Decker
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
 */

/*
 * Definitions for Platform Resets
 */

#ifndef __PLATFORM_RESET_DEFS_H__
#define __PLATFORM_RESET_DEFS_H__

#include <sysreboot.h>

enum {
  SYSREBOOT_OW_REQUEST = SYSREBOOT_EXTEND,

  /* bits from RSTCTL->HARDRESET_STAT */
  RST_HARD_SYSRESET = RSTCTL_HARDRESET_STAT_SRC0,       /* sys reset output, core */
  RST_HARD_WDT_TO   = RSTCTL_HARDRESET_STAT_SRC1,       /* WDT time out           */
  RST_HARD_WDT_PWV  = RSTCTL_HARDRESET_STAT_SRC2,       /* WDT password violation */
  RST_HARD_FLCTL    = RSTCTL_HARDRESET_STAT_SRC3,       /* Flash Controller Fault */
  RST_HARD_OW_REQ   = RSTCTL_HARDRESET_STAT_SRC4,       /* OverWatch Request      */
  RST_HARD_CS       = RSTCTL_HARDRESET_STAT_SRC14,      /* Clock System fault     */
  RST_HARD_PCM      = RSTCTL_HARDRESET_STAT_SRC15,      /* Power Control fault    */
};

#define PRD_RESET_KEY   RSTCTL_RESETREQ_RSTKEY_VAL
#define PRD_RESET_HARD  RSTCTL_RESET_REQ_HARD_REQ
#define PRD_RESET_SOFT  RSTCTL_RESET_REQ_SOFT_REQ

#define PRD_RESET_OW_REQ RSTCTL_HARDRESET_STAT_SRC4

#define PRD_PSS_VCCDET  RSTCTL_PSSRESET_STAT_VCCDET
#define PRD_PSS_SVSH    RSTCTL_PSSRESET_STAT_SVSMH
#define PRD_PSS_BGREF   RSTCTL_PSSRESET_STAT_BGREF

#define PRD_CS_DCOR_SHT RSTCTL_CSRESET_STAT_DCOR_SHT

#endif    /* __PLATFORM_RESET_DEFS_H__ */
