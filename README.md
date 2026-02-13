# LED Clock

A tiny shell script that turns LEDs on an OpenWrt (or other) device into a “blinking clock” — handy when you don’t want to grab your phone.

This project was originally built for a **D-Link DIR-810L** running **OpenWrt**, using its **Power** and **WAN** LEDs (green/orange).  
It should be adaptable to other OpenWrt routers and Linux devices that expose LEDs via `/sys/class/leds/` or similar.

## What it does

The script runs in an infinite loop and shows the time **twice per minute** (synchronized to **xx:00** and **xx:30**).

Each cycle:

1. **Early warning** blink patterns at **T-25s, T-20s, T-15s, T-10s**
2. Turns **orange LEDs on** briefly to signal “time is about to be shown”
3. Blinks **GREEN Power LED** to show **hours (1–12)**
4. Pauses, then blinks **GREEN WAN LED** to show **minutes**
   - Minutes are split into **tens** and **ones**
   - A digit of **0** is shown as a **single long blink**
   - Examples:
     - `23` → blink 2 times, pause, blink 3 times
     - `50` → blink 5 times, pause, LONG blink
     - `00` → LONG blink only (no tens/ones)
5. Turns **orange LEDs on** briefly again to signal end of cycle

## Requirements

- OpenWrt (or Linux) with LEDs available under:
  - `/sys/class/leds/`
- A `sleep` command that supports fractional seconds.
  - On OpenWrt, install **coreutils-sleep**.

### Install coreutils-sleep (OpenWrt)

```sh
opkg update
opkg install coreutils-sleep
```

## Files

- `scripts/ledclock.sh` — the LED clock script
- `CHANGELOG.md`, `VERSION`, `LICENSE`

## Installation (OpenWrt)

1. **Get the script onto your computer**
   - Download/copy `scripts/ledclock.sh` from this repo.
2. **Copy it to the router**
   - Use SCP/WinSCP, or paste via SSH.
3. **Install it**
   ```sh
   cp scripts/ledclock.sh /usr/bin/ledclock.sh
   chmod +x /usr/bin/ledclock.sh
   ```
4. **Run it**
   ```sh
   /usr/bin/ledclock.sh
   ```

### Run in background

```sh
/usr/bin/ledclock.sh &
```

### Auto-start on boot (simple method)

Add this line to `/etc/rc.local` (before `exit 0`):

```sh
/usr/bin/ledclock.sh &
```

Reboot to test.

## Configuration

Open `scripts/ledclock.sh` and adjust these variables for your device.

### 1) `sleep_bin`

The script uses a `sleep` binary that supports fractional seconds.

Default in the script:

```sh
sleep_bin="/overlay/upper/bin/sleep"
```

On many systems you can use plain `sleep`:

```sh
sleep_bin="sleep"
```

On OpenWrt with coreutils-sleep, the correct path may vary. Find it with:

```sh
which sleep
```

### 2) LED paths

List your LED names:

```sh
ls /sys/class/leds/
```

Then set these paths in the script to match what your device exposes:

```sh
LED_GreenPower="/sys/class/leds/green:power/brightness"
LED_GreenWAN="/sys/class/leds/green:wan/brightness"
LED_OrangePower="/sys/class/leds/orange:power/brightness"
LED_OrangeWAN="/sys/class/leds/orange:wan/brightness"
```

Some devices use different names (e.g. `router:green:power`, `system:green:status`, etc.).

Quick LED test:

```sh
echo 1 > /sys/class/leds/<your-led>/brightness
sleep 1
echo 0 > /sys/class/leds/<your-led>/brightness
```

## Debugging

Enable debug prints by changing near the top of `scripts/ledclock.sh`:

```sh
DEBUG_IS=ON
```

## Notes / limitations

- The script assumes it can write to LED brightness files (run as root on OpenWrt).
- Timing is “good enough” for human reading; it synchronizes to the next `:00` or `:30` based on epoch seconds.
- Your device must have at least **two LEDs** you can control for best readability (hours + minutes). If you only have one LED, you need to edit the code.

## License

GPL-3.0-or-later

