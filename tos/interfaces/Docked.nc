/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 */

interface Docked {
  command bool isDocked();
  event void docked();
  event void undocked();
}
