/*
 * Copyright (c) 2008, Eric B. Decker
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
 * The HplMM3Adc interface exports low-level access control registers effecting
 * the MM3 conversion system.  This includes power control for the Vref, Vdiff,
 * and sensor power.  Also included is access to the control muxes (smux, dmux, and
 * gmux).
 *
 * @author Eric B. Decker
 */
 
interface HplMM3Adc {
  command void	  vref_on();
  command void	  vref_off();
  command void	  vdiff_on();
  command void	  vdiff_off();

//  command bool	  isVrefPowered();
//  command bool	  isVdiffPowered();

  command void	  toggleSal();
  command uint8_t get_dmux();
  command void	  set_dmux(uint8_t val);
  command uint8_t get_smux();
  command void	  set_smux(uint8_t val);
  command uint8_t get_gmux();
  command void	  set_gmux(uint8_t val);
  command void	  batt_on();
  command void	  batt_off();
  command void	  temp_on();
  command void	  temp_off();
  command void	  sal_on();
  command void	  sal_off();
  command void	  accel_on();
  command void	  accel_off();
  command void	  ptemp_on();
  command void	  ptemp_off();
  command void	  press_on();
  command void	  press_off();
  command void	  speed_on();
  command void	  speed_off();
  command void	  mag_on();
  command void	  mag_off();

  async command bool isSDPowered();
  async command void sd_on();
  async command void sd_off();
  async command void gps_on();
  async command void gps_off();
}
