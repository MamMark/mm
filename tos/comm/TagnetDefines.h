// THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT

typedef enum {                   //      (parent) name
  TN_22_ID              =    22, //  (<nodeid:010203040506>) nib
  TN_20_ID              =    20, //  (<nodeid:010203040506>) backup
  TN_21_ID              =    21, //  (<nodeid:010203040506>) golden
  TN_11_ID              =    11, //  (   tag    ) sd
  TN_10_ID              =    10, //  (   gps    ) xyz
  TN_13_ID              =    13, //  (<nodeid:010203040506>) 0
  TN_12_ID              =    12, //  (    sd    ) <nodeid:010203040506>
  TN_15_ID              =    15, //  (   dblk   ) 0
  TN_14_ID              =    14, //  (    0     ) dblk
  TN_17_ID              =    17, //  (   tag    ) sys
  TN_16_ID              =    16, //  (    0     ) img
  TN_19_ID              =    19, //  (<nodeid:010203040506>) active
  TN_18_ID              =    18, //  (   sys    ) <nodeid:010203040506>
  TN_23_ID              =    23, //  (<nodeid:010203040506>) running
  TN_1_ID               =     1, //  (   root   ) tag
  TN_0_ID               =     0, //  (    _     ) root
  TN_3_ID               =     3, //  (   poll   ) <nodeid:010203040506>
  TN_2_ID               =     2, //  (   tag    ) poll
  TN_5_ID               =     5, //  (<nodeid:010203040506>) cnt
  TN_4_ID               =     4, //  (<nodeid:010203040506>) ev
  TN_7_ID               =     7, //  (   info   ) <nodeid:010203040506>
  TN_6_ID               =     6, //  (   tag    ) info
  TN_9_ID               =     9, //  (   sens   ) gps
  TN_8_ID               =     8, //  (<nodeid:010203040506>) sens
  TN_LAST_ID            =    24,
  TN_ROOT_ID            =     0,
  TN_MAX_ID             =  65000,
} tn_ids_t;

#define  TN_22_UQ                "TN_22_UQ"
#define  TN_20_UQ                "TN_20_UQ"
#define  TN_21_UQ                "TN_21_UQ"
#define  TN_11_UQ                "TN_11_UQ"
#define  TN_10_UQ                "TN_10_UQ"
#define  TN_13_UQ                "TN_13_UQ"
#define  TN_12_UQ                "TN_12_UQ"
#define  TN_15_UQ                "TN_15_UQ"
#define  TN_14_UQ                "TN_14_UQ"
#define  TN_17_UQ                "TN_17_UQ"
#define  TN_16_UQ                "TN_16_UQ"
#define  TN_19_UQ                "TN_19_UQ"
#define  TN_18_UQ                "TN_18_UQ"
#define  TN_23_UQ                "TN_23_UQ"
#define  TN_1_UQ                 "TN_1_UQ"
#define  TN_0_UQ                 "TN_0_UQ"
#define  TN_3_UQ                 "TN_3_UQ"
#define  TN_2_UQ                 "TN_2_UQ"
#define  TN_5_UQ                 "TN_5_UQ"
#define  TN_4_UQ                 "TN_4_UQ"
#define  TN_7_UQ                 "TN_7_UQ"
#define  TN_6_UQ                 "TN_6_UQ"
#define  TN_9_UQ                 "TN_9_UQ"
#define  TN_8_UQ                 "TN_8_UQ"
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
  { TN_1_ID, "\01\03tag", "\01\04help", TN_1_UQ },
  { TN_2_ID, "\01\04poll", "\01\04help", TN_2_UQ },
  { TN_3_ID, "\05\06\01\02\03\04\05\06", "\01\04help", TN_3_UQ },
  { TN_4_ID, "\01\02ev", "\01\04help", TN_4_UQ },
  { TN_5_ID, "\01\03cnt", "\01\04help", TN_5_UQ },
  { TN_6_ID, "\01\04info", "\01\04help", TN_6_UQ },
  { TN_7_ID, "\05\06\01\02\03\04\05\06", "\01\04help", TN_7_UQ },
  { TN_8_ID, "\01\04sens", "\01\04help", TN_8_UQ },
  { TN_9_ID, "\01\03gps", "\01\04help", TN_9_UQ },
  { TN_10_ID, "\01\03xyz", "\01\04help", TN_10_UQ },
  { TN_11_ID, "\01\02sd", "\01\04help", TN_11_UQ },
  { TN_12_ID, "\05\06\01\02\03\04\05\06", "\01\04help", TN_12_UQ },
  { TN_13_ID, "\02\01\00", "\01\04help", TN_13_UQ },
  { TN_14_ID, "\01\04dblk", "\01\04help", TN_14_UQ },
  { TN_15_ID, "\02\01\00", "\01\04help", TN_15_UQ },
  { TN_16_ID, "\01\03img", "\01\04help", TN_16_UQ },
  { TN_17_ID, "\01\03sys", "\01\04help", TN_17_UQ },
  { TN_18_ID, "\05\06\01\02\03\04\05\06", "\01\04help", TN_18_UQ },
  { TN_19_ID, "\01\06active", "\01\04help", TN_19_UQ },
  { TN_20_ID, "\01\06backup", "\01\04help", TN_20_UQ },
  { TN_21_ID, "\01\06golden", "\01\04help", TN_21_UQ },
  { TN_22_ID, "\01\03nib", "\01\04help", TN_22_UQ },
  { TN_23_ID, "\01\07running", "\01\04help", TN_23_UQ },
};

