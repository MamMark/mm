/*
 * Copyright (c) 2010, Eric B. Decker, Carl W. Davis
 * All rights reserved.
 *
 * @author Eric B. Decker
 * @author Carl W. Davis
 */

#include "sd_cmd.h"

interface SDraw {
  command void      start_op();
  command void      end_op();
  command uint8_t   get();
  command void      put(uint8_t byte);
  command sd_cmd_t *cmd_ptr();
  command uint8_t   send_cmd();
  command uint8_t   raw_acmd();
  command uint8_t   raw_cmd();
  command void      send_recv(uint8_t *tx, uint8_t *rx, uint16_t len);
}
