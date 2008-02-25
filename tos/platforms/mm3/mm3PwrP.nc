#include "hardware.h"

module mm3PwrP {
  provides interface mm3Pwr as PwrClient[uint8_t client_id];
}

implementation {
  uint8_t cur_pwr_client;

  task void pwrclient_grant() {
    signal PwrClient.granted[cur_pwr_client]();
  }

  command error_t PwrClient.request[uint8_t client_id]() {
    cur_pwr_client = client_id;
    post pwrclient_grant();
//    signal PwrClient.granted[client_id]();
    return SUCCESS;
  }

//  command error_t PwrClient.immediateRequest[uint8_t client_id]() {
//    return SUCCESS;
//  }

  command error_t PwrClient.release[uint8_t client_id]() {
    return SUCCESS;
  }

//  command bool PwrClient.isOwner[uint8_t client_id]() {
//    return FALSE;
//  }

  default event void PwrClient.granted[uint8_t id]() {}
}
