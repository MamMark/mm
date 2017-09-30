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

typedef struct {
  uint32_t    sig;                      /* must be IMAGE_INFO_SIG to be valid */
  uint32_t    image_start;              /* where this binary loads            */
  uint32_t    image_length;             /* byte length of entire image        */
  uint32_t    vector_chk;               /* simple checksum over vector table  */
  uint32_t    image_chk;                /* simple checksum over entire image  */
  image_ver_t ver_id;
  uint8_t     descriptor0[ID_MAX];      /* main tree descriptor */
  uint8_t     descriptor1[ID_MAX];      /* aux  tree descriptor */
  uint8_t     stamp_date[30];           /* build time stamp */
  hw_ver_t    hw_ver;                   /* and last 2 bytes */
} image_info_t;

/*
 * stamp_date is a null terminated string that contains the date (UTC)
 * of when this image was built (actally when the tag_finish program was
 * run).  Tag_finish is used to set the checksums, stamp_date, and the
 * git descriptors.
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
