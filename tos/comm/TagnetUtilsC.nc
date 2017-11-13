/**
 * This configuration combines several modules providing interfaces
 * to access a Tagnet Message into a single component.
 *<p>
 * Typically the interfaces provided by this configuration are used within the Tagnet stack itself. But there are a few special cases where direct access to the message is required outside of the stack. Otherwise, the stack provides alternative interfaces for adapting network access to system wide data of standard C types.
 *</p>
 *<p>
This includes the following modules:
 *</p>
 *<dl>
 *   <dt>TagnetHeaderP</dt> <dd>module for manipulating the header in a Tagnet message</dd>
 *   <dt>TagnetNameP</dt> <dd>module for manipulating the name in a Tagnet message</dd>
 *   <dt>TagnetPayloadP</dt> <dd>module for manipulating the payload in a Tagnet message</dd>
 *   <dt>TagnetTlvP</dt> <dd>module for manipulating Tagnet TLVs. Found in the name and payload fields of Tagnet message</dd>
 *</dl>
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 * @Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
 *
 */
/*
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
configuration TagnetUtilsC {
  provides interface TagnetName;
  provides interface TagnetHeader;
  provides interface TagnetPayload;
  provides interface TagnetTLV;
}
implementation {
  components     TagnetNameP;
  components     TagnetHeaderP;
  components     TagnetPayloadP;
  components     TagnetTlvP;
  components     PanicC;

  TagnetName            =  TagnetNameP;
  TagnetHeader          =  TagnetHeaderP;
  TagnetPayload         =  TagnetPayloadP;
  TagnetTLV             =  TagnetTlvP;

  TagnetNameP.THdr      -> TagnetHeaderP;
  TagnetNameP.TTLV      -> TagnetTlvP;

  TagnetPayloadP.THdr   -> TagnetHeaderP;
  TagnetPayloadP.TTLV   -> TagnetTlvP;

  TagnetTlvP.Panic      -> PanicC;
}
