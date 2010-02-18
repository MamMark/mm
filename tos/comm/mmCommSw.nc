/*
 * Copyright (c) 2008-2010 Eric B. Decker
 * All rights reserved.
 */
 
/**
 * @author Eric B. Decker <cire831@gmail.com>
 */

interface mmCommSw {
  command error_t useSerial();
  event void serialOn();
  command error_t useRadio();
  event void radioOn();
  command error_t useNone();
  event void commOff();
}
