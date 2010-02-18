/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

#include "logevent.h"

interface LogEvent {
  command void logEvent(uint8_t ev, uint16_t arg);
  //  command void setEventSet(uint16_t setMask);
  //  command uint16_t getEventSet();
}
