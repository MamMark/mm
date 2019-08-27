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
    interface             TagnetAdapter<message_t>          as RadioTxPower;
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface             TagnetAdapter<uint32_t>           as DblkLastSyncOffset;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecNum;
    interface             TagnetAdapter<message_t>          as PollEvent;
    interface             TagnetAdapter<tagnet_block_t>     as RadioStats;
    interface             TagnetAdapter<uint32_t>           as DblkCommittedOffset;
    interface             TagnetAdapter<uint32_t>           as DblkResyncOffset;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecOffset;
    interface      TagnetSysExecAdapter                     as SysNIB;
    interface             TagnetAdapter<int32_t>            as PollCount;
    interface             TagnetAdapter<tagnet_gps_cmd_t>   as InfoSensGpsCmd;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestEchoBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestDropBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestZeroBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestOnesBytes;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
    interface      TagnetSysExecAdapter                     as SysGolden;
    interface             TagnetAdapter<message_t>          as RadioRSSI;
    interface             TagnetAdapter<rtctime_t>          as SysRtcTime;
    interface      TagnetSysExecAdapter                     as SysActive;
    interface             TagnetAdapter<uint32_t>           as DblkBootOffset;
    interface             TagnetAdapter<uint32_t>           as DblkBootRecNum;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface             TagnetAdapter<tagnet_dblk_note_t>  as DblkNote;
    interface      TagnetSysExecAdapter                     as SysRunning;
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
    components new  TagnetFileByteAdapterP ( TN_14_ID )        as   tn_14_Vx;
    components new  TagnetFileByteAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new  TagnetFileByteAdapterP ( TN_16_ID )        as   tn_16_Vx;
    components new  TagnetFileByteAdapterP ( TN_17_ID )        as   tn_17_Vx;
    components new    TagnetGpsXyzAdapterP ( TN_18_ID )        as   tn_18_Vx;
    components new     TagnetImageAdapterP ( TN_19_ID )        as   tn_19_Vx;
    components new      TagnetNameElementP (TN_20_ID,TN_20_UQ) as   tn_20_Vx;
    components new   TagnetIntegerAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new       TagnetMsgAdapterP ( TN_22_ID )        as   tn_22_Vx;
    components new       TagnetMsgAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new       TagnetMsgAdapterP ( TN_24_ID )        as   tn_24_Vx;
    components new      TagnetNameElementP (TN_25_ID,TN_25_UQ) as   tn_25_Vx;
    components new     TagnetBlockAdapterP ( TN_26_ID )        as   tn_26_Vx;
    components new      TagnetNameElementP (TN_27_ID,TN_27_UQ) as   tn_27_Vx;
    components new   TagnetRtcTimeAdapterP ( TN_28_ID )        as   tn_28_Vx;
    components new   TagnetSysExecAdapterP ( TN_29_ID )        as   tn_29_Vx;
    components new   TagnetSysExecAdapterP ( TN_30_ID )        as   tn_30_Vx;
    components new   TagnetSysExecAdapterP ( TN_31_ID )        as   tn_31_Vx;
    components new   TagnetSysExecAdapterP ( TN_32_ID )        as   tn_32_Vx;
    components new   TagnetSysExecAdapterP ( TN_33_ID )        as   tn_33_Vx;
    components new  TagnetUnsignedAdapterP ( TN_34_ID )        as   tn_34_Vx;
    components new  TagnetUnsignedAdapterP ( TN_35_ID )        as   tn_35_Vx;
    components new  TagnetUnsignedAdapterP ( TN_36_ID )        as   tn_36_Vx;
    components new  TagnetUnsignedAdapterP ( TN_37_ID )        as   tn_37_Vx;
    components new  TagnetUnsignedAdapterP ( TN_38_ID )        as   tn_38_Vx;
    components new  TagnetUnsignedAdapterP ( TN_39_ID )        as   tn_39_Vx;
    components new  TagnetUnsignedAdapterP ( TN_40_ID )        as   tn_40_Vx;

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
    TestDropBytes    =     tn_14_Vx.Adapter;
      tn_15_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    TestEchoBytes    =     tn_15_Vx.Adapter;
      tn_16_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    TestOnesBytes    =     tn_16_Vx.Adapter;
      tn_17_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    TestZeroBytes    =     tn_17_Vx.Adapter;
      tn_18_Vx.Super ->     tn_9_Vx.Sub[unique(TN_9_UQ)];
    InfoSensGpsXyz   =     tn_18_Vx.Adapter;
      tn_19_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
      tn_20_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_21_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    PollCount        =     tn_21_Vx.Adapter;
      tn_22_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    PollEvent        =     tn_22_Vx.Adapter;
      tn_23_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    RadioRSSI        =     tn_23_Vx.Adapter;
      tn_24_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    RadioTxPower     =     tn_24_Vx.Adapter;
      tn_25_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_26_Vx.Super ->    tn_25_Vx.Sub[unique(TN_25_UQ)];
    RadioStats       =     tn_26_Vx.Adapter;
      tn_27_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_28_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysRtcTime       =     tn_28_Vx.Adapter;
      tn_29_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysActive        =     tn_29_Vx.Adapter;
      tn_30_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysBackup        =     tn_30_Vx.Adapter;
      tn_31_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysGolden        =     tn_31_Vx.Adapter;
      tn_32_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysNIB           =     tn_32_Vx.Adapter;
      tn_33_Vx.Super ->    tn_27_Vx.Sub[unique(TN_27_UQ)];
    SysRunning       =     tn_33_Vx.Adapter;
      tn_34_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkBootRecNum   =     tn_34_Vx.Adapter;
      tn_35_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkBootOffset   =     tn_35_Vx.Adapter;
      tn_36_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkCommittedOffset  =     tn_36_Vx.Adapter;
      tn_37_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastRecNum   =     tn_37_Vx.Adapter;
      tn_38_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastRecOffset  =     tn_38_Vx.Adapter;
      tn_39_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkLastSyncOffset  =     tn_39_Vx.Adapter;
      tn_40_Vx.Super ->     tn_4_Vx.Sub[unique(TN_4_UQ)];
    DblkResyncOffset  =     tn_40_Vx.Adapter;
}
