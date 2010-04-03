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

/**
 * @author Kevin Klues <klueska@cs.stanford.edu>
 * @author Eric B. Decker <cire831@gmail.com>
 */
 
generic configuration mm3BlockingSpi1C() {
  provides {
    interface BlockingResource;
    interface BlockingSpiByte;
    interface BlockingSpiPacket;
    interface ResourceConfigure as SpiResourceConfigure;
  }
  uses interface ResourceConfigure;
}

implementation {
  components new BlockingResourceC();
  components new BlockingSpiP();
  
  BlockingResource  = BlockingResourceC;
  BlockingSpiByte   = BlockingSpiP;
  BlockingSpiPacket = BlockingSpiP;
  
  components new mm3Spi1C() as SPI_1;
//  components new Msp430Spi1C() as SPI_1;
  SpiResourceConfigure = SPI_1;
  ResourceConfigure = SPI_1;
  BlockingResourceC.Resource -> SPI_1;
  BlockingSpiP.SpiByte -> SPI_1;
  BlockingSpiP.SpiPacket -> SPI_1;
  
  components SystemCallC;
  BlockingSpiP.SystemCall -> SystemCallC;
}
