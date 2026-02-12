#!/bin/sh
#
# ledclock.sh  —  self-looping LED clock with early warning blinks
#
# Copyright (C) 2025 raffe
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# -------------------------------------------------------------------
# Description:
# This script turns your OpenWrt router into a "blinking LED clock."
#                                                                                   
# Every minute (synchronized to either xx:00 or xx:30), it:                         
#   * Gives early-warning blink patterns (at T-25s, T-20s, T-15s, T-10s)
#   * Signals with orange LEDs that it is about to show the time
#   * Blinks the GREEN POWER LED to show the current hour (1...12)
#   * Pauses briefly, then blinks the GREEN WAN LED to show minutes:
#       - Minutes are split into TENS and ONES.
#       - If either digit is 0, it is shown as a single long blink.
#         Example: 23 -> blink 2 times, pause, blink 3 times.
#                  50 -> blink 5 times, pause, LONG blink.
#                  00 -> LONG blink only (no tens/ones).
#   * Signals with orange LEDs again to mark the end of the cycle.
#
# The script runs continuously in an infinite loop, always showing
# the correct time twice every minute.
#
# Requirements:
#   * OpenWrt with working LEDs under /sys/class/leds/
#   * coreutils-sleep (needed for fractional second sleeps)
#
# Installation & Usage:
#   1. Copy this script to /usr/bin/ledclock.sh
#   2. Make it executable:  chmod +x /usr/bin/ledclock.sh
#   3. Run it manually or add to /etc/rc.local for auto-start:
#        /usr/bin/ledclock.sh &
#
# Debugging:
#   * Set DEBUG_IS=ON near the top of this file to enable debug output.
# -------------------------------------------------------------------

# Debug can be ON or OFF
DEBUG_IS=OFF

# New sleep installed from coreutils-sleep. 
# Built in sleep do not work with fractions of second
sleep_bin="/overlay/upper/bin/sleep"

# Check what LEDs you have with ls /sys/class/leds/
LED_GreenPower="/sys/class/leds/green:power/brightness"
LED_GreenWAN="/sys/class/leds/green:wan/brightness"
LED_OrangePower="/sys/class/leds/orange:power/brightness"
LED_OrangeWAN="/sys/class/leds/orange:wan/brightness"

LED_ON=1
LED_OFF=0

blink_veryfast=0.1
blink_fast=0.2
blink_wait_time=0.3
blink_both_wait_time=0.2
blink_to_show_zero=1.2

pause_before_minutes=0.5
pause_avoid_busylooping=0.2
pause_orange=1
pause_very_short=0.05
pause_minutes_between_tens_and_ones=0.8

debug() {
    if [ "$DEBUG_IS" = "ON" ]; then
        echo "$@"
    fi
}

debug "Start!"

set_led() {
    # set_led <led_path> <0|1>
    debug "set_led: $1 = $2"
    echo "$2" > "$1"
}

blink_led() {
    # blink_led <led_path> <duration_seconds> <count>
    local led=$1 duration=$2 count=$3
    debug "blink_led: $led dur=$duration count=$count"
    i=1
    while [ $i -le $count ]; do
        echo $LED_ON > "$led"
        $sleep_bin "$duration"
        echo $LED_OFF > "$led"
        $sleep_bin "$blink_wait_time"
        i=$((i+1))
    done
}

blink_both() {
    # blink both green leds in sync. blink_both <duration_seconds> <count>
    local duration=$1 count=$2
    debug "blink_both: dur=$duration count=$count"
    i=1
    while [ $i -le $count ]; do
        echo $LED_ON > "$LED_GreenPower"
        echo $LED_ON > "$LED_GreenWAN"
        $sleep_bin "$duration"
        echo $LED_OFF > "$LED_GreenPower"
        echo $LED_OFF > "$LED_GreenWAN"
        $sleep_bin "$blink_both_wait_time"
        i=$((i+1))
    done
}

while true; do
    # compute current second (0 to 59)
    SEC=$(( $(date +%s) % 60 ))
    # target second is 30 if now <30, otherwise 0 (next minute)
    if [ $SEC -lt 30 ]; then
        TARGET=30
    else
        TARGET=0
    fi
    # seconds until target (0 to 59)
    WAIT=$(( (TARGET - SEC + 60) % 60 ))

    debug "SEC=$SEC TARGET=$TARGET WAIT=$WAIT"

    # reset early-warning flags for this cycle
    did25=0; did20=0; did15=0; did10=0

    # wait until T-5s but trigger early-warning blinks when threshold passed
    while [ $WAIT -gt 5 ]; do
        # check thresholds (trigger only once each cycle)
        if [ "$WAIT" -le 25 ] && [ "$did25" -eq 0 ]; then
            debug "Early warning: 25s -> 5 fast blinks"
            blink_both "$blink_veryfast" 5
            did25=1
        fi
        if [ "$WAIT" -le 20 ] && [ "$did20" -eq 0 ]; then
            debug "Early warning: 20s -> 4 fast blinks"
            blink_both "$blink_veryfast" 4
            did20=1
        fi
        if [ "$WAIT" -le 15 ] && [ "$did15" -eq 0 ]; then
            debug "Early warning: 15s -> 3 fast blinks"
            blink_both "$blink_veryfast" 3
            did15=1
        fi
        if [ "$WAIT" -le 10 ] && [ "$did10" -eq 0 ]; then
            debug "Early warning: 10s -> 2 fast blinks"
            blink_both "$blink_veryfast" 2
            did10=1
        fi

        # Small sleep to avoid busy-looping
        $sleep_bin $pause_avoid_busylooping

        # recalc current second and WAIT
        SEC=$(( $(date +%s) % 60 ))
        WAIT=$(( (TARGET - SEC + 60) % 60 ))
        # debug line:
        debug "Waiting... SEC=$SEC WAIT=$WAIT"
    done

    # Now we are at T-5s (or within that region).
    blink_both "$blink_veryfast" 1

    # Do A→F sequence to show user time is soon showing:

    # A: Pre-event signal (T-5s). Turn off both green & turn on both orange
    debug "A: Pre-event signal (T-5s). Turn off both green & turn on both orange"
    set_led "$LED_GreenPower" $LED_OFF
    set_led "$LED_OrangePower" $LED_ON
    set_led "$LED_GreenWAN" $LED_OFF
    set_led "$LED_OrangeWAN" $LED_ON

    # B. After a pause time, turn off both orange
    debug "B. After a pause time, turn off both orange"
    $sleep_bin $pause_orange
    set_led "$LED_OrangePower" $LED_OFF
    set_led "$LED_OrangeWAN" $LED_OFF

    # C. After a pause time, turn on both orange again
    debug "C. After a pause time, turn on both orange again"
    $sleep_bin $pause_orange
    set_led "$LED_OrangePower" $LED_ON
    set_led "$LED_OrangeWAN" $LED_ON

    # D: wait until exact target second ($TARGET)
    debug "D: wait until exact target second ($TARGET)"
    # wait until the second equals TARGET (0..59). use epoch%60 for robustness:
    while [ $(( $(date +%s) % 60 )) -ne $TARGET ]; do
        # very short sleeps so we catch target quickly
        $sleep_bin $pause_very_short
    done

    set_led "$LED_OrangePower" $LED_OFF
    set_led "$LED_OrangeWAN" $LED_OFF

    # ---- Time blinks (parallel) ----
    debug "Time blinks"
    HOUR=$(date +%-I)       # Hours 1 to 12
    MIN=$(date +%-M)

    # --- Hours first, shown with LED_GreenPower  ---
    debug "blink_led $LED_GreenPower $blink_fast $HOUR"
    blink_led "$LED_GreenPower" "$blink_fast" "$HOUR"
    set_led "$LED_GreenPower" $LED_OFF

    # Short pause before showing minutes
    $sleep_bin $pause_before_minutes

    # --- Minutes (tens + ones), shown with LED_GreenWAN ---
    TENS=$(( MIN / 10 ))
    ONES=$(( MIN % 10 ))

    debug "Minutes = $MIN  (TENS=$TENS ONES=$ONES)"

    if [ "$TENS" -eq 0 ] && [ "$ONES" -eq 0 ]; then
        # 00 minutes -> single long blink
        debug "Minutes=00 -> long blink"
        echo $LED_ON > "$LED_GreenWAN"
        $sleep_bin $blink_to_show_zero
        echo $LED_OFF > "$LED_GreenWAN"
        $sleep_bin "$blink_wait_time"
    else
        if [ "$TENS" -gt 0 ]; then
            debug "Blink tens ($TENS)"
            blink_led "$LED_GreenWAN" "$blink_fast" "$TENS"
            $sleep_bin $pause_minutes_between_tens_and_ones
        fi

        if [ "$ONES" -gt 0 ]; then
            debug "Blink ones ($ONES)"
            blink_led "$LED_GreenWAN" "$blink_fast" "$ONES"
        else
            # ONES=0 => long blink for the zero
            debug "ONES=0 -> long blink"
            echo $LED_ON > "$LED_GreenWAN"
            $sleep_bin $blink_to_show_zero
            echo $LED_OFF > "$LED_GreenWAN"
            $sleep_bin "$blink_wait_time"
        fi
    fi

    set_led "$LED_GreenWAN" $LED_OFF

    # E and F Show with orange LEDs that we are done showing time
    debug "E: after-event (turn orange on)"
    set_led "$LED_OrangePower" $LED_ON
    set_led "$LED_OrangeWAN" $LED_ON
    $sleep_bin $pause_orange

    debug "F: turn orange off"
    set_led "$LED_OrangePower" $LED_OFF
    set_led "$LED_OrangeWAN" $LED_OFF

    debug "Cycle complete — restarting loop"
done

