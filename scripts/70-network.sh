#!/usr/bin/env bash
# Captive-portal probes and NTP that work both in mainland China and abroad (no root needed).
# Google's default probes are blocked in China: "no internet" mark, Wi-Fi falls back to mobile data.
# Probes: Huawei hicloud (primary) + Xiaomi miui (fallback). Both answer 204 over HTTP and HTTPS and are served in
# China and abroad.
# Last-resort fallback: Cloudflare (blocked in China, fine abroad; only tried when the probes above fail).
# Keys from AOSP NetworkStackUtils.java / NtpTrustedTime.java. Survive OTA; wiped by factory reset.
source "$(dirname "$0")/lib.sh"
adb wait-for-device
# Value is single-quoted for the device shell: adb joins args, so a bare '|' would become a pipe on the phone.
set_g() { adb shell "settings put global $1 '$2'"; printf '%-36s %s\n' "$1" "$(adb shell settings get global "$1" | tr -d '\r')"; }
set_g captive_portal_mode 1
set_g captive_portal_http_url  http://connectivitycheck.platform.hicloud.com/generate_204
set_g captive_portal_https_url https://connectivitycheck.platform.hicloud.com/generate_204
set_g captive_portal_fallback_url http://connect.rom.miui.com/generate_204
set_g captive_portal_other_fallback_urls http://cp.cloudflare.com/generate_204
# '|' separates servers (NtpTrustedTime). aliyun for China, pool.ntp.org abroad.
set_g ntp_server 'ntp.aliyun.com|pool.ntp.org'
echo "Toggle Wi-Fi off/on; the exclamation mark should go away. Check: adb shell dumpsys connectivity | grep -c VALIDATED"
