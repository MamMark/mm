#ifndef _H_MM3_PORT_REGS_H
#define _H_MM3_PORT_REGS_H
  static volatile struct {
    uint8_t dmux	        : 2;
    uint8_t mag_deguass1    : 1;
    uint8_t gps_rx_out      : 1;
    uint8_t mag_deguass2    : 1;
    uint8_t press_res_off   : 1;
    uint8_t salinity_off    : 1;
    uint8_t press_off       : 1;
  } mmP1out;

  static volatile struct {
    uint8_t u8_inhibit		: 1;
    uint8_t accel_wake		: 1;
    uint8_t salinity_pol_sw	: 1;
    uint8_t u12_inhibit		: 1;
    uint8_t smux_low2		: 2;
    uint8_t adc_cnv		: 1;
    uint8_t			: 1;
  } mmP2out;

  static volatile struct {
    uint8_t			: 1;
    uint8_t smux_a2		: 1;
    uint8_t adc_sdo		: 1;	/* input */
    uint8_t adc_clk		: 1;
    uint8_t tmp_on		: 1;
    uint8_t adc_sdi		: 1;
    uint8_t utxd1		: 1;
    uint8_t urxd1_o		: 1;
  } mmP3out;

  static volatile struct {
    uint8_t gmux		: 2;
    uint8_t vdiff_off		: 1;
    uint8_t vref_off		: 1;
    uint8_t solar_chg_on	: 1;
    uint8_t extchg_battchk	: 1;
    uint8_t gps_off		: 1;
    uint8_t rf232_off		: 1;
  } mmP4out;

norace  static volatile struct {
    uint8_t sd_pwr_off		: 1;
    uint8_t sd_sdi		: 1;
    uint8_t sd_sdo		: 1;
    uint8_t sd_clk		: 1;
    uint8_t sd_csn		: 1;	/* chip select low true (deselect) */
    uint8_t rf_beep_off		: 1;
    uint8_t ser_sel		: 2;
  } mmP5out;

  static volatile struct {
    uint8_t			: 1;
    uint8_t			: 1;
    uint8_t			: 1;
    uint8_t tell		: 1;
    uint8_t speed_off		: 1;
    uint8_t mag_xy_off		: 1;
    uint8_t led_y		: 1;
    uint8_t mag_z_off		: 1;
  } mmP6out;
  
#endif //_H_MM3_PORT_REGS_H
