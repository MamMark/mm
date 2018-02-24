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

#ifndef __IMAGE_INFO_H__
#define __IMAGE_INFO_H__

#define IMAGE_INFO_SIG  0x33275401

/*
 * IMAGE_META_OFFSET is the offset into the image where
 * image_info lives in the image.  It directly follows
 * the exception vectors which are 0x140 bytes long.
 *
 * If the vector length changes, this value will have to
 * change.
 */
#define IMAGE_META_OFFSET 0x140
#define IMAGE_MIN_SIZE    (IMAGE_META_OFFSET + sizeof(image_info_t))

typedef struct {                        /* little endian order  */
  uint16_t build;                       /* that's native for us */
  uint8_t  minor;
  uint8_t  major;
} image_ver_t;

typedef struct {
  uint8_t  hw_rev;
  uint8_t  hw_model;
} hw_ver_t;

#define IMAGE_DESCRIPTOR_MAX 44
#define ID_MAX               44

/*
 * Image description structure
 *
 * fields with 'b' filled in by build process (make)
 * fields with 's' filled in by 'stamp' program after building.
 */
typedef struct {
  uint32_t    ii_sig;                   /*  b  must be IMAGE_INFO_SIG to be valid */
  uint32_t    image_start;              /*  b  where this binary loads            */
  uint32_t    image_length;             /*  b  byte length of entire image        */
  uint32_t    vector_chk;               /*  s  simple checksum over vector table  */
  uint32_t    image_chk;                /*  s  simple checksum over entire image  */
  image_ver_t ver_id;                   /*  b  version string of this build       */
  uint8_t     descriptor0[ID_MAX];      /*  s  main tree tinyos/prod descriptor   */
  uint8_t     descriptor1[ID_MAX];      /*  s  aux  tree MamMark descriptor       */
  uint8_t     stamp_date[30];           /*  s  build time stamp */
  hw_ver_t    hw_ver;                   /*  b  and last 2 bytes */
} image_info_t;

/*
 * stamp_date is a null terminated string that contains the date (UTC)
 * of when this image was built (actally when the binfinish program was
 * run).  binfinish is used to set the checksums, stamp_date, and the
 * git descriptors of the binary image.
 *
 * stamp_date gets filled in with "date -u".
 *
 * descriptor{0,1} are descriptor strings that identify the code base used to
 * build this image.
 *
 * each descriptor is generated using:
 *
 *      git describe --all --long --dirty
 *
 * sha information is abbreviated to 7 digits (default).  This should work
 * for both the MamMark as well as the Prod/tinyos-main repositories.  There
 * is enough additional information to enable finding where on the tree this
 * code base was built from.
 *
 * If the descriptor becomes larger that ID_MAX then one can lose characters
 * from the front of the string, typically <name>/ can be removed safely.
 *
 * The descriptors should be null terminated and this null counts as one of
 * the characters in ID_MAX.
 */

#endif  /* __IMAGE_INFO_H__ */
