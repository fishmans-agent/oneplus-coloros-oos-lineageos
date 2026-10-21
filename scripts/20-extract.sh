#!/usr/bin/env bash
# Tasks 3.1 + 3.4: extract the CN and OOS full OTAs and gate on anti-rollback.
# usage: scripts/20-extract.sh <ColorOS_CN_full.zip> <OxygenOS_full.zip>
source "$(dirname "$0")/lib.sh"
cn=${1:?CN zip}; oos=${2:?OOS zip}

meta() { unzip -p "$1" META-INF/com/android/metadata | grep -E '^(post-build|post-sdk-level|post-security-patch-level|version_name)='; }
meta "$cn"  | tee logs/cn-build.txt
meta "$oos" | tee logs/oos-build.txt

val() { sed -n "s/^$1=//p" "$2"; }
cn_sdk=$(val post-sdk-level logs/cn-build.txt);  oos_sdk=$(val post-sdk-level logs/oos-build.txt)
cn_spl=$(val post-security-patch-level logs/cn-build.txt); oos_spl=$(val post-security-patch-level logs/oos-build.txt)
(( oos_sdk >= cn_sdk )) || die "OOS Android ($oos_sdk) older than CN ($cn_sdk): anti-rollback risk"
[[ ! $oos_spl < $cn_spl ]] || die "OOS patch $oos_spl older than CN $cn_spl: anti-rollback risk"
echo "go: OOS sdk $oos_sdk >= $cn_sdk, patch $oos_spl >= $cn_spl"
# LineageOS 24.0 bundles CPH2449 16.0.5.1301 firmware: an older OOS here means a later sideload changes firmware
# versions across slots, and going back to OOS after LineageOS would be a downgrade.
LOS_FW=16.0.5.1301
oos_ver=$(grep -oE '1[0-9]\.[0-9]+\.[0-9]+\.[0-9]+' logs/oos-build.txt | head -1)
[[ -n $oos_ver ]] || die "can't read the OOS version (16.x.y.z) from the zip metadata"
[[ $(printf '%s\n' "$LOS_FW" "$oos_ver" | sort -V | head -1) == "$LOS_FW" ]] ||
  die "OOS $oos_ver is older than $LOS_FW (LineageOS's bundled firmware); get a newer full OTA"
echo "go: OOS $oos_ver >= $LOS_FW"

step "extract"
mkdir -p backup/cn-stock oos
payload-dumper-go -o backup/cn-stock "$cn"
payload-dumper-go -o oos "$oos"
(cd backup/cn-stock && sha256sum -- *.img > SHA256SUMS)
(cd oos && sha256sum -- *.img > SHA256SUMS)
