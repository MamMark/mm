/**
 * This component provides the main configuration for the Tagnet
 * protocol stack.
 *<p>
 * The Tagnet protocol stack provides the network oriented access
 * to Tag local device information. This information consists of
 * variables exposed by the underlying software and hardware.
 * For instance sensors provide readings and may have settings
 * that can be configured.
 *</p>
 *<p>
 * In Tagnet, each variable in the Tag device is represented by
 * a unique name. A Tagnet name is similar to a Unix file path in
 * that it is constructed from a list of elements (sub-directories)
 * that together identify a specific item in the system. For Tagnet,
 * the name identifies a variable of a specific type (e.g, integer,
 * string, file). The collection of Tagnet names represents all of
 * the externally accessible variables and functions provided by
 * this node using the Tagnet protocol.
 * All of the possible names are defined in a directed acyclical
 * graph, or tree, where each node in the graph represents an
 * element of a name. The terminal element of the name is connected
 * to an individual variable in the system. The stack provides the
 * means to traverse a name in a given message through the tree and
 * perform the requested operation on that element when a match
 * is found.
 *</p>
 *<p>
 * The Tagnet protocol defines different message types for operating
 * on the Tag device named variables, including reading and writing
 * the variable as well as retrieving metadata associated with the
 * variable.
 *</p>
 *<p>
 * Processing a message request consists of traversing the elements
 * of the name in the message according to the nodes of the tree
 * until reaching the terminus of the name. The terminus can refer
 * to any intermediate element in the tree or else the leaf node. In
 * the case of intermediate nodes, the request operates like a
 * reference to a sub-directory in a file path, whereas a match
 * to a leaf node provides access to the contents of the system
 * variable of the specified type. Once the terminus node is matched,
 * the operation defined by the message is performed on the object
 * and an optional result is returned in a response message.
 *</p>
 *<p>
 *</p>
 * The Tagnet stack is defined in a collection of interfaces and
 * components that operate on Tagnet messages to perform network
 * initiated operations on local system variables. Below is listed
 * the files associated with the stack.
 *<p>
 * interfaces:
 *</p>
 *<dl>
 *   <dt>Tagnet</dt> <dd>primary user methods for accessing the Tagnet stack</dd>
 *   <dt>TagnetMessage</dt> <dd>methods used to travers the name tree</dd>
 *   <dt>TagnetHeader</dt> <dd>methods for accessing a Tagnet message header</dd>
 *   <dt>TagnetName</dt> <dd>methods for acessing and evaluating a Tagnet message name</dd>
 *   <dt>TagnetPayload</dt> <dd>methods for accessing a Tagnet message payload</dd>
 *   <dt>TagnetTLV</dt> <dd>methods for parsing and building Tagnet TLVs</dd>
 *</dl>
 *<p>
 * Components:
 *</p>
 *<dl>
 *   <dt>TagnetUtilsC</dt> <dd>configuration with functions to access Tagnet messages</dd>
 *   <dt>TagnetNameElementP</dt> <dd>generic module handles intermediate elements of a name</dd>
 *   <dt>TagnetNameRootP</dt> <dd>module handles the name root starting point</dd>
 *   <dt>TagnetNamePollP</dt> <dd>generic module processes Tagnet poll request (special)</dd>
 *   <dt>TagnetIntegerAdapterP</dt> <dd>generic module for adapting local integer variable to the network TLV</dd>
 *<dl>
 *
 * @author Daniel J. Maltbie <dmaltbie@daloma.org>
 *
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
 */
#include <Tagnet.h>
#include <TagnetTLV.h>

configuration TagnetC {
  provides {
    interface Tagnet;
    interface TagnetAdapter<int32_t> as PollCount;
    interface TagnetName;
    interface TagnetPayload;
    interface TagnetTLV;
    interface TagnetHeader;
  }
  uses {
    interface TagnetAdapter<tagnet_gps_xyz_t>  as InfoSensGpsXyz;
  }
}
implementation {
  components TagnetUtilsC;
  TagnetName = TagnetUtilsC;
  TagnetPayload = TagnetUtilsC;
  TagnetTLV = TagnetUtilsC;
  TagnetHeader = TagnetUtilsC;

  // instantiate root of Name tree, provides the TagNet API
  components             TagnetNameRootP  as  RootVx;
  Tagnet              =  RootVx.Tagnet;
  components new         TagnetNameElementP   (TN_TAG_ID, UQ_TN_TAG)           as TagVx;
  TagVx.Super         -> RootVx.Sub[unique(UQ_TN_ROOT)];

  // instantiate object pathname for the TagNet poll event
  // -/tag-----/poll----/<nid>----/ev----PollEvLf
  // note this object is used by TagNet Master protocol to determine status of this node
  // number of times polled is exposed as an integer adapter for use as a counter
  components new         TagnetNameElementP   (TN_POLL_ID, UQ_TN_POLL)         as PollVx;
  components new         TagnetNameElementP   (TN_POLL_NID_ID, UQ_TN_POLL_NID) as PollNidVx;
  components new         TagnetNamePollP      (TN_POLL_EV_ID)                  as PollEvLf;
  PollVx.Super        -> TagVx.Sub[unique(UQ_TN_TAG)];
  PollNidVx.Super     -> PollVx.Sub[unique(UQ_TN_POLL)];
  PollEvLf.Super      -> PollNidVx.Sub[unique(UQ_TN_POLL_NID)];
  PollCount           =  PollEvLf.Adapter;

  // instantiate object pathname for the TagNet poll statistics counter
  // -/tag-----/poll----/<nid>----/cnt---PollEvLf.adapter
  // currently wire directly to poll event
  components new         TagnetIntegerAdapterP(TN_POLL_CNT_ID, UQ_TN_POLL_CNT) as PollCntLf;
  PollCntLf.Super     -> PollNidVx.Sub[unique(UQ_TN_POLL_NID)];
  PollCntLf.Adapter   -> PollEvLf;

  // instantiate object pathname for the TagNet GPS XYZ position
  // -/tag-----/info----/<nid>----/sens----/gps----gps_xyz.adapter
  components new         TagnetNameElementP   (TN_INFO_ID, UQ_TN_INFO)         as InfoVx;
  components new         TagnetNameElementP   (TN_INFO_NID_ID, UQ_TN_INFO_NID) as InfoNidVx;
  components new         TagnetNameElementP   (TN_INFO_SENS_ID, UQ_TN_INFO_SENS) as InfoSensVx;
  components new         TagnetNameElementP   (TN_INFO_SENS_GPS_ID, UQ_TN_INFO_SENS_GPS) as InfoSensGpsVx;
  components new         TagnetGpsXyzAdapterP (TN_INFO_SENS_GPS_XYZ_ID, UQ_TN_INFO_SENS_GPS_XYZ) as InfoSensGpsXyzLf;
  InfoVx.Super        -> TagVx.Sub[unique(UQ_TN_TAG)];
  InfoNidVx.Super     -> InfoVx.Sub[unique(UQ_TN_INFO)];
  InfoSensVx.Super    -> InfoNidVx.Sub[unique(UQ_TN_INFO_NID)];
  InfoSensGpsVx.Super -> InfoSensVx.Sub[unique(UQ_TN_INFO_SENS)];
  InfoSensGpsXyzLf.Super -> InfoSensGpsVx.Sub[unique(UQ_TN_INFO_SENS_GPS)];
  InfoSensGpsXyz      =  InfoSensGpsXyzLf.Adapter;

  // instantiate object pathname for the TagNet Software Image Repository
  // -/tag-----/sd------/<nid>----/<int=0>--/img---sd_image.adapter
  //                                     \--/conf--sd_image.adapter
  //                                     \--/rules-sd_image.adapter
  components new         TagnetNameElementP   (TN_SD_ID, UQ_TN_SD)         as SdVx;
  components new         TagnetNameElementP   (TN_SD_NID_ID, UQ_TN_SD_NID) as SdNidVx;
  components new         TagnetNameElementP   (TN_SD_DEV_0_ID, UQ_TN_SD_DEV_0) as SdDev0Vx;
  components new         TagnetImageAdapterP  (TN_SD_DEV_0_IMG_ID) as SdDev0ImgLf;
  SdVx.Super          -> TagVx.Sub[unique(UQ_TN_TAG)];
  SdNidVx.Super       -> SdVx.Sub[unique(UQ_TN_SD)];
  SdDev0Vx.Super      -> SdNidVx.Sub[unique(UQ_TN_SD_NID)];
  SdDev0ImgLf.Super   -> SdDev0Vx.Sub[unique(UQ_TN_SD_DEV_0)];

  // instantiate object pathname for TagNet System Boot Control
  // -/tag-----/sys-----/<nid>----/boot----/active
  //                                   \---/backup
  //                                   \---/nib
  //                                   \---/golden
  components new         TagnetNameElementP   (TN_SYS_ID, UQ_TN_SYS)         as SysVx;
  components new         TagnetNameElementP   (TN_SYS_NID_ID, UQ_TN_SYS_NID) as SysNidVx;
  components new         TagnetNameElementP   (TN_SYS_BOOT_ID, UQ_TN_SYS_BOOT) as SysBootVx;
  components new         TagnetActiveAdapterP (TN_SYS_BOOT_ACTIVE_ID) as SysBootActiveLf;
  components new         TagnetActiveAdapterP (TN_SYS_BOOT_BACKUP_ID) as SysBootBackupLf;
  components new         TagnetActiveAdapterP (TN_SYS_BOOT_GOLDEN_ID) as SysBootGoldenLf;
  components new         TagnetActiveAdapterP (TN_SYS_BOOT_NIB_ID)    as SysBootNibLf;
//  components new         TagnetBackupAdapterP (TN_SYS_BOOT_BACKUP_ID) as SysBootBackupLf;
//  components new         TagnetGoldenAdapterP (TN_SYS_BOOT_GOLDEN_ID) as SysBootGoldenLf;
//  components new         TagnetNibAdapterP    (TN_SYS_BOOT_NIB_ID)    as SysBootNibLf;
  SysVx.Super         -> TagVx.Sub[unique(UQ_TN_TAG)];
  SysNidVx.Super      -> SysVx.Sub[unique(UQ_TN_SYS)];
  SysBootVx.Super     -> SysNidVx.Sub[unique(UQ_TN_SYS_NID)];
  SysBootActiveLf.Super-> SysBootVx.Sub[unique(UQ_TN_SYS_BOOT)];
  SysBootBackupLf.Super-> SysBootVx.Sub[unique(UQ_TN_SYS_BOOT)];
  SysBootGoldenLf.Super-> SysBootVx.Sub[unique(UQ_TN_SYS_BOOT)];
  SysBootNibLf.Super  -> SysBootVx.Sub[unique(UQ_TN_SYS_BOOT)];
}
