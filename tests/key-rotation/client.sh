#!/bin/bash
# client.sh <id> <user|system> <cmd> [arg]
set -uo pipefail
id=$1 mode=$2 cmd=$3 arg=${4:-}; export LC_ALL=C.UTF-8
if [ "$mode" = system ]; then export FLATPAK_SYSTEM_DIR=/c/$id; inst=--system; d=/c/$id; else export FLATPAK_USER_DIR=/c/$id; inst=--user; d=/c/$id; fi
case "$cmd" in
add)     flatpak $inst remote-add --gpg-import=/srv/pub/$arg fp http://127.0.0.1:18765/ ;;
install) flatpak $inst install -y --noninteractive fp org.test.Hello ;;
update)  flatpak $inst update -y --noninteractive ;;
update-silent) out=$(flatpak $inst update -y --noninteractive 2>&1); rc=$?; echo "$out"; [ $rc -eq 0 ] && echo "$out" | grep -q "non-fatal" ;;
ls)      flatpak $inst remote-ls fp ;;
fix)     flatpak $inst remote-modify --gpg-import=/srv/pub/$arg fp ;;
version) cat "$(flatpak $inst info --show-location org.test.Hello)/files/bin/hello" | sed -n 's/^echo //p' ;;
keys)    gpg --show-keys --with-colons $d/repo/fp.trustedkeys.gpg 2>/dev/null | awk -F: '/^uid/{print $10}' | sed -E 's/ <.*//; s/FlatPark Repository Signing Key //' | sort | tr '\n' ',' ;;
esac
