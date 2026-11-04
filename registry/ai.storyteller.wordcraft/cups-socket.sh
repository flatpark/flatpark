#!/bin/sh
# Runs lp, lpstat or lpoptions. Flatpak mounts the host CUPS socket at
# /var/run/cups/cups.sock, choosing it as flatpak-run-cups.c does from the
# host's CUPS_SERVER, else the first line spelled exactly `ServerName /path`
# in ~/.cups/client.conf, else the default. CUPS itself reads the keyword in
# any case and takes the last ServerName. When that socket is the one Flatpak
# mounted, point the tool at the mount. When it is a different socket, fail
# rather than talk to another server. An explicit CUPS_SERVER is left alone:
# one passed to `flatpak run --env` may not be the socket that was mounted.
conf="$HOME/.cups/client.conf"
if [ -z "${CUPS_SERVER:-}" ] && [ -r "$conf" ]; then
  server=$(sed -n 's/^[[:space:]]*[Ss][Ee][Rr][Vv][Ee][Rr][Nn][Aa][Mm][Ee][[:space:]]\{1,\}\([^[:space:]]*\).*/\1/p' "$conf" | tail -n 1)
  case "$server" in
  /*)
    mounted=$(sed -n 's/^[[:space:]]*ServerName \(.*\)$/\1/p' "$conf" | sed 's/^[[:space:]]*//' | grep -m 1 '^/[^:]*$')
    if [ "$mounted" = "$server" ]; then
      export CUPS_SERVER=/var/run/cups/cups.sock
    else
      echo "${0##*/}: ~/.cups/client.conf names the CUPS socket $server, but Flatpak gave this app ${mounted:-a different one}; give each socket one ServerName line, spelled ServerName" >&2
      exit 1
    fi
    ;;
  esac
fi
exec "/app/libexec/cups/${0##*/}" "$@"
