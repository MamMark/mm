/*
 * Copyright (c) 2021 Eric B. Decker
 * All rights reserved.
 */

/**
 * mm7 does not have any LEDs
 *
 * This module provides the general Led interface.
 *
 * The advantage to doing it this way is we can now create a platforms
 * that provide more or less than 3 LED's, and the LED's can be pull-up or
 * pull-down enabled.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */

module PlatformLedsP {
  provides {
    interface Init;
    interface Leds;
  }

  uses {
    interface GeneralIO as Led0;
    interface GeneralIO as Led1;
    interface GeneralIO as Led2;
  }
}

implementation {

  /***************** Init Commands ****************/
  command error_t Init.init() {
    return SUCCESS;
  }

  /***************** Leds Commands ****************/
  async command void Leds.led0On()     {  }
  async command void Leds.led0Off()    {  }
  async command void Leds.led0Toggle() {  }
  async command void Leds.led1On()     {  }
  async command void Leds.led1Off()    {  }
  async command void Leds.led1Toggle() {  }
  async command void Leds.led2On()     {  }
  async command void Leds.led2Off()    {  }
  async command void Leds.led2Toggle() {  }

  async command uint8_t Leds.get()  {
    return 0;
  }

  async command void Leds.set(uint8_t val) {  }
}
