# Android OEM Background Keep-Alive & Anti-Kill Guide

> **Goal**: Prevent aggressive Android OEM battery managers from killing Termux background SSH sessions, ensuring uninterrupted AI agent monitoring and long-running execution.

---

## 1. Universal Keep-Alive Foundation

Before adjusting OEM-specific settings, ensure the core Termux wake lock is active:

### 1.1 Termux Native Wake Lock
Acquire a partial CPU wake lock directly from the terminal:
```bash
termux-wake-lock
```
- This prevents the CPU from going into deep sleep when the screen turns off.
- An active notification **"Termux (wake lock held)"** will appear in the Android notification shade.
- To release when done: `termux-wake-unlock`.
- *(Note: `herdr-remote` automatically manages this wake lock during execution).*

### 1.2 Android Battery Optimization Whitelist
1. Open Android **Settings** -> **Apps** -> **Special App Access** -> **Battery Optimization** (or search "Battery Optimization").
2. Switch dropdown filter from *Not Optimized* to **All Apps**.
3. Locate **Termux** and **Tailscale**.
4. Set both to **Don't Optimize** / **Unrestricted**.

---

## 2. OEM-Specific Settings Matrix

Android OEMs implement proprietary background task killers. Follow the steps corresponding to your device:

---

### A. Xiaomi / Redmi (HyperOS / MIUI)

1. **Battery Saver Settings**:
   - Long press the Termux app icon -> **App Info** (`ⓘ`).
   - Scroll down to **Battery Saver**.
   - Change from *MIUI Battery Saver (recommended)* to **No restrictions**.
2. **Autostart & Background Launch**:
   - In App Info, enable **Autostart**.
   - Enable **Display pop-up windows while running in the background**.
3. **Recent Task Lock**:
   - Open Android Recent Apps view (swipe up and hold).
   - Long-press the Termux preview card and tap the **Padlock icon (🔒)**.
4. **Game Space / Security App Whitelist**:
   - In the **Security** app -> **Speed Boost** -> **Lock apps** -> toggle **Termux** ON.

---

### B. vivo / iQOO (OriginOS / FuntouchOS)

1. **Background Power Management**:
   - Settings -> **Battery** -> **Background power consumption management**.
   - Locate **Termux** and select **High background power usage** (允许高耗电后台运行).
2. **Auto-Start Management**:
   - Settings -> **Apps & Permissions** -> **Permission management** -> **Auto-start**.
   - Toggle **Termux** and **Tailscale** to ON.
3. **Task Card Locking**:
   - Open Recent Apps switcher.
   - Pull down on the Termux app card until a lock icon appears at the top right.

---

### C. OPPO / OnePlus / Realme (ColorOS / OxygenOS / RealmeUI)

1. **Battery Management**:
   - Long press Termux icon -> **App Info** -> **Battery Usage**.
   - Enable **Allow background activity** and **Allow auto-launch**.
   - Disable **Optimized battery use** (select *Don't optimize*).
2. **App Freezer / Sleep Policy**:
   - Settings -> **Battery** -> **More settings** -> **App Freezer**.
   - Ensure **Termux** is excluded from auto-freezing.
3. **Recent Task Lock**:
   - Open Recent Apps, tap the three dots (`⋮`) on the Termux card header, and tap **Lock**.

---

### D. Samsung Galaxy (OneUI)

1. **Unrestricted Battery**:
   - Settings -> **Apps** -> **Termux** -> **Battery** -> select **Unrestricted**.
2. **Never Sleeping Apps**:
   - Settings -> **Battery and device care** -> **Battery** -> **Background usage limits**.
   - Tap **Never sleeping apps** -> Tap `+` -> Add **Termux** and **Tailscale**.
3. **Memory Exclusion**:
   - Settings -> **Battery and device care** -> **Memory** -> **Excluded apps** -> Add **Termux**.
4. **Recent Apps Lock**:
   - In Recent Apps screen, tap the Termux app icon at top of card -> select **Lock this app**.

---

## 3. Android 12+ Phantom Process Killer Mitigation

Android 12 introduced a strict limit of 32 child processes per app (`PhantomProcessKiller`). If Herdr, Tmux, Git, and subshells spawn numerous subprocesses, Android may silently kill the Termux daemon.

### Fix via Wireless Debugging / Shizuku / ADB (Zero-Root)

If you have ADB access (or use [Shizuku](https://shizuku.rikka.app/) / Termux-ADB):

```bash
# Disable phantom process monitoring
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"

# Or on Android 12L / 13+ / 14:
adb shell setprop persist.sys.fflag.override.settings_enable_monitor_phantom_procs false
```

### Verification inside Termux
Check if phantom process limit is relaxed:
```bash
/system/bin/device_config get activity_manager max_phantom_processes
# Should return 2147483647 or disabled
```

---

## 4. Verification & Testing

To verify that your background keep-alive setup is working properly:

1. Connect to your workstation:
   ```bash
   herdr-remote
   ```
2. Turn off the mobile phone screen and leave it locked for 10–15 minutes.
3. Turn on the screen and check the connection.
   - **Success**: Terminal is responsive immediately without reconnection banners.
   - **Failure**: SSH disconnected with *broken pipe* or Termux process was restarted.
