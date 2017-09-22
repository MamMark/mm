/*
 * Copyright (c) 2017 Eric B. Decker, Miles Maltbie
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

#include <image_mgr.h>

interface ImageManager {
  command error_t alloc(image_ver_t ver_id);
  command error_t alloc_abort();

  command uint32_t write(uint8_t *buf, uint32_t len);
  event   void     write_continue();

  command error_t finish();
  event   void    finish_complete();

  command error_t delete(image_ver_t ver_id);
  event   void    delete_complete();

  command error_t dir_set_active(image_ver_t ver_id);
  event   void    dir_set_active_complete();

  command error_t dir_set_backup(image_ver_t ver_id);
  event   void    dir_set_backup_complete();

  command error_t dir_eject_active();
  event   void    dir_eject_active_complete();

  command bool check_fit(uint32_t len);
  command bool verEqual(image_ver_t *ver0, image_ver_t *ver1);

  command image_dir_slot_t *dir_get_active();
  command image_dir_slot_t *dir_get_dir(uint8_t idx);
  command image_dir_slot_t *dir_find_ver(image_ver_t ver_id);

  command bool dir_coherent();
}
