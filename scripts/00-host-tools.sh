#!/usr/bin/env bash
# Download platform-tools (adb, fastboot) and payload-dumper-go into tools/ (gitignored).
source "$(dirname "$0")/lib.sh"
mkdir -p tools

step "platform-tools"
curl -fsSL -o tools/pt.zip https://dl.google.com/android/repository/platform-tools-latest-linux.zip
unzip -qo tools/pt.zip -d tools && rm tools/pt.zip

step "payload-dumper-go"
url=$(curl -fsSL https://api.github.com/repos/ssut/payload-dumper-go/releases/latest |
  jq -r '.assets[].browser_download_url | select(endswith("linux_amd64.tar.gz"))')
curl -fsSL "$url" | tar xz -C tools payload-dumper-go

fastboot --version | head -1   # need >= 35
adb --version | head -1
payload-dumper-go -h 2>&1 | head -1
