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

  /*
   * power_vref: power up or down main sensor power
   * power_vdiff: power up or down the differential system.
   * isVrefPowered: true if Vref is up
   * isVdiffPowered: true if Vdiff is up.  Does not account
   *   for any timing.  It just returns whether or not the
   *   bit controlling Vref/Vdiff power is set.
   */
  command void power_vref(bool up);
  command void power_vdiff(bool up);
  command bool isVrefPowered();
  command bool isVdiffPowered();
  command void toggleSal();

  /*
   * Returns the current Diff Mux control value
   * @return dmux control value
   */
  command uint8_t get_dmux();

  /*
   * Set dmux control value
   * @param dmux control value
   */
  command void    set_dmux(uint8_t);

  /*
   * Returns the current SMux control value
   * @return smux control value
   */
  command uint8_t get_smux();

  /*
   * Set smux control value
   * @param smux control value
   */
  command void    set_smux(uint8_t val);

  /*
   * Returns the current diff gain Mux control value
   * @return gmux control value
   */
  command uint8_t get_gmux();

  /*
   * Set gmux control value
   * @param gain mux control value
   */
  command void    set_gmux(uint8_t val);
}
