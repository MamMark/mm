/*
 * Copyright (c) 2018 Eric B. Decker
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

#ifndef __CORE_REV_H__
#define __CORE_REV_H__

/*
 * Core_Rev defines the versioning of the following files:
 *
 * C include headers:   (include)
 *
 *   core_rev.h         yep, this file
 *   dblk_dir.h         directory for the dblk stream
 *   image_info.h       defines image descriptors
 *   overwatch.h        overwatch control block
 *   typed_data.h       definitions of data blocks, data stream
 *   sirf_msg.h         sirf message defines
 *   panic_info.h       external panic definitions
 *
 *   fs_loc.h           directory for file system locators
 *                      (not currently exposed)
 *
 * Python equivalent:   (tagcore)
 *
 *   core_rev.py
 *   core_headers.py
 *     dblk_dir
 *     image_info
 *     overwatch
 *     typed_data
 *   sirf_headers.py
 *   panic_info.py
 *
 * If these files change CORE_REV needs to be bumped.
 *
 * CORE_REV has been split into a 16 bit CORE_REV and a 16 bit CORE_MINOR.
 * CORE_REV gets popped when there are major structural changes in any of
 * the above structural published files above.
 *
 * CORE_MINOR gets popped to indicate there have been minor changes.  Such
 * as adding new events.  These will potentially show up as 'unk' which is
 * fine.
 */

#define CORE_REV   20
#define CORE_MINOR  6

#endif  /* __CORE_REV_H__ */
