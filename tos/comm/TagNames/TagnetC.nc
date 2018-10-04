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
    interface             TagnetAdapter<uint32_t>           as DblkResyncOffset;
    interface             TagnetAdapter<int32_t>            as PollCount;
    interface             TagnetAdapter<message_t>          as PollEvent;
    interface             TagnetAdapter<message_t>          as RadioRSSI;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestZeroBytes;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
    interface             TagnetAdapter<message_t>          as RadioTxPower;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecOffset;
    interface             TagnetAdapter<uint32_t>           as DblkLastSyncOffset;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface             TagnetAdapter<tagnet_dblk_note_t>  as DblkNote;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
    interface             TagnetAdapter<tagnet_gps_cmd_t>   as InfoSensGpsCmd;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecNum;
    interface             TagnetAdapter<uint32_t>           as DblkCommittedOffset;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestDropBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestEchoBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestOnesBytes;
    interface             TagnetAdapter<rtctime_t>          as SysRtcTime;
    interface             TagnetAdapter<tagnet_block_t>     as RadioStats;
    interface      TagnetSysExecAdapter                     as SysRunning;
    interface      TagnetSysExecAdapter                     as SysNIB;
    interface      TagnetSysExecAdapter                     as SysGolden;
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface      TagnetSysExecAdapter                     as SysActive;
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
    components new      TagnetNameElementP (TN_4_ID,TN_4_UQ)   as    tn_4_Vx;
    components new  TagnetFileByteAdapterP ( TN_5_ID  )        as    tn_5_Vx;
    components new  TagnetFileByteAdapterP ( TN_6_ID  )        as    tn_6_Vx;
    components new      TagnetNameElementP (TN_7_ID,TN_7_UQ)   as    tn_7_Vx;
    components new      TagnetNameElementP (TN_8_ID,TN_8_UQ)   as    tn_8_Vx;
    components new      TagnetNameElementP (TN_9_ID,TN_9_UQ)   as    tn_9_Vx;
    components new  TagnetFileByteAdapterP ( TN_10_ID )        as   tn_10_Vx;
    components new      TagnetNameElementP (TN_11_ID,TN_11_UQ) as   tn_11_Vx;
    components new  TagnetFileByteAdapterP ( TN_12_ID )        as   tn_12_Vx;
    components new      TagnetNameElementP (TN_13_ID,TN_13_UQ) as   tn_13_Vx;
    components new      TagnetNameElementP (TN_14_ID,TN_14_UQ) as   tn_14_Vx;
    components new  TagnetFileByteAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new      TagnetNameElementP (TN_16_ID,TN_16_UQ) as   tn_16_Vx;
    components new  TagnetFileByteAdapterP ( TN_17_ID )        as   tn_17_Vx;
    components new      TagnetNameElementP (TN_18_ID,TN_18_UQ) as   tn_18_Vx;
    components new  TagnetFileByteAdapterP ( TN_19_ID )        as   tn_19_Vx;
    components new      TagnetNameElementP (TN_20_ID,TN_20_UQ) as   tn_20_Vx;
    components new  TagnetFileByteAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new    TagnetGpsXyzAdapterP ( TN_22_ID )        as   tn_22_Vx;
    components new     TagnetImageAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new      TagnetNameElementP (TN_24_ID,TN_24_UQ) as   tn_24_Vx;
    components new   TagnetIntegerAdapterP ( TN_25_ID )        as   tn_25_Vx;
    components new       TagnetMsgAdapterP ( TN_26_ID )        as   tn_26_Vx;
    components new       TagnetMsgAdapterP ( TN_27_ID )        as   tn_27_Vx;
    components new       TagnetMsgAdapterP ( TN_28_ID )        as   tn_28_Vx;
    components new      TagnetNameElementP (TN_29_ID,TN_29_UQ) as   tn_29_Vx;
    components new     TagnetBlockAdapterP ( TN_30_ID )        as   tn_30_Vx;
    components new      TagnetNameElementP (TN_31_ID,TN_31_UQ) as   tn_31_Vx;
    components new   TagnetRtcTimeAdapterP ( TN_32_ID )        as   tn_32_Vx;
    components new   TagnetSysExecAdapterP ( TN_33_ID )        as   tn_33_Vx;
    components new   TagnetSysExecAdapterP ( TN_34_ID )        as   tn_34_Vx;
    components new   TagnetSysExecAdapterP ( TN_35_ID )        as   tn_35_Vx;
    components new   TagnetSysExecAdapterP ( TN_36_ID )        as   tn_36_Vx;
    components new   TagnetSysExecAdapterP ( TN_37_ID )        as   tn_37_Vx;
    components new  TagnetUnsignedAdapterP ( TN_38_ID )        as   tn_38_Vx;
    components new  TagnetUnsignedAdapterP ( TN_39_ID )        as   tn_39_Vx;
    components new  TagnetUnsignedAdapterP ( TN_40_ID )        as   tn_40_Vx;
    components new  TagnetUnsignedAdapterP ( TN_41_ID )        as   tn_41_Vx;
    components new  TagnetUnsignedAdapterP ( TN_42_ID )        as   tn_42_Vx;

    Tagnet           =     tn_0_Vx;
       tn_1_Vx.Super ->     tn_0_Vx.Sub[unique(TN_0_UQ)];
       tn_2_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_3_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
       tn_4_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
       tn_5_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkBytes        =      tn_5_Vx.Adapter;
       tn_6_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkNote         =      tn_6_Vx.Adapter;
       tn_7_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_8_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
       tn_9_Vx.Super ->     tn_8_Vx.Sub[unique(TN_8_UQ)];
      tn_10_Vx.Super ->     tn_9_Vx.Sub[unique(TN_9_UQ)];
    InfoSensGpsCmd   =     tn_10_Vx.Adapter;
      tn_11_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
      tn_12_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
    PanicBytes       =     tn_12_Vx.Adapter;
      tn_13_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_14_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_15_Vx.Super ->    tn_14_Vx.Sub[unique(TN_14_UQ)];
    TestDropBytes    =     tn_15_Vx.Adapter;
      tn_16_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_17_Vx.Super ->    tn_16_Vx.Sub[unique(TN_16_UQ)];
    TestEchoBytes    =     tn_17_Vx.Adapter;
      tn_18_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_19_Vx.Super ->    tn_18_Vx.Sub[unique(TN_18_UQ)];
    TestOnesBytes    =     tn_19_Vx.Adapter;
      tn_20_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
      tn_21_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    TestZeroBytes    =     tn_21_Vx.Adapter;
      tn_22_Vx.Super ->     tn_9_Vx.Sub[unique(TN_9_UQ)];
    InfoSensGpsXyz   =     tn_22_Vx.Adapter;
      tn_23_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
      tn_24_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_25_Vx.Super ->    tn_24_Vx.Sub[unique(TN_24_UQ)];
    PollCount        =     tn_25_Vx.Adapter;
      tn_26_Vx.Super ->    tn_24_Vx.Sub[unique(TN_24_UQ)];
    PollEvent        =     tn_26_Vx.Adapter;
      tn_27_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    RadioRSSI        =     tn_27_Vx.Adapter;
      tn_28_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    RadioTxPower     =     tn_28_Vx.Adapter;
      tn_29_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_30_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
    RadioStats       =     tn_30_Vx.Adapter;
      tn_31_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_32_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysRtcTime       =     tn_32_Vx.Adapter;
      tn_33_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysActive        =     tn_33_Vx.Adapter;
      tn_34_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysBackup        =     tn_34_Vx.Adapter;
      tn_35_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysGolden        =     tn_35_Vx.Adapter;
      tn_36_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysNIB           =     tn_36_Vx.Adapter;
      tn_37_Vx.Super ->    tn_31_Vx.Sub[unique(TN_31_UQ)];
    SysRunning       =     tn_37_Vx.Adapter;
      tn_38_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkCommittedOffset  =     tn_38_Vx.Adapter;
      tn_39_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastRecNum   =     tn_39_Vx.Adapter;
      tn_40_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastRecOffset  =     tn_40_Vx.Adapter;
      tn_41_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastSyncOffset  =     tn_41_Vx.Adapter;
      tn_42_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkResyncOffset  =     tn_42_Vx.Adapter;
}
