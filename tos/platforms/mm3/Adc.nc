/*
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * This interface provides access to the mm3 ADC subsystem.
 *
 * The MM3 ADC uses a stand alone ADC chip interfaced to a combination
 * differential and single ended multiplexed system.  The read of the
 * actual ADC is single ended and the call returns the value read (it
 * takes approximately 5 uS)
 *.
 * Configuration on the other hand is split phase and can take significant
 * time.
 *
 * A sensor requests access from the ADC system via Adc.reqConfigure.  The
 * ADC system obtains the sensor's configuration via an upcall through the
 * AdcConfigure interface.  Unlike resource request, the Adc subsystem will
 * signal the sensor driver to proceed via the signal Adc.configured.
 * This is the completion part of the split phase configure.
 *
 * Once a sensor driver has been signalled that the configuration is
 * completed it can access the result via Adc.read which completes
 * immediately after accessing the ADC via the SPI.  Actual access of the
 * ADC is single phase and completes immediately.
 *
 * A sensor driver can request a reconfiguration via Adc.reconfigure,
 * completion of which is signalled via Adc.configured.  This split phase
 * interface is used by sensor devices that contain multiple parts (a
 * composite sensor, ie. accelerometer with X, Y, and Z components).
 */

interface Adc {
  /**
   * A sensor driver gains access to the ADC subsystem via Adc.reqConfigure.
   * This both requests access to the shared ADC but also requests a
   * configuration be installed once access is awarded.
   *
   * After the requester owns the ADC and the configuration has been
   * completed the signal Adc.configured is generated telling the
   * client to proceed.
   *
   * adcRelease() is used when the sensor driver is finished.  This
   * also power off the sensor.
   *
   * The ADC subsystem will make sure that main power (Vref and Vdiff if needed)
   * are on and settled, the appropriate mux settings have been made and enough time
   * has been allowed for the signal levels to propagate to the ADC.  This
   * is part of the initial configuration cycle and when complete Adc.configured
   * will be signalled.
   *
   * If a sensor is a singleton (only one value is obtained from the device)
   * then the driver will release after reading.
   *
   * Some sensors, however, consist of one device providing multiple values.
   * The device is powered up on the request, the first value read, and then
   * a reconfiguration request is made.  The ADC subsystem will change any
   * values needed, and allow things to settle.  Upon completion Adc.configured
   * will be signalled.  This is repeated for each part of the device.  When
   * complete the driver will call Adc.release to power the sensor down and
   * release ADC ownership.
   *
   * For a single ended sensor the appropriate smux setting will be selected
   * and the settling time is included in the inital delay prior to the
   * Adc.configured signal being generated.  (A single alarm is used when
   * powering up which is the max of t_vref, t_diff, and t_settle).  All times
   * are in terms of 32KHz jiffies (1/32768, ~30.5uS).
   *
   * For differential sensors, the Vdiff amp system is first slewed to
   * the mid-point (using a high gain sensor with low gain setting).
   * Once at the mid-point (time based), dmux is set to the sensor being
   * sampled and gmux to the appropriate gain.  Smux is set to connect
   * the differential system to the output of the diff amps.  This requires
   * an extra timing cycle.
   *
   * A note on power timing.  Power delays use the underlying 32KHz timing
   * hardware.  Timing units are in terms of 16 bit (uint16_t) 32KHz jiffies.
   * 64K jiffies = 2 secs.  Each jiffy is about 30.5 uS.
   *
   * @return SUCCESS When a request has been accepted. The granted()
   *                 event will be signaled once you have control of the
   *                 resource.<br>
   *         EBUSY You have already requested this resource and a
   *               granted event is pending
   */
  command error_t reqConfigure();


  /**
   * reconfigure
   *
   * tell the ADC subsystem that the configuration must be changed.
   * This is used by a composite sensor driver running a multiple sensor
   * device.  For example an accelerometer that gets powered on
   * once but has X, Y, and Z parts that must get sampled.
   *
   * The ADC subsystem is responsible for any settling time required
   * by the change.  This is a split phase event.  Upon completion
   * Adc.configured() is signaled.
   *
   * Only the current owner can reconfigure the ADC subsystem.
   */
  command void reconfigure(const mm3_sensor_config_t* config);


  /**
   * Tell the client the ADC configuration has been installed.  ie. powered
   * up, proper mux settings in place, and settling time has elapsed.
   */
  event void configured();
   

  /**
  * Release the ADC subsystem.  This will also turn off power
  * to the sensor.
  *
  * @return SUCCESS The resource has been released <br>
  *         FAIL You tried to release but you are not the
  *              owner of the resource 
  *
  * @note This command should never be called between putting in a request 	  
  *       and waiting for a granted event.  Doing so will result in a
  *       potential race condition.  There are ways to guarantee that no
  *       race will occur, but they are clumsy and overly complicated.
  *       Since it doesn't logically make since to be calling
  *       <code>release</code> before receiving a <code>granted</code> event, 
  *       we have opted to keep thing simple and warn you about the potential 
  *       race.
  */
  command error_t release();


  /**
   * isOwner
   *
   * returns true if the client is the current owner of the ADC.
   */
  command bool isOwner();


  /**
   * readAdc
   *
   * obtain data directly from the ADC.  Starts a conversion
   * cycle (which doesn't take very long) and returns the data.
   *
   * This is single phase and returns immediately after obtaining
   * the data.
   **/
  command uint16_t readAdc();
}
