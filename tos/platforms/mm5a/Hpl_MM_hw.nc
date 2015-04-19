/*
 * Copyright (c) 2014-2015 Eric B. Decker
 * All rights reserved.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA,
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *
 */
        
/**
 * The Hpl_MM_hw interface exports low-level access control registers effecting
 * the MM5a platform h/w.
 *
 * @author Eric B. Decker <cire831@gmail.com>
 */
 
interface Hpl_MM_hw {
  async command bool r446x_cts();
  async command bool r446x_irq();
  async command void r446x_shutdown();
  async command void r446x_unshutdown();
  async command void r446x_set_cs();
  async command void r446x_clr_cs();
  async command void r446x_set_low_pwr();
  async command void r446x_set_high_pwr();

  async command bool mems_gyro_drdy();
  async command bool mems_gyro_irq();
  async command bool mems_mag_drdy();
  async command bool mems_mag_irq();
  async command bool mems_accel_int1();
  async command bool mems_accel_int2();
  async command void mems_accel_set_cs();
  async command void mems_accel_clr_cs();
  async command void mems_gyro_set_cs();
  async command void mems_gyro_clr_cs();
  async command void mems_mag_set_cs();
  async command void mems_mag_clr_cs();

  async command void sd_set_access();
  async command void sd_clr_access();
  async command bool sd_got_access();
  async command void sd_pwr_on();
  async command void sd_pwr_off();
  async command void sd_set_cs();
  async command void sd_clr_cs();

  async command bool adc_drdy();
  async command void adc_set_start();
  async command void adc_clr_start();
  async command void adc_set_cs();
  async command void adc_clr_cs();
  /* need mux4x and mux2x */

  async command bool dock_irq();

  async command bool gps_awake();
  async command void gps_set_cs();
  async command void gps_clr_cs();
  async command void gps_set_on_off();
  async command void gps_clr_on_off();
  async command void gps_set_reset();
  async command void gps_clr_reset();

  async command void pwr_3v3_on();
  async command void pwr_3v3_off();
  async command void pwr_solar_ena();
  async command void pwr_solar_dis();
  async command void pwr_bat_sense_ena();
  async command void pwr_bat_sense_dis();
  async command void pwr_tmp_on();
  async command void pwr_tmp_off();
}
