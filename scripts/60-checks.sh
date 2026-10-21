#!/usr/bin/env bash
# Post-boot checks on OxygenOS or LineageOS. LineageOS: enable Developer options -> Rooted debugging first.
source "$(dirname "$0")/lib.sh"
set +e   # read-only diagnostics: keep going past individual failures
adb root >/dev/null 2>&1; adb wait-for-device
dev() { adb shell "$@" | tr -d '\r'; }
if [[ $(dev id) == *"uid=0"* ]]; then R=(adb shell)
elif [[ $(adb shell -T su -c id 2>/dev/null) == *"uid=0"* ]]; then R=(adb shell -T su -c)
else die "no root: enable Developer options -> Rooted debugging (LineageOS) or grant su (OxygenOS)"; fi

echo "build:    $(dev getprop ro.build.display.id)  lineage=$(dev getprop ro.lineage.version)"
echo "slot:     $(dev getprop ro.boot.slot_suffix)"
echo "baseband: $(dev getprop gsm.version.baseband)"
echo "qsf_init crashes this boot: $("${R[@]}" "dmesg | grep -c 'qsf_init failed'" | tr -d '\r')   (must be 0)"
for s in a b; do
  have=$("${R[@]}" "sha256sum /dev/block/by-name/oplusstanvbk_$s" | awk '{print $1}')
  want=$(sha256sum "backup/device/oplusstanvbk_$s.img" | awk '{print $1}')
  [[ $have == "$want" ]] && echo "oplusstanvbk_$s: CN (ok)" || echo "oplusstanvbk_$s: CHANGED -> scripts/45-restore-stanvbk.sh"
done
echo "Now dial *#06# and compare with logs/imei-before.txt; place a call, send an SMS, use mobile data."
