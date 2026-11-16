#!/bin/bash
# client.sh <cmd>: a tester's machine. User installs go to /c/user, system
# installs (run as root, like `sudo flatpak install`) to /c/system.
set -uo pipefail
export LC_ALL=C.UTF-8 FLATPAK_USER_DIR=/c/user FLATPAK_SYSTEM_DIR=/c/system
PR=7 APP=org.flatpark.TestApp
REF_URL=http://127.0.0.1:18767/pr/$PR/$APP.flatpakref
applied() { cat "$(flatpak "$1" info --show-location $APP)/files/extra/applied.txt"; }
case "$1" in
user-install)   flatpak --user install -y --noninteractive "$REF_URL" && applied --user ;;
system-install) flatpak --system install -y --noninteractive "$REF_URL" && applied --system ;;
run)            flatpak --user info $APP >/dev/null && cat "$(flatpak --user info --show-location $APP)/files/bin/hello" | tail -1 ;;
remote-ls)      flatpak --user remote-ls --all --columns=ref flatpark-pr$PR | sort | tr '\n' ' ' ;;
update)         flatpak --user update -y --noninteractive 2>&1 ;;
# On a wide terminal: off one, flatpak cuts the End-of-life line at 80 columns.
remote-info)    script -qec "stty cols 1000; flatpak --user remote-info flatpark-pr$PR $APP" /dev/null 2>&1 | tr -d '\r' ;;
system-update)  flatpak --system update -y --noninteractive 2>&1 ;;
esac
