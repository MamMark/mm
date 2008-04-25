/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

interface SD {
  /**
   * Read and Write
   *
   * Read or write sectors (512 bytes) to or from the Secure Disk.  Access
   * to the disk is in fixed sized sectors of 512 bytes.
   *
   * Sectors are addressed by block addresses (sector addresses) starting
   * at 0 and running up to the size of the device.  (Currently no way to
   * get the size but this doesn't matter because the StreamStorage component
   * won't ask for anything beyond the limits of the disk sections).
   *
   * If SUCCESS is returned, then the corresponding Done event will be signalled
   *
   * @param blk         sector address to start reading or writing.
   * @param buf         buffer to place read data or write data from.
   * @return 
   *   <li>SUCCESS if the request was accepted, 
   *   <li>EINVAL if the parameters are invalid
   *   <li>EBUSY if a request is already being processed.
   */
  command error_t read(uint32_t blk, void *buf);
  event   void    readDone(uint32_t blk, void *buf);
  command error_t read_direct(uint32_t blk, void *buf);

  command error_t write(uint32_t blk, void *buf);
  event   void    writeDone(uint32_t blk, void *buf);
  command error_t write_direct(uint32_t blk, void *buf);

  command error_t reset();
}
