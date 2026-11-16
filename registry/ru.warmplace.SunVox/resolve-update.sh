#!/usr/bin/env bash
set -euo pipefail

page="$(curl -fsSL https://www.warmplace.ru/soft/sunvox/)"
SUNVOX_PAGE="$page" node -e '
const html = process.env.SUNVOX_PAGE ?? "";
const match = html.match(/Latest release\s*-\s*([0-9]+(?:\.[0-9]+){1,3}[a-z]?)\s*\((\d{1,2})\s+([a-z]{3})\s+(\d{4})\)/i);
if (!match) {
  console.error("Could not find the latest SunVox version and date");
  process.exit(1);
}
const months = {jan: "01", feb: "02", mar: "03", apr: "04", may: "05", jun: "06", jul: "07", aug: "08", sep: "09", oct: "10", nov: "11", dec: "12"};
const [, version, day, monthName, year] = match;
const month = months[monthName.toLowerCase()];
if (!month) {
  console.error(`Unknown release month: ${monthName}`);
  process.exit(1);
}
const releaseDate = `${year}-${month}-${day.padStart(2, "0")}`;
const url = `https://www.warmplace.ru/soft/sunvox/sunvox-${version}.zip`;
console.log(JSON.stringify({version, releaseDate, sources: [{filename: "sunvox.zip", url}]}));
'
