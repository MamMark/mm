/*
 * Copyright (c) 2008, 2010, Eric B. Decker
 * All rights reserved.
 *
 * Data, Typed: Sender.   Used to send typed data blocks out a comm stream.
 * typed with AM_MM_DT.
 */

interface DTSender {
  command error_t send(void *buf, uint8_t buf_len);
  event void sendDone(error_t rtn);
}
