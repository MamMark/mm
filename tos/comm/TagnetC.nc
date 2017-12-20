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
    interface      TagnetSysExecAdapter                     as SysRunning;
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface      TagnetSysExecAdapter                     as SysActive;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
    interface             TagnetAdapter<tagnet_dblk_bytes_t>  as Dblk0Bytes;
    interface             TagnetAdapter<uint8_t>            as DblkNote;
    interface             TagnetAdapter<tagnet_dblk_bytes_t>  as Dblk1Bytes;
    interface      TagnetSysExecAdapter                     as SysGolden;
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

    components             TagnetNameRootP                     as    tn_0_Vx;
    components new      TagnetNameElementP (TN_1_ID,TN_1_UQ)   as    tn_1_Vx;
    components new      TagnetNameElementP (TN_2_ID,TN_2_UQ)   as    tn_2_Vx;
    components new      TagnetNameElementP (TN_3_ID,TN_3_UQ)   as    tn_3_Vx;
    components new       TagnetMsgAdapterP ( TN_4_ID  )        as    tn_4_Vx;
    components new   TagnetIntegerAdapterP ( TN_5_ID  )        as    tn_5_Vx;
    components new      TagnetNameElementP (TN_6_ID,TN_6_UQ)   as    tn_6_Vx;
    components new      TagnetNameElementP (TN_7_ID,TN_7_UQ)   as    tn_7_Vx;
    components new      TagnetNameElementP (TN_8_ID,TN_8_UQ)   as    tn_8_Vx;
    components new      TagnetNameElementP (TN_9_ID,TN_9_UQ)   as    tn_9_Vx;
    components new    TagnetGpsXyzAdapterP ( TN_10_ID )        as   tn_10_Vx;
    components new      TagnetNameElementP (TN_11_ID,TN_11_UQ) as   tn_11_Vx;
    components new      TagnetNameElementP (TN_12_ID,TN_12_UQ) as   tn_12_Vx;
    components new      TagnetNameElementP (TN_13_ID,TN_13_UQ) as   tn_13_Vx;
    components new      TagnetNameElementP (TN_14_ID,TN_14_UQ) as   tn_14_Vx;
    components new  TagnetDblkByteAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new  TagnetDblkByteAdapterP ( TN_16_ID )        as   tn_16_Vx;
    components new  TagnetDblkNoteAdapterP ( TN_17_ID )        as   tn_17_Vx;
    components new     TagnetImageAdapterP ( TN_18_ID )        as   tn_18_Vx;
    components new      TagnetNameElementP (TN_19_ID,TN_19_UQ) as   tn_19_Vx;
    components new      TagnetNameElementP (TN_20_ID,TN_20_UQ) as   tn_20_Vx;
    components new   TagnetSysExecAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new   TagnetSysExecAdapterP ( TN_22_ID )        as   tn_22_Vx;
    components new   TagnetSysExecAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new   TagnetSysExecAdapterP ( TN_24_ID )        as   tn_24_Vx;
    components new   TagnetSysExecAdapterP ( TN_25_ID )        as   tn_25_Vx;

    Tagnet           =     tn_0_Vx;
       tn_1_Vx.Super ->     tn_0_Vx.Sub[unique(TN_0_UQ)];
       tn_2_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_3_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
       tn_4_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollEvent        =      tn_4_Vx.Adapter;
       tn_5_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollCount        =      tn_5_Vx.Adapter;
       tn_6_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_7_Vx.Super ->     tn_6_Vx.Sub[unique(TN_6_UQ)];
       tn_8_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
       tn_9_Vx.Super ->     tn_8_Vx.Sub[unique(TN_8_UQ)];
      tn_10_Vx.Super ->     tn_9_Vx.Sub[unique(TN_9_UQ)];
    InfoSensGpsXyz   =     tn_10_Vx.Adapter;
      tn_11_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_12_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_13_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
      tn_14_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_15_Vx.Super ->    tn_14_Vx.Sub[unique(TN_14_UQ)];
    Dblk0Bytes       =     tn_15_Vx.Adapter;
      tn_16_Vx.Super ->    tn_14_Vx.Sub[unique(TN_14_UQ)];
    Dblk1Bytes       =     tn_16_Vx.Adapter;
      tn_17_Vx.Super ->    tn_14_Vx.Sub[unique(TN_14_UQ)];
    DblkNote         =     tn_17_Vx.Adapter;
      tn_18_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_19_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_20_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
      tn_21_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    SysActive        =     tn_21_Vx.Adapter;
      tn_22_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    SysBackup        =     tn_22_Vx.Adapter;
      tn_23_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    SysGolden        =     tn_23_Vx.Adapter;
      tn_24_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    SysNIB           =     tn_24_Vx.Adapter;
      tn_25_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    SysRunning       =     tn_25_Vx.Adapter;
}
