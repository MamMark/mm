
typedef enum {
  S_SDN = 0,
  S_CONFIG_W,
  S_POR_W,
  S_PWR_UP_W,
  S_RX_ACTIVE,
  S_RX_ON,
  S_STANDBY,
  S_TX_ACTIVE,
  S_DEFAULT,
} fsm_state_t;

typedef enum {
  E_0NOP = 0,
  E_NONE = 0,
  E_CONFIG_DONE,
  E_CRC_ERROR,
  E_INVALID_SYNC,
  E_PACKET_RX,
  E_PACKET_SENT,
  E_PREAMBLE_DETECT,
  E_RX_THRESH,
  E_STANDBY,
  E_SYNC_DETECT,
  E_TRANSMIT,
  E_TURNOFF,
  E_TURNON,
  E_TX_THRESH,
  E_WAIT_DONE,
} fsm_event_t;

typedef enum {
  A_BREAK = 0,
  A_CLEAR_SYNC,
  A_CONFIG,
  A_NOP,
  A_PWR_DN,
  A_PWR_UP,
  A_READY,
  A_RX_CMP,
  A_RX_CNT_CRC,
  A_RX_DRAIN_FF,
  A_RX_START,
  A_RX_TIMEOUT,
  A_STANDBY,
  A_TX_CMP,
  A_TX_FILL_FF,
  A_TX_START,
  A_TX_TIMEOUT,
  A_UNSHUT,
} fsm_action_t;

typedef struct {
  fsm_state_t    current_state;
  fsm_action_t   action;
  fsm_state_t    next_state;
} fsm_transition_t;

typedef struct {
  fsm_event_t    e;
  fsm_state_t    s;
} fsm_result_t;

const fsm_transition_t fsm_e_0nop[];
const fsm_transition_t fsm_e_config_done[];
const fsm_transition_t fsm_e_crc_error[];
const fsm_transition_t fsm_e_invalid_sync[];
const fsm_transition_t fsm_e_packet_rx[];
const fsm_transition_t fsm_e_packet_sent[];
const fsm_transition_t fsm_e_preamble_detect[];
const fsm_transition_t fsm_e_rx_thresh[];
const fsm_transition_t fsm_e_standby[];
const fsm_transition_t fsm_e_sync_detect[];
const fsm_transition_t fsm_e_transmit[];
const fsm_transition_t fsm_e_turnoff[];
const fsm_transition_t fsm_e_turnon[];
const fsm_transition_t fsm_e_tx_thresh[];
const fsm_transition_t fsm_e_wait_done[];

fsm_result_t a_clear_sync(fsm_transition_t *t);
fsm_result_t a_config(fsm_transition_t *t);
fsm_result_t a_nop(fsm_transition_t *t);
fsm_result_t a_pwr_dn(fsm_transition_t *t);
fsm_result_t a_pwr_up(fsm_transition_t *t);
fsm_result_t a_ready(fsm_transition_t *t);
fsm_result_t a_rx_cmp(fsm_transition_t *t);
fsm_result_t a_rx_cnt_crc(fsm_transition_t *t);
fsm_result_t a_rx_drain_ff(fsm_transition_t *t);
fsm_result_t a_rx_start(fsm_transition_t *t);
fsm_result_t a_rx_timeout(fsm_transition_t *t);
fsm_result_t a_standby(fsm_transition_t *t);
fsm_result_t a_tx_cmp(fsm_transition_t *t);
fsm_result_t a_tx_fill_ff(fsm_transition_t *t);
fsm_result_t a_tx_start(fsm_transition_t *t);
fsm_result_t a_tx_timeout(fsm_transition_t *t);
fsm_result_t a_unshut(fsm_transition_t *t);

const fsm_transition_t fsm_e_tx_thresh[] = {
  {S_TX_ACTIVE, A_TX_FILL_FF, S_TX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_invalid_sync[] = {
  {S_RX_ON, A_CLEAR_SYNC, S_RX_ON},
  {S_RX_ACTIVE, A_CLEAR_SYNC, S_RX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_packet_rx[] = {
  {S_RX_ACTIVE, A_RX_CMP, S_RX_ON},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_turnon[] = {
  {S_SDN, A_UNSHUT, S_POR_W},
  {S_STANDBY, A_READY, S_RX_ON},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_packet_sent[] = {
  {S_TX_ACTIVE, A_TX_CMP, S_RX_ON},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_transmit[] = {
  {S_RX_ON, A_TX_START, S_TX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_config_done[] = {
  {S_CONFIG_W, A_READY, S_RX_ON},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_rx_thresh[] = {
  {S_RX_ACTIVE, A_RX_DRAIN_FF, S_RX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_standby[] = {
  {S_SDN, A_CONFIG, S_STANDBY},
  {S_RX_ON, A_STANDBY, S_STANDBY},
  {S_RX_ACTIVE, A_STANDBY, S_STANDBY},
  {S_TX_ACTIVE, A_STANDBY, S_STANDBY},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_wait_done[] = {
  {S_POR_W, A_PWR_UP, S_PWR_UP_W},
  {S_RX_ACTIVE, A_RX_TIMEOUT, S_RX_ON},
  {S_TX_ACTIVE, A_TX_TIMEOUT, S_RX_ON},
  {S_PWR_UP_W, A_CONFIG, S_CONFIG_W},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_0nop[] = {
  {S_DEFAULT, A_NOP, S_DEFAULT},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_crc_error[] = {
  {S_RX_ACTIVE, A_RX_CNT_CRC, S_RX_ON},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_preamble_detect[] = {
  {S_RX_ON, A_NOP, S_RX_ON},
  {S_RX_ACTIVE, A_NOP, S_RX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_sync_detect[] = {
  {S_RX_ON, A_RX_START, S_RX_ACTIVE},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t fsm_e_turnoff[] = {
  {S_RX_ON, A_PWR_DN, S_SDN},
  {S_RX_ACTIVE, A_PWR_DN, S_SDN},
  {S_TX_ACTIVE, A_PWR_DN, S_SDN},
  {S_STANDBY, A_PWR_DN, S_SDN},
  { S_DEFAULT, A_BREAK, S_DEFAULT },
};

const fsm_transition_t *fsm_events_group[] = {
fsm_e_0nop,  fsm_e_config_done,  fsm_e_crc_error,  fsm_e_invalid_sync,  fsm_e_packet_rx,  fsm_e_packet_sent,  fsm_e_preamble_detect,  fsm_e_rx_thresh,  fsm_e_standby,  fsm_e_sync_detect,  fsm_e_transmit,  fsm_e_turnoff,  fsm_e_turnon,  fsm_e_tx_thresh,  fsm_e_wait_done,  };
