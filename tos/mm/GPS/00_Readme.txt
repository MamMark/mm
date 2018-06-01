GPSmonitor

The GPSmonitor is responsible for top level control of the gps subsystem.

Initially this is tightly coupled to the GSD4e chip and reflects its
weirdnesses.


1) Major States

Major States are invoked from LOCK_SEARCH.  What we are trying to accomplish
determines what major state we are using and what we do next from the
LOCK_SEARCH/ev_lock_* event.

The GPSmonitor has the following major states:

    (in order of priority)

    CYCLE           simple search for lock, take the fix, and return to MPM.
                    take fixes for about 30 secs.  this seems to keep mpm
                    happy.

    MPM_COLLECT     Stabilizing MPM.  Collect enough fixes to help MPM
                    stablize.  (2 mins).

    SATS_COLLECT    collecting almanac/ephemeri so the gps behaves better.
                    during this collection one needs to leave the gps up.
                    we turn off messages we don't want to receive while in
                    this mode to not yank the processors chain.

                    If we don't have sufficient gps state ie. can't see
                    enough satellites with strong enough signal strength,
                    we hang in COLLECT_SATS.

                    This is where a decision can be made to give up for a
                    time if sufficient forward progress isn't possible.
                    (looking at satellite Cno signals in the NavTrack
                    message).

    TIME_COLLECT    collecting time fixes, the timing system has a feature
                    (auto-cal), which needs a series of high quality gps
                    time stamps.


2) Minor State machine...

OFF             Boot.booted
                    -> GMS_BOOTING
                    GPSControl.turnOn

FAIL

BOOTING         GPSControl.gps_booted
                    -> GMS_STARTUP
                    send(swver)
                    MinorT.startOneShot(SWVER_TO)

                GPSControl.gps_boot_fail
                    too many tries ... -> FAIL
                    2nd try:
                        GPSControl.reset
                        GPSControl.turnOn
                    3rd try:
                        GPSControl.powerOff
                        GPSControl.powerOn
                        GPSControl.turnOn

STARTUP         SWVER seen              purpose is to make sure we know the
                                        swver on first boot.

                    MinorT.stop
                    -> LOCK_SEARCH

                MinorT.fired
                    too many trys?:
                        pulse
                        MinorT.startOneShot(SHORT_COMM_TO)
                        -> COMM_CHECK
                    trys++
                        send(swver)
                        MinorT.startOneShot(SWVER_TO)

                ots_no
                    comm_check_next_state = STARTUP
                    pulse
                    MinorT.startOneShot(SHORT_COMM_TO)

COMM_CHECK      any msg
                    MinorT.stop()
                    -> LOCK_SEARCH

                MinorT.fired
                    too many trys?
                        -> FAIL

                    pulse
                    MinorT.startOneShot(LONG_COMM_TO)

                ots_no
                    can't happen.  first we will see msg which will
                    transition us into LOCK_SEARCH.  LOCK_SEARCH will
                    see the ots_no and transition back to COMM_CHECK.


will want to start a longer timer for proper duty cycle, want to watch
navTrack to see if we have a reasonable chance Timer needs to be
set up on entry to LOCK_SEARCH.

got_lock records current_time - cycle_start if cycle_start != 0

LOCK_SEARCH     got_lock
                    major_state:
                        CYCLE
                            send(mpm)
                            MinorT.startOneShot(MPM_TIMEOUT)
                            -> MPM_WAIT

                        MPM_COLLECT
                            MajorT.startOneShot(MPM_COLLECT_TIME)
                            -> COLLECT

                ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK


 MPM_WAIT       mpm_error (not 0010)
                    major_state = MPM_COLLECT
                    MinorT.startOneShot(GPS_MON_MPM_RESTART_WAIT)
                    -> MPM_RESTART

                mpm_good
                    -> GMS_MPM
                    MinorT.startOneShot(next_wakeup)

                MinorT.fired
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

MPM_RESTART     ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                     -> COMM_CHECK

                MinorT.fired
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

MPM             Timer.fired             start of a cycle.
                    cycle_start = current_time
                    pulse
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                got_lock                can happen during NavDataCycles(MPM).
                    ignore

                ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

COLLECT         MinorT.fired
                    major_state:
                        CYCLE
                        MPM_COLLECT
                            major_state = CYCLE
                    MinorT.start(SHORT_COMM_TO)
                    -> COMM_CHECK

                ots_no
                    comm_check_next_state = COLLECT
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                got_lock                do we need to check things?
