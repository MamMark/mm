/* -*- mode:c; indent-tabs-mode:nil; c-basic-offset: 2 -*-
 *
 * Copyright (c) 2008, Eric B. Decker
 * All rights reserved.
 *
 * Based loosely on the Resource interface (Kevin Klues & Phil Levis)
 * Copyright (c) 2004, Technische Universitat Berlin
 * All rights reserved.
 */

interface mm3Adc {
  /**
   * Request access to the mm3 shared Adc resource. You must call release()
   * when you are done with it.
   *
   * When granted, the ADC subsystem will have made sure that main power
   * systems (Vref and Vdiff if needed) are on and enough time has been
   * allowed for the power to settle.
   *
   * For a single ended sensor the appropriate smux setting will be selected
   * and the settling time for the sensor taken into account.  (A single
   * timer is used when powering up which is the max of t_vref, t_diff,
   * and t_sensor).
   *
   * For differential sensors, the Vdiff amp system is first slewed to
   * the mid-point (using a high gain sensor with low gain setting).
   * Once at the mid-point (time based), dmux is set to the sensor being
   * sampled and gmux to the appropriate gain.  Smux is set to connect
   * the differential system to the output of the diff amps.  This requires
   * an extra timing cycle.
   *
   * After everything has had enough time to settle the grant is signaled
   * to the client.  This indicates that the adc system is ready to be
   * read and the client can proceed with the ADC access.
   *
   * @return SUCCESS When a request has been accepted. The granted()
   *                 event will be signaled once you have control of the
   *                 resource.<br>
   *         EBUSY You have already requested this resource and a
   *               granted event is pending
   */
  command error_t request();

  /**
   * Tell the client the ADC has powered things up and enough time has
   * elapsed for things to settle down.
   */
  event void granted();
   
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
   *  Check if the user of this interface is the current
   *  owner of the Resource
   *  @return TRUE  It is the owner <br>
   *             FALSE It is not the owner
   */
//  command bool isOwner();

  /**
   * readAdc
   *
   * obtain data directly from the ADC.  Starts a conversion
   * cycle (which doesn't take very long) and returns the data.
   **/
  command uint16_t readAdc();
}
