#!/usr/bin/env bash
# UI-lag diagnostics for LineageOS (read-only). Run while reproducing the lag; output -> logs/perf-*.txt.
# Rooted debugging needed for thermal/cpufreq reads.
source "$(dirname "$0")/lib.sh"
set +e   # read-only diagnostics: an empty grep must not abort the report
adb root >/dev/null 2>&1; adb wait-for-device
out=logs/perf-$(date +%Y%m%d-%H%M%S).txt
{
  echo "## build";        adb shell 'getprop ro.lineage.version; getprop ro.build.date; getprop | grep -E "ro.vendor.perf"'
  echo "## refresh rate"; adb shell 'settings get system peak_refresh_rate; settings get system min_refresh_rate'
  adb shell dumpsys SurfaceFlinger | grep -iE 'refresh-rate|activeMode|fps' | head -20
  echo "## jank (launcher)"; adb shell dumpsys gfxinfo com.android.launcher3 | grep -iE 'janky|percentile|Total frames'
  echo "## thermal";      adb shell 'for t in /sys/class/thermal/thermal_zone*; do echo "$(cat $t/type) $(cat $t/temp)"; done' | sort -k2 -n | tail -8
  echo "## cpufreq";      adb shell 'for p in /sys/devices/system/cpu/cpufreq/policy*; do echo "$p $(cat $p/scaling_cur_freq) $(cat $p/scaling_max_freq) $(cat $p/scaling_governor)"; done'
  echo "## perf config";  adb shell 'ls /vendor/etc/perf/ 2>&1; grep -o "ro.vendor.perf.ss[^/]*" /vendor/etc/perf/perfconfigstore.xml 2>/dev/null'
  echo "## apps not yet compiled (verify-only)"; adb shell 'dumpsys package dexopt | grep -c "status=verify"'
  # Driver-level signs: failed firmware loads, GPU stuck at low clock, GPU (client) composition instead of HWC overlays.
  echo "## firmware load failures"; adb shell 'dmesg | grep -iE "firmware.*(fail|error)|zap|gmu.*(fail|err)|kgsl.*(fail|err)|subsys.*crash" | grep -vE "Direct firmware load|sysfs fallback|found .* for" | tail -20'
  echo "## gpu";          adb shell 'cd /sys/class/kgsl/kgsl-3d0 && echo "cur=$(cat devfreq/cur_freq) max=$(cat devfreq/max_freq) busy=$(cat gpu_busy_percentage) thermal_pwrlevel=$(cat thermal_pwrlevel)"'
  echo "## composition (CLIENT on most layers = display HAL not doing overlays)"; adb shell dumpsys SurfaceFlinger | grep -cE '\| *CLIENT'; adb shell dumpsys SurfaceFlinger | grep -cE '\| *DEVICE'
  echo "## display/gpu HAL";  adb shell 'getprop | grep -iE "hwcomposer|vendor.gralloc|ro.hardware.(egl|vulkan)|debug.sf.(hw|enable)"'
} 2>&1 | tr -d '\r' | tee "$out"
cat <<EOF
Saved $out. Things to try, in order:
  1. Nightly older than ~2026-09-28 lacks the perf-HAL boost fix: update via Settings > System > Updater.
  2. Settings > Display > Smooth display / peak refresh 120 Hz.
  3. Right after install/update: adb shell cmd package bg-dexopt-job, then leave it charging and idle.
  4. Hot (> 45000 in thermal list) during lag = throttling, not software.
EOF
