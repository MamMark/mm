/**
 * Copyright 2010 (c) Eric B. Decker
 * All rights reserved.
 *
 * @author Eric B. Decker
 *
 * define platform versioning and structures for representing it
 *
 *    8     8     8
 * major.minor.build
 */

#ifndef _H_PLATFORM_VERSION_h
#define _H_PLATFORM_VERSION_h


#define MAJOR 0
#define MINOR 4


typedef struct {
  uint8_t major;
  uint8_t minor;
  uint8_t build;
} version_t;

#endif // _H_PLATFORM_VERSION_H
