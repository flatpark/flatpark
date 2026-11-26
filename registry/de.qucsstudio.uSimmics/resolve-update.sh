#!/usr/bin/env bash
set -euo pipefail
html="$(curl -fsSL --retry 3 https://qucsstudio.de/download/)"
result="$(python3 -c '
import html.parser, json, re, sys
class Links(html.parser.HTMLParser):
    def __init__(self):
        super().__init__(); self.href = None; self.text = ""; self.matches = []
    def handle_starttag(self, tag, attrs):
        if tag == "a": self.href = dict(attrs).get("href"); self.text = ""
    def handle_data(self, data):
        if self.href: self.text += data
    def handle_endtag(self, tag):
        if tag == "a" and self.href:
            m = re.fullmatch(r"uSimmics-([0-9]+(?:\.[0-9]+)+)\.zip", self.text.strip(), re.I)
            if m and re.fullmatch(r"https://dd6um\.darc\.de/QucsStudio/uSimmics-[A-Za-z0-9.]+\.zip", self.href): self.matches.append((m.group(1), self.href))
            self.href = None
p = Links(); p.feed(sys.stdin.read())
if len(p.matches) != 1: sys.exit("expected one official uSimmics download")
v, u = p.matches[0]
print(json.dumps({"version":v,"sources":[{"filename":"usimmics.zip","url":u}]}))
' <<<"$html")"
url="$(jq -er '.sources[0].url' <<<"$result")"
headers="$(curl -fsSI --retry 3 "$url")"
modified="$(sed -n 's/^[Ll]ast-[Mm]odified:[[:space:]]*//p' <<<"$headers" | tr -d '\r' | tail -n1)"
[ -n "$modified" ] || { echo 'missing Last-Modified' >&2; exit 1; }
stamp="$(date -u -d "$modified" +%Y%m%d%H%M%S)"
day="$(date -u -d "$modified" +%Y-%m-%d)"
jq --arg stamp "$stamp" --arg day "$day" '.version += ("-" + $stamp) | .releaseDate = $day' <<<"$result"
