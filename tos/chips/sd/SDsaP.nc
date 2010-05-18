/*
 * SDsa - stand alone SD driver prototype
 * try using raw interface, no shared code.
 *
 * Copyright (c) 2010, Eric B. Decker, Carl Davis
 * All rights reserved.
 */

#include "msp430hardware.h"
#include "hardware.h"
#include "sd.h"
#include "sd_cmd.h"
#include "panic.h"

#ifdef FAIL
#warning "FAIL defined, undefining, it should be an enum"
#undef FAIL
#endif

module SDsaP {
  provides {
    interface SDsa;
  }
  uses {
    interface SDraw;
    interface HplMsp430UsciB as Usci;
    interface Hpl_MM_hw as HW;
  }
}

implementation {

#include "platform_sd_spi.h"

  command error_t SDsa.reset() {
    sd_cmd_t *cmd;                // Command Structure

    call HW.sd_on();
    call Usci.setModeSpi((msp430_spi_union_config_t *) &sd_full_config);
    cmd = call SDraw.cmd_ptr();
    call SDraw.send_recv(NULL, NULL, 10);
    cmd->cmd = SD_FORCE_IDLE;		// Send CMD0, software reset
    cmd->arg = 0;
    rsp = sd_send_command();
    if (rsp & ~MSK_IDLE) {		/* ignore idle for errors */
      return FAIL;
    }

    send acmd go_op;
    call SDraw.send_acmd();
    return SUCCESS;
  }


  command error_t SDsa.read() {
    return SUCCESS;
  }


  command error_t SDsa.write() {
    return SUCCESS;
  }
}
