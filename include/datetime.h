/*
 * Copyright (c) 2017-2018 Daniel J Maltbie, Eric B. Decker
 * All rights reserved.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 * See COPYING in the top level directory of this source tree.
 *
 * Contact: Eric B. Decker <cire831@gmail.com>
 *          Daniel J. Maltbie <dmaltbie@danome.com>
 */

#ifndef __DATETIME_H__
#define __DATETIME_H__

typedef struct {                        /* little endian order  */
  uint16_t	jiffies;                /* 16 bit jiffies (32KiHz) */
  uint8_t	sec;                    /* 0-59, TIM0 */
  uint8_t	min;                    /* 0-59, TIM0 */
  uint8_t	hr;                     /* 0-23, TIM1 */
  uint8_t       dow;                    /* day of week, 0-6, 0 sunday */
  uint8_t	day;                    /* 1-31, DATE */
  uint8_t	mon;                    /* 1-12, DATE */
  uint16_t	yr;
} datetime_t;


typedef union {
  struct {
    uint16_t	jiffies;                /* 16 bit jiffies (32KiHz) */
    uint8_t	sec;                    /* 0-59 */
    uint8_t	min;                    /* 0-59 */
    uint8_t	hr;                     /* 0-23 */
    uint8_t     dow;                    /* day of week, 0-6, 0 sunday */
    uint8_t	day;                    /* 1-31 */
    uint8_t	mon;                    /* 1-12 */
  } xs;                                 /* structure */
  uint64_t x64;                         /* 64 bit    */
} dt64_t;


#endif  /* __DATETIME_H__ */
