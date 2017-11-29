// THIS IS AN AUTO-GENERATED FILE, DO NOT EDIT

typedef enum {                   //      (parent) name
  TN_20_ID              =    20, //  (<node_id:>) nib
  TN_21_ID              =    21, //  (<node_id:>) running
  TN_11_ID              =    11, //  (   tag    ) sd
  TN_10_ID              =    10, //  (   gps    ) xyz
  TN_13_ID              =    13, //  (<node_id:>) 0
  TN_12_ID              =    12, //  (    sd    ) <node_id:>
  TN_15_ID              =    15, //  (   tag    ) sys
  TN_14_ID              =    14, //  (    0     ) img
  TN_17_ID              =    17, //  (<node_id:>) active
  TN_16_ID              =    16, //  (   sys    ) <node_id:>
  TN_19_ID              =    19, //  (<node_id:>) golden
  TN_18_ID              =    18, //  (<node_id:>) backup
  TN_1_ID               =     1, //  (   root   ) tag
  TN_0_ID               =     0, //  (    _     ) root
  TN_3_ID               =     3, //  (   poll   ) <node_id:>
  TN_2_ID               =     2, //  (   tag    ) poll
  TN_5_ID               =     5, //  (<node_id:>) cnt
  TN_4_ID               =     4, //  (<node_id:>) ev
  TN_7_ID               =     7, //  (   info   ) <node_id:>
  TN_6_ID               =     6, //  (   tag    ) info
  TN_9_ID               =     9, //  (   sens   ) gps
  TN_8_ID               =     8, //  (<node_id:>) sens
  TN_LAST_ID            =    22,
  TN_ROOT_ID            =     0,
  TN_MAX_ID             =  65000,
} tn_ids_t;

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
  { TN_3_ID, "\01\012<node_id:>", "\01\04help", TN_3_UQ },
  { TN_4_ID, "\01\02ev", "\01\04help", TN_4_UQ },
  { TN_5_ID, "\01\03cnt", "\01\04help", TN_5_UQ },
  { TN_6_ID, "\01\04info", "\01\04help", TN_6_UQ },
  { TN_7_ID, "\01\012<node_id:>", "\01\04help", TN_7_UQ },
  { TN_8_ID, "\01\04sens", "\01\04help", TN_8_UQ },
  { TN_9_ID, "\01\03gps", "\01\04help", TN_9_UQ },
  { TN_10_ID, "\01\03xyz", "\01\04help", TN_10_UQ },
  { TN_11_ID, "\01\02sd", "\01\04help", TN_11_UQ },
  { TN_12_ID, "\01\012<node_id:>", "\01\04help", TN_12_UQ },
  { TN_13_ID, "\01\010", "\01\04help", TN_13_UQ },
  { TN_14_ID, "\01\03img", "\01\04help", TN_14_UQ },
  { TN_15_ID, "\01\03sys", "\01\04help", TN_15_UQ },
  { TN_16_ID, "\01\012<node_id:>", "\01\04help", TN_16_UQ },
  { TN_17_ID, "\01\06active", "\01\04help", TN_17_UQ },
  { TN_18_ID, "\01\06backup", "\01\04help", TN_18_UQ },
  { TN_19_ID, "\01\06golden", "\01\04help", TN_19_UQ },
  { TN_20_ID, "\01\03nib", "\01\04help", TN_20_UQ },
  { TN_21_ID, "\01\07running", "\01\04help", TN_21_UQ },
};

