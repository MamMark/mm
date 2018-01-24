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
    interface      TagnetSysExecAdapter                     as SysRunning;
    interface      TagnetSysExecAdapter                     as SysGolden;
    interface      TagnetSysExecAdapter                     as SysActive;
    interface      TagnetSysExecAdapter                     as SysBackup;
    interface             TagnetAdapter<uint8_t>            as InfoSensGpsCmd;
    interface             TagnetAdapter<tagnet_dblk_note_t>  as DblkNote;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as DblkBytes;
    interface             TagnetAdapter<tagnet_file_bytes_t>  as PanicBytes;
    interface      TagnetSysExecAdapter                     as SysNIB;
    interface             TagnetAdapter<int32_t>            as PollCount;
    interface             TagnetAdapter<message_t>          as PollEvent;
    interface             TagnetAdapter<tagnet_gps_xyz_t>   as InfoSensGpsXyz;
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
    components new    TagnetGpsXyzAdapterP ( TN_9_ID  )        as    tn_9_Vx;
    components new    TagnetGpsCmdAdapterP ( TN_10_ID )        as   tn_10_Vx;
    components new      TagnetNameElementP (TN_11_ID,TN_11_UQ) as   tn_11_Vx;
    components new      TagnetNameElementP (TN_12_ID,TN_12_UQ) as   tn_12_Vx;
    components new      TagnetNameElementP (TN_13_ID,TN_13_UQ) as   tn_13_Vx;
    components new  TagnetFileByteAdapterP ( TN_14_ID )        as   tn_14_Vx;
    components new  TagnetDblkNoteAdapterP ( TN_15_ID )        as   tn_15_Vx;
    components new     TagnetImageAdapterP ( TN_16_ID )        as   tn_16_Vx;
    components new      TagnetNameElementP (TN_17_ID,TN_17_UQ) as   tn_17_Vx;
    components new  TagnetFileByteAdapterP ( TN_18_ID )        as   tn_18_Vx;
    components new      TagnetNameElementP (TN_19_ID,TN_19_UQ) as   tn_19_Vx;
    components new   TagnetSysExecAdapterP ( TN_20_ID )        as   tn_20_Vx;
    components new   TagnetSysExecAdapterP ( TN_21_ID )        as   tn_21_Vx;
    components new   TagnetSysExecAdapterP ( TN_22_ID )        as   tn_22_Vx;
    components new   TagnetSysExecAdapterP ( TN_23_ID )        as   tn_23_Vx;
    components new   TagnetSysExecAdapterP ( TN_24_ID )        as   tn_24_Vx;

    Tagnet           =     tn_0_Vx;
       tn_1_Vx.Super ->     tn_0_Vx.Sub[unique(TN_0_UQ)];
       tn_2_Vx.Super ->     tn_1_Vx.Sub[unique(TN_1_UQ)];
       tn_3_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
       tn_4_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollEvent        =      tn_4_Vx.Adapter;
       tn_5_Vx.Super ->     tn_3_Vx.Sub[unique(TN_3_UQ)];
    PollCount        =      tn_5_Vx.Adapter;
       tn_6_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
       tn_7_Vx.Super ->     tn_6_Vx.Sub[unique(TN_6_UQ)];
       tn_8_Vx.Super ->     tn_7_Vx.Sub[unique(TN_7_UQ)];
       tn_9_Vx.Super ->     tn_8_Vx.Sub[unique(TN_8_UQ)];
    InfoSensGpsXyz   =      tn_9_Vx.Adapter;
      tn_10_Vx.Super ->     tn_8_Vx.Sub[unique(TN_8_UQ)];
    InfoSensGpsCmd   =     tn_10_Vx.Adapter;
      tn_11_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
      tn_12_Vx.Super ->    tn_11_Vx.Sub[unique(TN_11_UQ)];
      tn_13_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
      tn_14_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    DblkBytes        =     tn_14_Vx.Adapter;
      tn_15_Vx.Super ->    tn_13_Vx.Sub[unique(TN_13_UQ)];
    DblkNote         =     tn_15_Vx.Adapter;
      tn_16_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
      tn_17_Vx.Super ->    tn_12_Vx.Sub[unique(TN_12_UQ)];
      tn_18_Vx.Super ->    tn_17_Vx.Sub[unique(TN_17_UQ)];
    PanicBytes       =     tn_18_Vx.Adapter;
      tn_19_Vx.Super ->     tn_2_Vx.Sub[unique(TN_2_UQ)];
      tn_20_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
    SysActive        =     tn_20_Vx.Adapter;
      tn_21_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
    SysBackup        =     tn_21_Vx.Adapter;
      tn_22_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
    SysGolden        =     tn_22_Vx.Adapter;
      tn_23_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
    SysNIB           =     tn_23_Vx.Adapter;
      tn_24_Vx.Super ->    tn_19_Vx.Sub[unique(TN_19_UQ)];
    SysRunning       =     tn_24_Vx.Adapter;
}
