#!/usr/bin/env bash
# Task 3.3: dump every partition except userdata/super straight off the rooted, booted phone.
# Rerunnable: complete dumps are skipped, partial ones redone. Fails on any truncated or missing critical dump.
source "$(dirname "$0")/lib.sh"
mkdir -p backup/device

[[ $(adb shell -T su -c id) == *"uid=0"* ]] || die "adb shell has no root (grant it in Magisk/KernelSU)"
adb shell -T su -c 'ls -1 /dev/block/by-name' | tr -d '\r' > logs/partitions.txt

bad=()
while read -r p; do
  case $p in userdata|super|sd[a-z]|sd[a-z][0-9]*|'') continue ;; esac
  out="backup/device/$p.img"
  want=$(adb shell -T su -c "blockdev --getsize64 /dev/block/by-name/$p" </dev/null | tr -d '\r')
  [[ $want =~ ^[0-9]+$ ]] || want=""
  if [[ -s $out && -n $want && $(stat -c %s "$out") == "$want" ]]; then echo "skip $p (complete)"; continue; fi
  echo ">> $p (${want:-unknown} bytes)"
  # exec-out is binary-clean; plain adb shell would turn \n into \r\n.
  adb exec-out "su -c 'dd if=/dev/block/by-name/$p bs=4M 2>/dev/null'" </dev/null > "$out"
  [[ -z $want || $(stat -c %s "$out") == "$want" ]] || { echo "SIZE MISMATCH: $p"; bad+=("$p"); }
done < logs/partitions.txt

(cd backup/device && sha256sum -- *.img > SHA256SUMS)
for p in persist modemst1 modemst2 fsg fsc oplusstanvbk_a oplusstanvbk_b ocdt modem_a; do
  [[ -s backup/device/$p.img ]] || bad+=("missing:$p")
done
((${#bad[@]} == 0)) || die "rerun the script; bad dumps: ${bad[*]}"
echo "OK. Copy backup/ to a second disk now. oplusstanvbk_a/_b are irreplaceable (see README, 4.3)."
