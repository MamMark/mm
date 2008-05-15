/*
 * Copyright (c) 2008 Eric B. Decker
 * All rights reserved.
 */

/**
 * Blocking version of SpiPacket.
 * Only implements send.
 *
 * @author Eric B. Decker
 */

interface BlockingSpiPacket {

  /**
   * Send a message over the SPI bus.
   *
   * @param txBuf A pointer to the buffer to send over the bus. If this
   *              parameter is NULL, then the SPI will send zeroes.
   * @param rxBuf A pointer to the buffer where received data should
   *              be stored. If this parameter is NULL, then the SPI will
   *              discard incoming bytes.
   * @param len   Length of the message.  Note that non-NULL rxBuf and txBuf
   *              parameters must be AT LEAST as large as len, or the SPI
   *              will overflow a buffer.
   *
   * @return SUCCESS if the request was accepted for transfer
   */
  command error_t send(uint8_t* txBuf, uint8_t* rxBuf, uint16_t len);
}
