/*
 * Copyright (c) 2008 Stanford University.
 * Copyright (c) 2008 Eric B. Decker
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
 
/* code development: Eric B. Decker
 * Author: Eric B. Decker (cire831@gmail.com)
 *
 * original structure and wiring: Kevin Klues
 * Author: Kevin Klues (klueska@cs.stanford.edu)
 *
 * This module implements the thread based pieces of the disk based
 * stream storage.
 *
 * We use one thread to conserve resources and to serialize any requests
 * to the streaming device.  On Boot the first thing that is done is
 * initilization (see StreamStorageP).
 */
 
module StreamStorageWriterP {
  provides interface Boot as BlockingBoot;
  uses {
    interface Boot;
    interface Queue<ss_buf_handle_t*>;
    interface Thread;
    interface StdControl as SSControl;
    interface StreamStorage;
    interface Semaphore;
    interface Panic;
  }
}

implementation {
  semaphore_t sem;

  event void Boot.booted() {
    call Semaphore.reset(&sem, 0);
    call Thread.start(NULL);
  }
  
  event void Thread.run(void* arg) {
    ss_buf_handle_t* current_handle;

    /*
     * First start up and read in control blocks.
     * Then signal we have booted.
     */
    call SSControl.start();
    signal BlockingBoot.booted();

    for(;;) {
      call Semaphore.acquire(&sem);
      current_handle = call Queue.dequeue();
      call StreamStorage.flush_buf_handle(current_handle);
    }
  }
  
  event void StreamStorage.buffer_ready(ss_buf_handle_t *handle) {
    call Queue.enqueue(handle);
    call Semaphore.release(&sem);
  }
}
