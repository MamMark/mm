/*
 * Copyright (c) 2008 Stanford University.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * - Redistributions of source code must retain the above copyright
 *   notice, this list of conditions and the following disclaimer.
 * - Redistributions in binary form must reproduce the above copyright
 *   notice, this list of conditions and the following disclaimer in the
 *   documentation and/or other materials provided with the
 *   distribution.
 * - Neither the name of the Stanford University nor the names of
 *   its contributors may be used to endorse or promote products derived
 *   from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL STANFORD
 * UNIVERSITY OR ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
 * STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
 * OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
/*
 * Author: Kevin Klues (klueska@cs.stanford.edu)
 *
 */
 
#include "stream_storage.h"

configuration StreamStorageWriterC {
  provides interface Boot as SSWBoot;
  uses interface Boot;
}

implementation {
  
//  components MainC;
//  MainC.SoftwareInit -> StreamStorageWriterP;

  components StreamStorageWriterP as SSW_P, StreamStorageC;
  SSW_P.StreamStorage -> StreamStorageC;
  SSW_P.SSControl -> StreamStorageC;

  Boot = SSW_P.Boot;
  SSWBoot = BlockingBootC;

  components new BlockingBootC();
  BlockingBootC -> SSW_P.BlockingBoot;

  /*
   * Not sure of the stack size needed here
   * If things seems to break make it bigger...
   *
   * We need to implement stack guards
   * This will also give us an idea of how deep the stacks have been
   */

  components new ThreadC(300); 
  SSW_P.Thread -> ThreadC;
  
  components new QueueC(ss_buf_handle_t*, SS_NUM_BUFS);
  SSW_P.Queue -> QueueC;
    
  components SemaphoreC;
  SSW_P.Semaphore -> SemaphoreC;
}
