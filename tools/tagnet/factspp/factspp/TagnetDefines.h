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
  TN_LAST_ID            =    21,
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


const TN_data_t tn_name_data_descriptors[TN_LAST_ID]={
  { TN_0_ID, "\x01\x04root", "\x01\x04help", TN_0_UQ },
  { TN_1_ID, "\x01\x03tag", "\x01\x04help", TN_1_UQ },
  { TN_2_ID, "\x01\x04poll", "\x01\x04help", TN_2_UQ },
  { TN_3_ID, "\x01\n<node_id:>", "\x01\x04help", TN_3_UQ },
  { TN_4_ID, "\x01\x02ev", "\x01\x04help", TN_4_UQ },
  { TN_5_ID, "\x01\x03cnt", "\x01\x04help", TN_5_UQ },
  { TN_6_ID, "\x01\x04info", "\x01\x04help", TN_6_UQ },
  { TN_7_ID, "\x01\n<node_id:>", "\x01\x04help", TN_7_UQ },
  { TN_8_ID, "\x01\x04sens", "\x01\x04help", TN_8_UQ },
  { TN_9_ID, "\x01\x03gps", "\x01\x04help", TN_9_UQ },
  { TN_10_ID, "\x01\x03xyz", "\x01\x04help", TN_10_UQ },
  { TN_11_ID, "\x01\x02sd", "\x01\x04help", TN_11_UQ },
  { TN_12_ID, "\x01\n<node_id:>", "\x01\x04help", TN_12_UQ },
  { TN_13_ID, "\x01\x010", "\x01\x04help", TN_13_UQ },
  { TN_14_ID, "\x01\x03img", "\x01\x04help", TN_14_UQ },
  { TN_15_ID, "\x01\x03sys", "\x01\x04help", TN_15_UQ },
  { TN_16_ID, "\x01\n<node_id:>", "\x01\x04help", TN_16_UQ },
  { TN_17_ID, "\x01\x06active", "\x01\x04help", TN_17_UQ },
  { TN_18_ID, "\x01\x06backup", "\x01\x04help", TN_18_UQ },
  { TN_19_ID, "\x01\x06golden", "\x01\x04help", TN_19_UQ },
  { TN_20_ID, "\x01\x03nib", "\x01\x04help", TN_20_UQ },
  { TN_21_ID, "\x01\x07running", "\x01\x04help", TN_21_UQ },
};

