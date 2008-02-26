
interface Pwr {
  /**
   * Request access to a shared pwr resource. You must call release()
   * when you are done with it.
   *
   * @return SUCCESS When a request has been accepted. The granted()
   *                 event will be signaled once you have control of the
   *                 resource.<br>
   *         EBUSY You have already requested this resource and a
   *               granted event is pending
   */
  command error_t request();

  /**
  * Request immediate access to a shared pwr resource. You must call release()
  * when you are done with it.
  *
  * @return SUCCESS When a request has been accepted. <br>
  *            FAIL The request cannot be fulfilled
  */
//  command error_t immediateRequest();

  /**
   * You are now in control of the resource.
   */
  event void granted();
   
  /**
  * Release a shared resource you previously acquired.  
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
}
