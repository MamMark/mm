/*
 * l3g4200.h
 */

/* SPI Flag Bits */
#define READ_REG         0x80
#define WRITE_REG        0x00
#define MULT_ADDR        0x40
#define SINGLE_ADDR      0x00

/* 
 * Register with ID value. Validate SPI xfer by reading this
 * register: Value should equal WHO_I_AM.
 */
#define WHO_AM_I         0x0f
#define WHO_I_AM         0xd3

#define CTRL_REG1        0x20
#define ODR_MASK         0xf0	/* Output data rate mask */
#define POWER            0x08	/* Power: 0=power down,1=normal/sleep */
                                /* Set XEN=YEN=ZEN=0 for sleep mode */
#define ZEN              0x04	/* Z axis enable */
#define YEN              0x02	/* Y axis enable */
#define XEN              0x01   /* X axis enable */

#define CTRL_REG2        0x21
#define HPM_MASK         0x30   /* High pass filter mode mask */
#define  HPM_NORMAL      0x00   /*  High pass normal mode */
#define  HPM_REFERENCE   0x10   /*  Use reference for filtering */
#define  HPM_NORMAL2     0x20   /*  Normal mode */
#define  HPM_AUTORESET   0x30   /*  Reset on interrupt */
#define HPC_MASK         0x0f   /* High pass filter cutoff mask */

#define CTRL_REG3        0x22
#define I1_INT1          0x80   /* Enable interrupt on INT1 pin */
#define I1_BOOT          0x40   /* Boot status on INT1 pin */
#define HL_ACTIVE        0x20   /* Interrupt active on INT1 */
#define PP_OD            0x10   /* Push-pull/Open Drain */
#define I2_DRDY          0x08   /* Data Ready on DRDY/INT2 */
#define I2_WTM           0x04   /* FIFO Watermark interrupt on INT2 */
#define I2_ORUN          0x02   /* FIFO Overrun interrupt on INT2 */
#define I2_EMPTY         0x01   /* FIFO empty interrupt on INT2 */

#define CTRL_REG4        0x23
#define BDU              0x80   /* Block data update */
#define BLE              0x40   /* Big or little endian */
#define FS_MASK          0x30   /* Full scale deflection mask */
#define  FS_250          0x00   /*  250 dps */
#define  FS_500          0x10   /*  500 dps */
#define  FS_2000         0x20   /*  2000 dps */
#define ST_MASK          0x06   /* Self test mode mask */
#define  ST_DISABLED     0x00   /*  Self test disabled */
#define  ST_0            0x02   /*  Self test 0 */
#define  ST_1            0x06   /*  Self test 1 */
#define SIM              0x01   /* SPI mode: 0=4wire, 1=3wire */

#define CTRL_REG5        0x24
#define BOOT             0x80   /* Reboot memory content */
#define FIFO_ENABLE      0x40   /* FIFO Enable */
#define HPEN             0x10   /* High pass filter enable */
#define INT1_SEL_MASK    0x0c   /* INT1 generation select mask */
#define OUT_SEL_MASK     0x03   /* Output filtering select mask */

#define REFERENCE        0x25

#define OUT_TEMP         0x26

#define STATUS_REG       0x27
#define ZYZOR            0x80   /* ZYX Overrun */
#define ZOR              0x40   /* Z Overrun */
#define YOR              0x20   /* Y Overrun */
#define XOR              0x10   /* X Overrun */
#define ZYXDA            0x08   /* ZYX Data Available */
#define ZDA              0x04   /* Z Data Available */
#define YDA              0x02   /* Y Data Available */
#define XDA              0x01   /* X Data Available */

/*
 * X, Y and Z data registers
 */
#define OUT_X_L          0x28
#define OUT_X_H          0x29
#define OUT_Y_L          0x2a
#define OUT_Y_H          0x2b
#define OUT_Z_L          0x2c
#define OUT_Z_H          0x2d

#define FIFO_CTRL_REG    0x2e
#define FM_MASK          0xe0   /* FIFO mode select mask */
#define  FM_BYPASS       0x00   /*  FIFO Bypass mode */
#define  FM_FIFO         0x20   /*  FIFO mode */
#define  FM_STREAM       0x40   /*  FIFO Stream mode */
#define  FM_S2F          0x60   /*  Stream-to-FIFO mode */
#define  FM_B2S          0x80   /*  Bypass-to-Stream mode */
#define WTM_MASK         0x1f   /* FIFO Watermark mask */

#define FIFO_SRC_REG     0x2f
#define WTM              0x80   /* FIFO watermark status */
#define OVRN             0x40   /* FIFO Overrun status */
#define EMPTY            0x20   /* FIFO Empty */
#define FSS_MASK         0x1f   /* FIFO Sample Store count mask */

#define INT1_CFG         0x30

#define INT1_SRC         0x31

#define INT1_THS_XH      0x32
#define INT1_THS_XL      0x33
#define INT1_THS_YH      0x34
#define INT1_THS_YL      0x35
#define INT1_THS_ZH      0x36
#define INT1_THS_ZL      0x37

#define INT1_DURATION    0x38

