/*
 * serial_speed.h - define msp430 values for different baud rates
 * Copyright 2008, Eric B. Decker
 * Mam-Mark Project
 */

#ifndef __SERIAL_SPEED_H__
#define __SERIAL_SPEED_H__



enum {
  //32KHZ = 32,768 Hz, 1MHZ = 1,048,576 Hz, 4MHZ = 4,194,304

  UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x4a, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_115200=0x0024, UMCTL_4MHZ_115200=0x29, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_57600=0x0048, UMCTL_4MHZ_57600=0xfb, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_57600=0x0048, UMCTL_4MHZ_57600=0x7b, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_9600=0x01b4, UMCTL_4MHZ_9600=0xdf, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
//UBR_4MHZ_9600=0x01b4, UMCTL_4MHZ_9600=0xdf, // from http://mspgcc.sourceforge.net/baudrate.html

  UBR_4MHZ_4800=0x0369, UMCTL_4MHZ_4800=0xfb, // from http://www.daycounter.com/Calculators/MSP430-Uart-Calculator.phtml
};

#endif  /* __SERIAL_SPEED_H__ */
