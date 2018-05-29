GPSmonitor

The GPSmonitor is responsible for top level control of the gps subsystem.

Initially this is tightly coupled to the GSD4e chip and reflects its
weirdnesses.

* OFF             Boot.booted
*                    -> GMS_BOOTING
*                    GPSControl.turnOn
*
* FAIL
*
* BOOTING         GPSControl.gps_booted
*                    -> GMS_STARTUP
*                    send(swver)
*                    Timer.startOneShot(SWVER_TO)
*
*                GPSControl.gps_boot_fail
*                    too many tries ... -> FAIL
*                    2nd try:
*                        GPSControl.reset
*                        GPSControl.turnOn
*                    3rd try:
*                        GPSControl.powerOff
*                        GPSControl.powerOn
*                        GPSControl.turnOn
*
* STARTUP         SWVER seen             purpose is to make sure we know the swver on first boot.
*                    Timer.stop()
*                    -> LOCK_WAIT
*                                        will want to start a longer timer for proper duty cyle
*                                        want to watch navTrack to see if we have a reasonable chance
*                                        Timer needs to be set up on entry to LOCK_WAIT
*
*                Timer.fired
*                    too many trys?:
*                        start Timer for comm check, should be receiving messages.
*                        -> COMM_CHECK
*                    trys++
*                        send(swver)
*                        Timer.startOneShot(SWVER_TO)

* COMM_CHECK      any msg
*                    stop Timer
*                    -> LOCK_WAIT
*
*                Timer.fired
*                    too many trys?
*                    ?
*
*                    pulse
*                    Timer.startOneShot(LONG_COMM_TO)
*
* COLLECT_FIXES   Timer.fired
*                    -> LOCK_WAIT
*
* LOCK_WAIT       got_lock
*                    send(mpm)
*                    Timer.startOneShot(MPM_WAIT_TIMEOUT)
*                    -> MPM_WAIT
*
* MPM_WAIT        mpm_error (not 0010)
*                    Timer.startOneShot(MPM_RESTART_WAIT)
*                    -> MPM_RESTART
*
*                mpm_good
*                    -> GMS_MPM
*                    Timer.startOneShot(next_wakeup)
*                Timer.fired
*                    Timer.startOneShot(COMM_SHORT_TO)
*                    pulse (to wake up)
*                    -> COMM_CHECK
*
*MPM_RESTART     ok_to_send_not
*                    Timer.startOneShot(COMM_SHORT_TO)
*                    pulse (to wake up)
*                     -> COMM_CHECK
*                Timer.fired
*                    Timer.startOneShot(COMM_SHORT_TO)
*                    pulse (to wake up)
*                    -> COMM_CHECK
*
* MPM             Timer.fired
*                    pulse to wake up
*                    Timer.startOneShot(COMM_CHECK_TIMEOUT)
*                    -> COMM_CHECK
*                  got_lock              can happen during NavDataCycles(MPM).
*                      ignore
