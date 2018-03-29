// THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT

typedef enum {                   //      (parent) name
  TN_0_ID               =     0, //  (    _     ) root
  TN_1_ID               =     1, //  (   root   ) \'<node_id:000000000000>\'
  TN_2_ID               =     2, //  (\'<node_id:000000000000>\') tag
  TN_3_ID               =     3, //  (   tag    ) poll
  TN_4_ID               =     4, //  (   poll   ) ev
  TN_5_ID               =     5, //  (   poll   ) cnt
  TN_6_ID               =     6, //  (   tag    ) info
  TN_7_ID               =     7, //  (   info   ) sens
  TN_8_ID               =     8, //  (   sens   ) gps
  TN_9_ID               =     9, //  (   gps    ) xyz
  TN_10_ID              =    10, //  (   gps    ) cmd
  TN_11_ID              =    11, //  (   tag    ) sd
  TN_12_ID              =    12, //  (    sd    ) 0
  TN_13_ID              =    13, //  (    0     ) dblk
  TN_14_ID              =    14, //  (   dblk   ) byte
  TN_15_ID              =    15, //  (   dblk   ) note
  TN_16_ID              =    16, //  (   dblk   ) .recnum
  TN_17_ID              =    17, //  (   dblk   ) .last_rec
  TN_18_ID              =    18, //  (   dblk   ) .last_sync
  TN_19_ID              =    19, //  (   dblk   ) .committed
  TN_20_ID              =    20, //  (    0     ) img
  TN_21_ID              =    21, //  (    0     ) panic
  TN_22_ID              =    22, //  (  panic   ) byte
  TN_23_ID              =    23, //  (   tag    ) sys
  TN_24_ID              =    24, //  (   sys    ) active
  TN_25_ID              =    25, //  (   sys    ) backup
  TN_26_ID              =    26, //  (   sys    ) golden
  TN_27_ID              =    27, //  (   sys    ) nib
  TN_28_ID              =    28, //  (   sys    ) running
  TN_29_ID              =    29, //  (   tag    ) .test
  TN_30_ID              =    30, //  (  .test   ) zero
  TN_31_ID              =    31, //  (   zero   ) byte
  TN_32_ID              =    32, //  (  .test   ) ones
  TN_33_ID              =    33, //  (   ones   ) byte
  TN_34_ID              =    34, //  (  .test   ) echo
  TN_35_ID              =    35, //  (   echo   ) byte
  TN_36_ID              =    36, //  (  .test   ) drop
  TN_37_ID              =    37, //  (   drop   ) byte
  TN_38_ID              =    38, //  (  .test   ) rssi
  TN_39_ID              =    39, //  (  .test   ) tx_pwr
  TN_LAST_ID            =    40,
  TN_ROOT_ID            =     0,
  TN_MAX_ID             =  65000,
} tn_ids_t;

#define  TN_0_UQ                 "TN_0_UQ"
#define  TN_1_UQ                 "TN_1_UQ"
#define  TN_2_UQ                 "TN_2_UQ"
#define  TN_3_UQ                 "TN_3_UQ"
#define  TN_4_UQ                 "TN_4_UQ"
#define  TN_5_UQ                 "TN_5_UQ"
#define  TN_6_UQ                 "TN_6_UQ"
#define  TN_7_UQ                 "TN_7_UQ"
#define  TN_8_UQ                 "TN_8_UQ"
#define  TN_9_UQ                 "TN_9_UQ"
#define  TN_10_UQ                "TN_10_UQ"
#define  TN_11_UQ                "TN_11_UQ"
#define  TN_12_UQ                "TN_12_UQ"
#define  TN_13_UQ                "TN_13_UQ"
#define  TN_14_UQ                "TN_14_UQ"
#define  TN_15_UQ                "TN_15_UQ"
#define  TN_16_UQ                "TN_16_UQ"
#define  TN_17_UQ                "TN_17_UQ"
#define  TN_18_UQ                "TN_18_UQ"
#define  TN_19_UQ                "TN_19_UQ"
#define  TN_20_UQ                "TN_20_UQ"
#define  TN_21_UQ                "TN_21_UQ"
#define  TN_22_UQ                "TN_22_UQ"
#define  TN_23_UQ                "TN_23_UQ"
#define  TN_24_UQ                "TN_24_UQ"
#define  TN_25_UQ                "TN_25_UQ"
#define  TN_26_UQ                "TN_26_UQ"
#define  TN_27_UQ                "TN_27_UQ"
#define  TN_28_UQ                "TN_28_UQ"
#define  TN_29_UQ                "TN_29_UQ"
#define  TN_30_UQ                "TN_30_UQ"
#define  TN_31_UQ                "TN_31_UQ"
#define  TN_32_UQ                "TN_32_UQ"
#define  TN_33_UQ                "TN_33_UQ"
#define  TN_34_UQ                "TN_34_UQ"
#define  TN_35_UQ                "TN_35_UQ"
#define  TN_36_UQ                "TN_36_UQ"
#define  TN_37_UQ                "TN_37_UQ"
#define  TN_38_UQ                "TN_38_UQ"
#define  TN_39_UQ                "TN_39_UQ"
#define UQ_TAGNET_ADAPTER_LIST  "UQ_TAGNET_ADAPTER_LIST"
#define UQ_TN_ROOT               TN_0_UQ
/* structure used to hold configuration values for each of the elements
* in the tagnet named data tree
*/
typedef struct TN_data_t {
  tn_ids_t    id;
  char*       name_tlv;
  char*       help_tlv;
  char*       uq;
} TN_data_t;

const TN_data_t tn_name_data_descriptors[TN_LAST_ID]={
  { TN_0_ID, "\01\04root", "\01\04help", TN_0_UQ },
  { TN_1_ID, "\01\032\'<node_id:000000000000>\'", "\01\04help", TN_1_UQ },
  { TN_2_ID, "\01\03tag", "\01\04help", TN_2_UQ },
  { TN_3_ID, "\01\04poll", "\01\04help", TN_3_UQ },
  { TN_4_ID, "\01\02ev", "\01\04help", TN_4_UQ },
  { TN_5_ID, "\01\03cnt", "\01\04help", TN_5_UQ },
  { TN_6_ID, "\01\04info", "\01\04help", TN_6_UQ },
  { TN_7_ID, "\01\04sens", "\01\04help", TN_7_UQ },
  { TN_8_ID, "\01\03gps", "\01\04help", TN_8_UQ },
  { TN_9_ID, "\01\03xyz", "\01\04help", TN_9_UQ },
  { TN_10_ID, "\01\03cmd", "\01\04help", TN_10_UQ },
  { TN_11_ID, "\01\02sd", "\01\04help", TN_11_UQ },
  { TN_12_ID, "\02\01\00", "\01\04help", TN_12_UQ },
  { TN_13_ID, "\01\04dblk", "\01\04help", TN_13_UQ },
  { TN_14_ID, "\01\04byte", "\01\04help", TN_14_UQ },
  { TN_15_ID, "\01\04note", "\01\04help", TN_15_UQ },
  { TN_16_ID, "\01\07.recnum", "\01\04help", TN_16_UQ },
  { TN_17_ID, "\01\011.last_rec", "\01\04help", TN_17_UQ },
  { TN_18_ID, "\01\012.last_sync", "\01\04help", TN_18_UQ },
  { TN_19_ID, "\01\012.committed", "\01\04help", TN_19_UQ },
  { TN_20_ID, "\01\03img", "\01\04help", TN_20_UQ },
  { TN_21_ID, "\01\05panic", "\01\04help", TN_21_UQ },
  { TN_22_ID, "\01\04byte", "\01\04help", TN_22_UQ },
  { TN_23_ID, "\01\03sys", "\01\04help", TN_23_UQ },
  { TN_24_ID, "\01\06active", "\01\04help", TN_24_UQ },
  { TN_25_ID, "\01\06backup", "\01\04help", TN_25_UQ },
  { TN_26_ID, "\01\06golden", "\01\04help", TN_26_UQ },
  { TN_27_ID, "\01\03nib", "\01\04help", TN_27_UQ },
  { TN_28_ID, "\01\07running", "\01\04help", TN_28_UQ },
  { TN_29_ID, "\01\05.test", "\01\04help", TN_29_UQ },
  { TN_30_ID, "\01\04zero", "\01\04help", TN_30_UQ },
  { TN_31_ID, "\01\04byte", "\01\04help", TN_31_UQ },
  { TN_32_ID, "\01\04ones", "\01\04help", TN_32_UQ },
  { TN_33_ID, "\01\04byte", "\01\04help", TN_33_UQ },
  { TN_34_ID, "\01\04echo", "\01\04help", TN_34_UQ },
  { TN_35_ID, "\01\04byte", "\01\04help", TN_35_UQ },
  { TN_36_ID, "\01\04drop", "\01\04help", TN_36_UQ },
  { TN_37_ID, "\01\04byte", "\01\04help", TN_37_UQ },
  { TN_38_ID, "\01\04rssi", "\01\04help", TN_38_UQ },
  { TN_39_ID, "\01\06tx_pwr", "\01\04help", TN_39_UQ },
};

