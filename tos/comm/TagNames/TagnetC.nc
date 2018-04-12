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
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface             TagnetAdapter<message_t>          as RadioTxPower;
    interface      TagnetSysExecAdapter                     as SysGolden;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestDropBytes;
    interface      TagnetSysExecAdapter                     as SysNIB;
    interface      TagnetSysExecAdapter                     as SysRunning;
    interface             TagnetAdapter<message_t>          as RadioRSSI;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecNum;
    interface             TagnetAdapter<tagnet_dblk_note_t>  as DblkNote;
    interface             TagnetAdapter<uint32_t>           as DblkLastSyncOffset;
    interface             TagnetAdapter<uint32_t>           as DblkLastRecOffset;
    interface             TagnetAdapter<uint32_t>           as DblkCommittedOffset;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestZeroBytes;
    interface      TagnetSysExecAdapter                     as SysActive;
    interface             TagnetAdapter<rtctime_t>          as SysRtcTime;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestEchoBytes;
    interface             TagnetAdapter<message_t>          as PollEvent;
    interface             TagnetAdapter<int32_t>            as PollCount;
    interface             TagnetAdapter<tagnet_gps_cmd_t>   as InfoSensGpsCmd;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as TestOnesBytes;
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
    components new       TagnetMsgAdapterP ( TN_3_ID  )        as    tn_3_Vx;
    components new   TagnetIntegerAdapterP ( TN_4_ID  )        as    tn_4_Vx;
    components new      TagnetNameElementP (TN_5_ID,TN_5_UQ)   as    tn_5_Vx;
    components new      TagnetNameElementP (TN_6_ID,TN_6_UQ)   as    tn_6_Vx;
    components new      TagnetNameElementP (TN_7_ID,TN_7_UQ)   as    tn_7_Vx;
    components new    TagnetGpsXyzAdapterP ( TN_8_ID  )        as    tn_8_Vx;
    components new  TagnetFileByteAdapterP ( TN_9_ID  )        as    tn_9_Vx;
    components new      TagnetNameElementP (TN_10_ID,TN_10_UQ) as   tn_10_Vx;
    components new      TagnetNameElementP (TN_11_ID,TN_11_UQ) as   tn_11_Vx;
    components new      TagnetNameElementP (TN_12_ID,TN_12_UQ) as   tn_12_Vx;
    components new  TagnetFileByteAdapterP ( TN_13_ID )        as   tn_13_Vx;
    components new  TagnetFileByteAdapterP ( TN_14_ID )        as   tn_14_Vx;
    components new  TagnetUnsignedAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new  TagnetUnsignedAdapterP ( TN_16_ID )        as   tn_16_Vx;
    components new  TagnetUnsignedAdapterP ( TN_17_ID )        as   tn_17_Vx;
    components new  TagnetUnsignedAdapterP ( TN_18_ID )        as   tn_18_Vx;
    components new     TagnetImageAdapterP ( TN_19_ID )        as   tn_19_Vx;
    components new      TagnetNameElementP (TN_20_ID,TN_20_UQ) as   tn_20_Vx;
    components new  TagnetFileByteAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new      TagnetNameElementP (TN_22_ID,TN_22_UQ) as   tn_22_Vx;
    components new   TagnetSysExecAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new   TagnetSysExecAdapterP ( TN_24_ID )        as   tn_24_Vx;
    components new   TagnetSysExecAdapterP ( TN_25_ID )        as   tn_25_Vx;
    components new   TagnetSysExecAdapterP ( TN_26_ID )        as   tn_26_Vx;
    components new   TagnetSysExecAdapterP ( TN_27_ID )        as   tn_27_Vx;
    components new   TagnetRtcTimeAdapterP ( TN_28_ID )        as   tn_28_Vx;
    components new      TagnetNameElementP (TN_29_ID,TN_29_UQ) as   tn_29_Vx;
    components new      TagnetNameElementP (TN_30_ID,TN_30_UQ) as   tn_30_Vx;
    components new  TagnetFileByteAdapterP ( TN_31_ID )        as   tn_31_Vx;
    components new      TagnetNameElementP (TN_32_ID,TN_32_UQ) as   tn_32_Vx;
    components new  TagnetFileByteAdapterP ( TN_33_ID )        as   tn_33_Vx;
    components new      TagnetNameElementP (TN_34_ID,TN_34_UQ) as   tn_34_Vx;
    components new  TagnetFileByteAdapterP ( TN_35_ID )        as   tn_35_Vx;
    components new      TagnetNameElementP (TN_36_ID,TN_36_UQ) as   tn_36_Vx;
    components new  TagnetFileByteAdapterP ( TN_37_ID )        as   tn_37_Vx;
    components new       TagnetMsgAdapterP ( TN_38_ID )        as   tn_38_Vx;
    components new       TagnetMsgAdapterP ( TN_39_ID )        as   tn_39_Vx;

    Tagnet           =     tn_0_Vx;
       tn_1_Vx.Super ->     tn_0_Vx.Sub[unique(TN_0_UQ)];
       tn_2_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_3_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
    PollEvent        =      tn_3_Vx.Adapter;
       tn_4_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
    PollCount        =      tn_4_Vx.Adapter;
       tn_5_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_6_Vx.Super ->     tn_5_Vx.Sub[unique(TN_5_UQ)];
       tn_7_Vx.Super ->     tn_6_Vx.Sub[unique(TN_6_UQ)];
       tn_8_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
    InfoSensGpsXyz   =      tn_8_Vx.Adapter;
       tn_9_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
    InfoSensGpsCmd   =      tn_9_Vx.Adapter;
      tn_10_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_11_Vx.Super ->    tn_10_Vx.Sub[unique(TN_10_UQ)];
      tn_12_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_13_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkBytes        =     tn_13_Vx.Adapter;
      tn_14_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkNote         =     tn_14_Vx.Adapter;
      tn_15_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkLastRecNum   =     tn_15_Vx.Adapter;
      tn_16_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkLastRecOffset  =     tn_16_Vx.Adapter;
      tn_17_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkLastSyncOffset  =     tn_17_Vx.Adapter;
      tn_18_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
    DblkCommittedOffset  =     tn_18_Vx.Adapter;
      tn_19_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_20_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_21_Vx.Super ->    tn_20_Vx.Sub[unique(TN_20_UQ)];
    PanicBytes       =     tn_21_Vx.Adapter;
      tn_22_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_23_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysActive        =     tn_23_Vx.Adapter;
      tn_24_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysBackup        =     tn_24_Vx.Adapter;
      tn_25_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysGolden        =     tn_25_Vx.Adapter;
      tn_26_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysNIB           =     tn_26_Vx.Adapter;
      tn_27_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysRunning       =     tn_27_Vx.Adapter;
      tn_28_Vx.Super ->    tn_22_Vx.Sub[unique(TN_22_UQ)];
    SysRtcTime       =     tn_28_Vx.Adapter;
      tn_29_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
      tn_30_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
      tn_31_Vx.Super ->    tn_30_Vx.Sub[unique(TN_30_UQ)];
    TestZeroBytes    =     tn_31_Vx.Adapter;
      tn_32_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
      tn_33_Vx.Super ->    tn_32_Vx.Sub[unique(TN_32_UQ)];
    TestOnesBytes    =     tn_33_Vx.Adapter;
      tn_34_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
      tn_35_Vx.Super ->    tn_34_Vx.Sub[unique(TN_34_UQ)];
    TestEchoBytes    =     tn_35_Vx.Adapter;
      tn_36_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
      tn_37_Vx.Super ->    tn_36_Vx.Sub[unique(TN_36_UQ)];
    TestDropBytes    =     tn_37_Vx.Adapter;
      tn_38_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
    RadioRSSI        =     tn_38_Vx.Adapter;
      tn_39_Vx.Super ->    tn_29_Vx.Sub[unique(TN_29_UQ)];
    RadioTxPower     =     tn_39_Vx.Adapter;
}
