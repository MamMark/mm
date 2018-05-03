/*
 * Copyright (c) 2017-2018 Eric B. Decker
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
  uint8_t     image_desc[ID_MAX];       /*  s  generic descriptor                 */
  uint8_t     repo_desc0[ID_MAX];       /*  s  main tree tinyos/prod descriptor   */
  uint8_t     repo_desc1[ID_MAX];       /*  s  aux  tree MamMark descriptor       */
  uint8_t     stamp_date[30];           /*  s  build time stamp */
  hw_ver_t    hw_ver;                   /*  b  and last 2 bytes */
} image_info_t;

/*
 * 'binfin' (tools/utils/binfin) is used to fill in the following cells:
 *
 *      o vector_chk
 *      o image_chk
 *      o image_desc
 *      o repo_desc0
 *      o repo_desc1
 *      o stamp_date
 *
 * image_desc is a general string (null terminated) that can be used to
 * indicate what this image is, released, development, etc.  It is an
 * arbitrary string provided to binfin and placed into image_desc.
 *
 * repository{0,1} are descriptor strings that identify the code repositories
 * used to build this image.
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
 * If the descriptor becomes larger than ID_MAX, characters can be removed
 * from the front of the string, typically <name>/ can be removed safely.
 *
 * Descriptors are NUL terminated.  The NUL byte is included in ID_MAX.
 *
 * stamp_date is a NUL terminated string that contains the date (UTC)
 * this image was stamped by binfin.  Typically this will be when the
 * image was built.  stamp_date gets filled in with "date -u".
 *
 * After filling in image_desc, repository{0,1}, and stamp_date, vector_chk
 * is computed and image_chk is computed over the entire image size.
 *
 * Both vector_chk and image_chk are computed using a 32 bit aligned, 32
 * bit wide checksum.  See tos/lib/ChecksumM.nc.  If the region being
 * summed checks out the resultant sum will be 0.  vector_chk/image_chk
 * must be set to make this happen.
 *
 * vector_chk is the sum over the first 0x140 bytes.  This is the exception
 * vectors of the processor.
 *
 * image_chk is the sum over the entire image.
 *
 * vector_chk, image_desc, repo_desc{0,1}, and stamp_date must be filled in
 * prior to computing the value of image_chk.
 */

#endif  /* __IMAGE_INFO_H__ */
