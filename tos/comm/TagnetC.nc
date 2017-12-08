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

/*
 * THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT
 */

#include <Tagnet.h>
#include <TagnetTLV.h>

configuration TagnetC {
  provides {
    interface                    Tagnet;
    interface                TagnetName;
    interface             TagnetPayload;
    interface                 TagnetTLV;
    interface              TagnetHeader;
  }
  uses {
    interface      TagnetSysExecAdapter                     as SysNIB;
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface      TagnetSysExecAdapter                     as SysGolden;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
    interface             TagnetAdapter<tagnet_dblk_bytes_t>  as DblkBytes;
    interface      TagnetSysExecAdapter                     as SysActive;
    interface      TagnetSysExecAdapter                     as SysRunning;
    interface             TagnetAdapter<int32_t>            as PollCount;
    interface             TagnetAdapter<message_t>          as PollEvent;
  }
}
implementation {
    components                   TagnetUtilsC;
    TagnetName       = TagnetUtilsC;
    TagnetPayload    = TagnetUtilsC;
    TagnetTLV        = TagnetUtilsC;
    TagnetHeader     = TagnetUtilsC;

    components new   TagnetSysExecAdapterP ( TN_22_ID )        as   tn_22_Vx;
    components new   TagnetSysExecAdapterP ( TN_20_ID )        as   tn_20_Vx;
    components new   TagnetSysExecAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new      TagnetNameElementP (TN_11_ID,TN_11_UQ) as   tn_11_Vx;
    components new    TagnetGpsXyzAdapterP ( TN_10_ID )        as   tn_10_Vx;
    components new      TagnetNameElementP (TN_13_ID,TN_13_UQ) as   tn_13_Vx;
    components new      TagnetNameElementP (TN_12_ID,TN_12_UQ) as   tn_12_Vx;
    components new  TagnetDblkByteAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new      TagnetNameElementP (TN_14_ID,TN_14_UQ) as   tn_14_Vx;
    components new      TagnetNameElementP (TN_17_ID,TN_17_UQ) as   tn_17_Vx;
    components new     TagnetImageAdapterP ( TN_16_ID )        as   tn_16_Vx;
    components new   TagnetSysExecAdapterP ( TN_19_ID )        as   tn_19_Vx;
    components new      TagnetNameElementP (TN_18_ID,TN_18_UQ) as   tn_18_Vx;
    components new   TagnetSysExecAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new      TagnetNameElementP (TN_1_ID,TN_1_UQ)   as    tn_1_Vx;
    components             TagnetNameRootP                     as    tn_0_Vx;
    components new      TagnetNameElementP (TN_3_ID,TN_3_UQ)   as    tn_3_Vx;
    components new      TagnetNameElementP (TN_2_ID,TN_2_UQ)   as    tn_2_Vx;
    components new   TagnetIntegerAdapterP ( TN_5_ID  )        as    tn_5_Vx;
    components new       TagnetMsgAdapterP ( TN_4_ID  )        as    tn_4_Vx;
    components new      TagnetNameElementP (TN_7_ID,TN_7_UQ)   as    tn_7_Vx;
    components new      TagnetNameElementP (TN_6_ID,TN_6_UQ)   as    tn_6_Vx;
    components new      TagnetNameElementP (TN_9_ID,TN_9_UQ)   as    tn_9_Vx;
    components new      TagnetNameElementP (TN_8_ID,TN_8_UQ)   as    tn_8_Vx;

      tn_22_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    SysNIB           =     tn_22_Vx.Adapter;
      tn_20_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    SysBackup        =     tn_20_Vx.Adapter;
      tn_21_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    SysGolden        =     tn_21_Vx.Adapter;
      tn_11_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_10_Vx.Super ->     tn_9_Vx.Sub[unique(TN_9_UQ)];
    InfoSensGpsXyz   =     tn_10_Vx.Adapter;
      tn_13_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
      tn_12_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_15_Vx.Super ->    tn_14_Vx.Sub[unique(TN_14_UQ)];
    DblkBytes        =     tn_15_Vx.Adapter;
      tn_14_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_17_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_16_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_19_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    SysActive        =     tn_19_Vx.Adapter;
      tn_18_Vx.Super ->    tn_17_Vx.Sub[unique(TN_17_UQ)];
      tn_23_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    SysRunning       =     tn_23_Vx.Adapter;
       tn_1_Vx.Super ->     tn_0_Vx.Sub[unique(TN_0_UQ)];
    Tagnet           =     tn_0_Vx;
       tn_3_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
       tn_2_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_5_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollCount        =      tn_5_Vx.Adapter;
       tn_4_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollEvent        =      tn_4_Vx.Adapter;
       tn_7_Vx.Super ->     tn_6_Vx.Sub[unique(TN_6_UQ)];
       tn_6_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_9_Vx.Super ->     tn_8_Vx.Sub[unique(TN_8_UQ)];
       tn_8_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
}
