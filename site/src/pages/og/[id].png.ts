// Link-preview image (og:image) for each app page: its icon centred on a
// 1200x630 card, as PNG. WhatsApp, Telegram and Facebook drop SVG og:images,
// and most app icons are SVG, so the raw icon left those previews blank.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import { dataDir, loadApps } from '../../lib/data.mjs';

export function getStaticPaths() {
  return loadApps()
    .filter((app) => app.icon)
    .map((app) => ({ params: { id: app.id }, props: { icon: app.icon } }));
}

export async function GET({ props }: { props: { icon: string } }) {
  const icon = await sharp(readFileSync(join(dataDir, props.icon)), { density: 384 })
    .resize(440, 440, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();
  const card = await sharp({ create: { width: 1200, height: 630, channels: 3, background: '#ffffff' } })
    .composite([{ input: icon, gravity: 'centre' }])
    // WhatsApp skips preview images over ~300 KB; a palette keeps photo-like icons under it.
    .png({ palette: true, compressionLevel: 9 })
    .toBuffer();
  return new Response(new Uint8Array(card), { headers: { 'Content-Type': 'image/png' } });
}
