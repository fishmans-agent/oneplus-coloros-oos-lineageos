#!/usr/bin/env bash
# Phase 4.3 / 4.5 firmware half: flash every slotted physical partition from oos/ to both slots.
# Keeps: oplusstanvbk (must stay CN, else the modem crash-loops), modem (the phone's own CN modem works),
# recovery (LineageOS recovery keeps a working fastbootd).
# Run in LineageOS-recovery fastbootd (proven: ~62 writes; flash lineage/recovery.img from the bootloader first)
# or in the bootloader (4.3; modem is refused there, which is fine).
source "$(dirname "$0")/lib.sh"
[[ -d oos ]] || die "oos/ missing; run scripts/20-extract.sh"
slots=" $(slotted | xargs) "

for img in oos/*.img; do
  p=$(basename "$img" .img)
  [[ " $LOGICAL " == *" $p "* ]] && continue
  [[ $slots == *" $p "* ]] || { echo "SKIP $p (no _a/_b on this phone)"; continue; }
  case $p in oplusstanvbk|modem|recovery) echo "KEEP $p"; continue ;; esac
  echo "fastboot flash --slot=all $p $img"
done | tee logs/oos-firmware-plan.txt
grep -q '^SKIP' logs/oos-firmware-plan.txt && echo "note: SKIP lines above are expected only for unslotted images"
confirm "Flash the plan above?"

: > logs/oos-firmware.log
while read -r cmd; do
  $cmd 2>&1 | tee -a logs/oos-firmware.log
  [[ ${PIPESTATUS[0]} == 0 ]] || die "'$cmd' failed; don't reboot to Android, fix and rerun"
done < <(grep '^fastboot' logs/oos-firmware-plan.txt)
echo "firmware OK: $(grep -c 'Writing.*OKAY' logs/oos-firmware.log) writes"

# A LineageOS sideload writes its bundled OOS modem to the slot it installs to; put the phone's own back on both.
fastboot flash --slot=all modem backup/device/modem_a.img 2>&1 | tee logs/oos-modem.log ||
  echo "modem refused here (bootloader/stock fastbootd do that); fine unless a LineageOS sideload replaced it"
