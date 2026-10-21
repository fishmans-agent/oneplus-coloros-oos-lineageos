#!/usr/bin/env bash
# Are the graphics/display drivers and vendor HALs actually working? Read-only.
# Most checks need no root; dmesg/tombstones need Developer options -> Rooted debugging.
source "$(dirname "$0")/lib.sh"
set +e
adb root >/dev/null 2>&1; adb wait-for-device
out=logs/drivers-$(date +%Y%m%d-%H%M%S).txt
{
  echo "## GPU driver in use (expect: Qualcomm, Adreno (TM) 740; 'SwiftShader'/'llvmpipe' = software rendering)"
  adb shell dumpsys SurfaceFlinger | grep -iE '^GLES:|vulkan' | head -3
  adb shell 'getprop ro.hardware.egl; getprop ro.hardware.vulkan; cat /sys/class/kgsl/kgsl-3d0/gpu_model 2>/dev/null; ls -l /dev/kgsl-3d0'
  echo "## display modes (expect 60 and 120 Hz listed)"
  adb shell dumpsys display | grep -oE 'fps=[0-9.]+' | sort -u
  echo "## composer HAL registered"
  adb shell service list | grep -iE 'composer|allocator|mapper'
  echo "## layers composed by display hardware (DEVICE) vs GPU (CLIENT)"
  echo "DEVICE=$(adb shell dumpsys SurfaceFlinger | grep -cE '\| *DEVICE') CLIENT=$(adb shell dumpsys SurfaceFlinger | grep -cE '\| *CLIENT')"
  echo "## vendor HAL / native crashes this boot"
  adb logcat -b crash -d | grep -E 'Process:|Cmdline:|signal' | tail -20
  adb shell 'ls -t /data/tombstones 2>/dev/null | head -5'
  echo "## kernel driver/firmware errors (root)"
  adb shell 'dmesg | grep -iE "kgsl|adreno|gmu|zap|msm_drm|sde|dsi" | grep -iE "fail|err|timeout|fault|hang" | tail -20'
} 2>&1 | tr -d '\r' | tee "$out"
echo "Saved $out"
