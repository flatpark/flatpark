// Link-preview image (og:image) for each app page: its icon centred on a
// 1200x630 card, as PNG. WhatsApp, Telegram and Facebook drop SVG og:images,
// and most app icons are SVG, so the raw icon left those previews blank.
// The card size is repeated as og:image:width/height on the app page.
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import sharp from 'sharp';
import { dataDir, loadApps } from '../../lib/data.mjs';

const ICON = 440;

export function getStaticPaths() {
  return loadApps()
    .filter((app) => app.icon)
    .map((app) => ({ params: { id: app.id }, props: { icon: app.icon } }));
}

export async function GET({ props }: { props: { icon: string } }) {
  const src = readFileSync(join(dataDir, props.icon));
  const meta = await sharp(src).metadata();
  const native = Math.max(meta.width ?? ICON, meta.height ?? ICON);
  const svg = meta.format === 'svg';
  // An SVG is rasterised straight at ICON px (density is DPI, 72 = 1:1), so a
  // 64px viewBox is as sharp as a 512px one. A bitmap is enlarged at most 2x:
  // a 64-128px icon comes out smaller but not blurred.
  const size = svg ? ICON : Math.min(ICON, native * 2);
  const icon = await sharp(src, svg ? { density: (72 * ICON) / native } : {})
    .resize(size, size, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
    .png()
    .toBuffer();
  const card = await sharp({ create: { width: 1200, height: 630, channels: 3, background: '#ffffff' } })
    .composite([{ input: icon, gravity: 'centre' }])
    // WhatsApp skips preview images over ~300 KB; a palette keeps photo-like icons under it.
    .png({ palette: true, compressionLevel: 9 })
    .toBuffer();
  return new Response(new Uint8Array(card), { headers: { 'Content-Type': 'image/png' } });
}
