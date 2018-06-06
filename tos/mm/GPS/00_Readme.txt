GPSmonitor - v1 - State Machine

The GPSmonitor is responsible for top level control of the gps subsystem.

Initially this is tightly coupled to the GSD4e chip and reflects its
weirdnesses.


1) Major States

The GPSmonitor has the following major states:

The major mode is determined when the MajorTimer fires.  If we have been
asleep (currently MinorState is MPM), then we will determine the next
MajorState based on current needs.

    (in order of priority)

    IDLE            no major activity selected/in progress.  Choose and
                    start a major cycle.

    CYCLE           take fixes for CYCLE_TIME.  ~30secs which seems to keep
                    MPM happy.

                    After a CYCLE completes, we will put the gps back to sleep
                    ie. MPM.  If MPM fails (mpm_error) then we will try gather
                    more satellite information (MPM_COLLECT).  This might help.

    MPM_COLLECT     Stabilizing MPM.  Collect enough fixes to help MPM
                    stablize.  (~2 mins).

    SATS_COLLECT    collecting almanac/ephemeri so the gps behaves better.
                    during this collection one needs to leave the gps up.
                    we turn off messages we don't want to receive while in
                    this mode to not yank the processor's chain.

                    If we don't have sufficient gps state ie. can't see
                    enough satellites with strong enough signal strength,
                    we sleep in COLLECT_SATS.  We choose a long enough duty
                    cycle to conserve power and wake up once in a while
                    to try again.

                    This is where a decision can be made to give up for a
                    time if sufficient forward progress isn't possible.
                    (looking at satellite Cno signals in the NavTrack
                    message).

    TIME_COLLECT    collecting time fixes, the timing system has a feature
                    (auto-cal), which needs a series of high quality gps
                    time stamps.


2) Minor State machine...

OFF             Boot.booted
                    retry_count = 1
                    -> GMS_BOOTING
                    GPSControl.turnOn

FAIL

BOOTING         GPSControl.gps_booted
                    msg_count   = 0
                    retry_count = 1
                    send(swver)
                    MinorT.startOneShot(SWVER_TO)
                    -> CONFIG

                GPSControl.gps_boot_fail
                    too many tries ... -> FAIL  (retry_count)
                    2nd try:
                        GPSControl.reset
                        GPSControl.turnOn
                    3rd try:
                        GPSControl.powerOff
                        GPSControl.powerOn
                        GPSControl.turnOn

CONFIG          SWVER seen              purpose is to make sure we know the
                                        swver on first boot.

                    major_event(EV_STARTUP)
                        (CYCLE, MajorTimer)
                    MinorT.startOneShot(GPS_MON_COLLECT_DEADMAN)
                    -> COLLECT

                MinorT.fired
                    retrys++
                    too many trys?:  (retry count)
                        give up?
                        /* not seeing msgs, try one more time */
                        pulse
                        MinorT.startOneShot(SWVER_TO)
                        -> CONFIG
                        return
                    if (!msg_count)     not seeing any messages
                        pulse
                    msg_count = 0
                    send(swver)
                    MinorT.startOneShot(SWVER_TO)
                    -> CONFIG

                any msg
                    msg_count++         count any msgs seen.

                ots_no
                    pulse
                    -> CONFIG

COMM_CHECK      any msg
                    if major_state == IDLE
                        retry_count = 1
                        send(mpm)
                        MinorT.startOneShot(MPM_RSP_TIMEOUT)
                        -> MPM_WAIT
                    else
                        MinorTimer.startOneShot(GPS_MON_COLLECT_DEADMAN)
                        -> COLLECT

                MinorT.fired
                    too many trys? (retry_count)
                        -> FAIL

                    retry_count++
                    pulse
                    MinorT.startOneShot(LONG_COMM_TO)

                ots_no
                    pulse
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

will want to start a longer timer for proper duty cycle, want to watch
navTrack to see if we have a reasonable chance. The timer needs to be
set up on entry to COLLECT/CYCLE, etc.

got_lock records current_time - cycle_start if cycle_start != 0

COLLECT         MinorT_timeout          (didn't see any messages, oops)
                    pulse
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                msg
                    MinorT.startOneShot(COLLECT_MSG_DEADMAN)

                ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                got_lock
                    lock_seen = TRUE

                major_changed
                   MinorT.startOneShot(SHORT_COMM_TO)
                   -> COMM_CHECK

MPM_WAIT        mpm_error (not 0010)
                    major_event(mpm_error)
                    MinorT.startOneShot(GPS_MON_MPM_RESTART_WAIT)
                    -> MPM_RESTART

                mpm_good
                    -> GMS_MPM

                MinorT.fired
                    if (retry_count > 5)
                        fail
                        major_event(MON_EV_MPM_ERROR)
                        pulse
                        MinorT.startOneStart(SHORT_COMM_TO)
                        -> COMM_CHECK
                    retry_count++
                    send(mpm)
                    MinorT.startOneShot(MPM_RSP_TIMEOUT)
                    -> MPM_WAIT

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

MPM             got_lock                can happen during NavDataCycles(MPM).
                    ignore

                ots_no
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK

                major_changed
                    cycle_start = current_time
                    lock_seen = False
                    pulse (to wake up)
                    MinorT.startOneShot(SHORT_COMM_TO)
                    -> COMM_CHECK


3) Major state transitions

IDLE            Boot.booted
                    major_state -> IDLE

                EV_STARTUP
                    major_state = CYCLE
                    MajorTimer.startOneShot(CYCLE_TIME)

                MajorTimer.fired
                    MajorTimer.startOneShot(CYCLE_TIME)
                    major_state = CYCLE
                    minor_event(major_changed)

                mpm_error
                    MajorTimer.startOneShot(MPM_COLLECT_TIME)
                    major_state = MPM_COLLECT

CYCLE           MajorTimer.fired
                    MajorTimer.startOneShot(MON_WAKEUP)
                    major_state = IDLE          go to sleep
                    minor_event(major_changed)

MPM_COLLECT     MajorTimer.fired
                    MajorTimer.startOneShot(MON_WAKEUP)
                    major_state = IDLE          go to sleep
                    minor_event(major_changed)
