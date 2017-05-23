/**
 * Copyright (c) 2017 Daniel J. Maltbie
 * All rights reserved.
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
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
 */

/**
 * TagnetC - this component provides the nesc configuration for the Tagnet
 * protocol stack.
 *
 * A full Tagnet name identifies a named data item of a specific type (e.g,
 * integer, string, file). The collection of names represents all of the
 * externally accessible variables and functions provided by this node
 * using the Tagnet protocol. All of the possible names are defined
 * in a directed acyclical graph, where each node in the
 * graph represents an element of a name.
 * Processing a named data request consists of processing the elements of
 * the name by traversing the the name in the Tagnet message through
 * the nodes of the DAG until reaching the terminus of the name. The
 * terminus can be name any intermediate node in the DAG or else the
 * leaf node. In the case of intermiedate nodes, the request operates
 * like a reference to a directory in a filesystem, whereas a reference
 * to a leaf node provides access to the contents of the named data item
 * based on the leaf node's type.
 *
 * interface files:
 *   TagnetHeader.nc   - methods for accessing a Tagnet packet header
 *   TagnetName.nc     - methods for acessing and evaluating a Tagnet packet name
 *   TagnetPayload.nc  - methods for accessing a Tagnet packet payload
 *   TagnetTLV.nc      - methods for parsing and building Tagnet TLVs
 *
 * implementation files:
 *   TagnetNameElementP.nc - generic module handles common name elements
 *   TagnetNameRootP.nc    - generic module handles special root name element
 *   TagnetNamePollP.nc    - generic module handles Tagnet poll request
 *   TagnetNameIntegerP.nc - generic module handles an integer named data item
 *
 */

#include "Tagnet.h"
#include "TagnetTLV.h"

configuration TagnetC {
  provides interface Tagnet;
  provides interface TagnetName;
  provides interface TagnetPayload;
  provides interface TagnetTLV;
  provides interface TagnetHeader;
}
implementation {
  components TagnetUtilsC;
  TagnetName = TagnetUtilsC;
  TagnetPayload = TagnetUtilsC;
  TagnetTLV = TagnetUtilsC;
  TagnetHeader = TagnetUtilsC;

  // root of Name tree, provides external interface
  components      TagnetNameRootP  as  RootVx;

  // instantiate each of the nodes (vertices) in the Name tree
  components new  TagnetNameElementP(TN_TAG_ID, UQ_TN_TAG)            as TagVx;
  components new  TagnetNameElementP(TN_POLL_ID, UQ_TN_POLL)          as PollVx;
  components new  TagnetNameElementP(TN_POLL_NID_ID, UQ_TN_POLL_NID)  as PollNidVx;
  components new  TagnetNamePollP   (TN_POLL_EV_ID)                   as PollEvLf;

  // now add the edges to complete the tree, connecting the nodes appropriately
  Tagnet          =  RootVx.Tagnet;
  TagVx.Super     -> RootVx.Sub[unique(UQ_TN_ROOT)];
  PollVx.Super    -> TagVx.Sub[unique(UQ_TN_TAG)];
  PollNidVx.Super -> PollVx.Sub[unique(UQ_TN_POLL)];
  PollEvLf.Super  -> PollNidVx.Sub[unique(UQ_TN_POLL_NID)];
#ifdef notdef
  Tagnet          =  RootVx;
  PollEvLf.Super  -> RootVx.Sub[unique(UQ_TN_ROOT)];
#endif

}
