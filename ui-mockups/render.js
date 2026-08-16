// Hirena UI mockup renderer
// Renders the app's screens to PNG using the exact design tokens from
// lib/design/tokens.dart and the real bundled fonts (Inter/Barlow).
// Pure Node: hand-written PNG codec + quadratic-glyph rasterizer (no deps).
import fs from 'node:fs';
import zlib from 'node:zlib';
import * as opentype from '/tmp/opentype.js/src/opentype.mjs';

const ROOT = '/home/user/Hirena-Music';
const OUT = ROOT + '/ui-mockups';
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------- fonts
const F = {};
function loadFont(p) {
  const b = fs.readFileSync(ROOT + '/assets/fonts/' + p);
  const ab = b.buffer.slice(b.byteOffset, b.byteOffset + b.byteLength);
  return opentype.parse(ab);
}
F.barlowSemi = loadFont('Barlow-SemiBold.ttf');
F.barlow = loadFont('Barlow-Bold.ttf');
F.barlowBlack = loadFont('Barlow-Black.ttf');
F.inter = loadFont('Inter-Variable.ttf');

// ---------------------------------------------------------------- tokens
const C = {
  canvas: [0, 0, 0, 255],
  surface: [20, 20, 20, 255],
  surfaceRaised: [22, 22, 22, 255],
  surfaceHover: [35, 35, 35, 255],
  surfacePressed: [45, 45, 45, 255],
  inkPrimary: [255, 255, 255, 255],
  inkSecondary: [255, 255, 255, 179],
  inkDisabled: [255, 255, 255, 102],
  hairline: [255, 255, 255, 41],
  brandRed: [229, 9, 20, 255],
  brandRedDark: [178, 7, 16, 255],
  success: [42, 183, 89, 255],
};
const SCALE = 2;
const W = 1440, H = 900;

// ---------------------------------------------------------------- canvas
class Canvas {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8Array(w * h * 4); }
  px(v) { return Math.round(v * SCALE); }
  set(x, y, rgba) {
    x = Math.floor(x); y = Math.floor(y);
    if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const i = (y * this.w + x) * 4;
    const a = rgba[3] / 255;
    const ia = 1 - a;
    this.d[i] = Math.round(rgba[0] * a + this.d[i] * ia);
    this.d[i + 1] = Math.round(rgba[1] * a + this.d[i + 1] * ia);
    this.d[i + 2] = Math.round(rgba[2] * a + this.d[i + 2] * ia);
    this.d[i + 3] = 255;
  }
  fill(rgba) { for (let i = 0; i < this.d.length; i += 4) { this.d[i] = rgba[0]; this.d[i+1] = rgba[1]; this.d[i+2] = rgba[2]; this.d[i+3] = rgba[3]; } }
  fillRect(x, y, w, h, rgba) {
    x = this.px(x); y = this.px(y); w = this.px(w); h = this.px(h);
    for (let yy = y; yy < y + h; yy++) for (let xx = x; xx < x + w; xx++) this.set(xx, yy, rgba);
  }
  fillRounded(x, y, w, h, r, rgba) {
    x = this.px(x); y = this.px(y); w = this.px(w); h = this.px(h); r = this.px(r);
    for (let yy = y; yy < y + h; yy++) {
      for (let xx = x; xx < x + w; xx++) {
        // rounded-rect coverage (1 if inside)
        const dx = Math.max(x + r - xx, xx - (x + w - 1 - r), 0);
        const dy = Math.max(y + r - yy, yy - (y + h - 1 - r), 0);
        if (dx * dx + dy * dy <= r * r) this.set(xx, yy, rgba);
      }
    }
  }
  // vertical linear gradient (stops: [{t, rgba}])
  fillGradientV(x, y, w, h, stops) {
    x = this.px(x); y = this.px(y); w = this.px(w); h = this.px(h);
    for (let yy = 0; yy < h; yy++) {
      const t = h <= 1 ? 0 : yy / (h - 1);
      const rgba = lerpStops(stops, t);
      for (let xx = 0; xx < w; xx++) this.set(x + xx, y + yy, rgba);
    }
  }
  fillGradientH(x, y, w, h, stops) {
    x = this.px(x); y = this.px(y); w = this.px(w); h = this.px(h);
    for (let xx = 0; xx < w; xx++) {
      const t = w <= 1 ? 0 : xx / (w - 1);
      const rgba = lerpStops(stops, t);
      for (let yy = 0; yy < h; yy++) this.set(x + xx, y + yy, rgba);
    }
  }
  // stroke circle (ring)
  circle(x, y, r, rgba, thickness) {
    const cx = this.px(x), cy = this.px(y), R = this.px(r), T = this.px(thickness || 1.5);
    for (let yy = cy - R - T; yy <= cy + R + T; yy++)
      for (let xx = cx - R - T; xx <= cx + R + T; xx++) {
        const d = Math.hypot(xx - cx, yy - cy);
        if (Math.abs(d - R) <= T) this.set(xx, yy, rgba);
      }
  }
  disc(x, y, r, rgba) {
    const cx = this.px(x), cy = this.px(y), R = this.px(r);
    for (let yy = cy - R; yy <= cy + R; yy++)
      for (let xx = cx - R; xx <= cx + R; xx++)
        if (Math.hypot(xx - cx, yy - cy) <= R) this.set(xx, yy, rgba);
  }
  line(x0, y0, x1, y1, thickness, rgba) {
    const ax = this.px(x0), ay = this.px(y0), bx = this.px(x1), by = this.px(y1), T = this.px(thickness) / 2;
    const minx = Math.min(ax, bx) - Math.ceil(T) - 2, maxx = Math.max(ax, bx) + Math.ceil(T) + 2;
    const miny = Math.min(ay, by) - Math.ceil(T) - 2, maxy = Math.max(ay, by) + Math.ceil(T) + 2;
    for (let yy = miny; yy <= maxy; yy++) for (let xx = minx; xx <= maxx; xx++) {
      const d = distToSeg(xx, yy, ax, ay, bx, by);
      if (d <= T) this.set(xx, yy, rgba);
    }
  }
  // polygon fill (list of [x,y] logical), even-odd via scanline, AA via supersample
  polygon(points, rgba) {
    const pts = points.map(p => [this.px(p[0]), this.px(p[1])]);
    const minx = Math.min(...pts.map(p => p[0])), maxx = Math.max(...pts.map(p => p[0]));
    const miny = Math.min(...pts.map(p => p[1])), maxy = Math.max(...pts.map(p => p[1]));
    for (let yy = miny; yy <= maxy; yy++) {
      const xs = [];
      for (let i = 0; i < pts.length; i++) {
        const [x0, y0] = pts[i], [x1, y1] = pts[(i + 1) % pts.length];
        if (y0 === y1) continue;
        const y = yy + 0.5;
        if ((y0 <= y && y1 > y) || (y1 <= y && y0 > y)) xs.push(x0 + (y - y0) * (x1 - x0) / (y1 - y0));
      }
      xs.sort((a, b) => a - b);
      for (let i = 0; i + 1 < xs.length; i += 2) {
        const xa = Math.ceil(xs[i]), xb = Math.floor(xs[i + 1]);
        for (let xx = xa; xx <= xb; xx++) this.set(xx, yy, rgba);
      }
    }
  }
  // blit an RGBA image with bilinear resample + optional rounded-rect mask
  blit(img, dx, dy, dw, dh, { mask, alpha = 1 } = {}) {
    const X = this.px(dx), Y = this.px(dy), DW = this.px(dw), DH = this.px(dh);
    for (let yy = 0; yy < DH; yy++) {
      const sy = (yy + 0.5) / DH * img.h - 0.5;
      for (let xx = 0; xx < DW; xx++) {
        const sx = (xx + 0.5) / DW * img.w - 0.5;
        const p = sample(img, sx, sy);
        if (p[3] === 0) continue;
        let a = alpha;
        if (mask) {
          const mx = xx / DW * (mask.w - 1), my = yy / DH * (mask.h - 1);
          a *= mask.d[((my | 0) * mask.w + (mx | 0)) * 4 + 3] / 255;
        }
        this.set(X + xx, Y + yy, [p[0], p[1], p[2], Math.round(p[3] * a)]);
      }
    }
  }
  text(t, x, yTop, font, size, rgba, { tracking = 0 } = {}) {
    const scale = size / font.unitsPerEm;
    const asc = font.ascender * scale;
    let pen = this.px(x);
    const baseY = this.px(yTop) + this.px(asc);
    for (const ch of t) {
      const g = glyph(font, ch, size);
      if (g) {
        this.blitGlyph(g.bitmap, pen, baseY - g.top, g.w, g.h, rgba);
        pen += g.w;
      }
      pen += this.px(scale * font.charToGlyph(ch).advanceWidth) - (g ? g.w : 0) + this.px(tracking);
    }
  }
  blitGlyph(g, x, y, w, h, rgba) {
    // g is alpha-only (w,h)
    for (let yy = 0; yy < h; yy++) {
      const gy = y + yy;
      if (gy < 0 || gy >= this.h) continue;
      for (let xx = 0; xx < w; xx++) {
        const gx = x + xx;
        if (gx < 0 || gx >= this.w) continue;
        const a = g[yy * w + xx];
        if (a === 0) continue;
        this.set(gx, gy, [rgba[0], rgba[1], rgba[2], Math.round(rgba[3] * a / 255)]);
      }
    }
  }
}

function lerpStops(stops, t) {
  if (t <= stops[0].t) return stops[0].rgba;
  for (let i = 0; i < stops.length - 1; i++) {
    const a = stops[i], b = stops[i + 1];
    if (t >= a.t && t <= b.t) {
      const f = b.t === a.t ? 0 : (t - a.t) / (b.t - a.t);
      return [0, 1, 2, 3].map(k => Math.round(a.rgba[k] + (b.rgba[k] - a.rgba[k]) * f));
    }
  }
  return stops[stops.length - 1].rgba;
}
function distToSeg(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const l2 = dx * dx + dy * dy;
  let t = l2 === 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / l2;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}

// ---------------------------------------------------------------- glyph rasterization
const glyphCache = new Map();
const _fontIds = new WeakMap();
let _fontIdSeq = 0;
function fontId(font) {
  if (!_fontIds.has(font)) _fontIds.set(font, ++_fontIdSeq);
  return _fontIds.get(font);
}
const SS = 3; // supersample for AA
function glyph(font, ch, size) {
  const key = fontId(font) + '|' + ch + '|' + size;
  if (glyphCache.has(key)) return glyphCache.get(key);
  const g = font.charToGlyph(ch);
  const path = g.getPath(0, 0, size * SCALE);
  const contours = [];
  let cur = null;
  for (const c of path.commands) {
    if (c.type === 'M') { if (cur && cur.length) contours.push(cur); cur = [[c.x, c.y]]; }
    else if (c.type === 'L') cur.push([c.x, c.y]);
    else if (c.type === 'Q') { flattenQ(cur, c.x1, c.y1, c.x, c.y); }
    else if (c.type === 'C') { flattenC(cur, c.x1, c.y1, c.x2, c.y2, c.x, c.y); }
    else if (c.type === 'Z') { if (cur && cur.length) contours.push(cur); cur = null; }
  }
  if (cur && cur.length) contours.push(cur);
  if (!contours.length) { glyphCache.set(key, null); return null; }
  let minx = Infinity, maxx = -Infinity, miny = Infinity, maxy = -Infinity;
  for (const ct of contours) for (const [x, y] of ct) { minx = Math.min(minx, x); maxx = Math.max(maxx, x); miny = Math.min(miny, y); maxy = Math.max(maxy, y); }
  const bw = Math.ceil((maxx - minx) * SS) + 2, bh = Math.ceil((maxy - miny) * SS) + 2;
  const coarse = new Uint8Array(bw * bh);
  // scanline fill in supersampled space (row 0 = miny = cap top)
  for (let ys = 0; ys < bh; ys++) {
    const y = miny + (ys + 0.5) / SS;
    const xs = [];
    for (const ct of contours) {
      for (let i = 0; i < ct.length; i++) {
        const [x0, y0] = ct[i], [x1, y1] = ct[(i + 1) % ct.length];
        if (y0 === y1) continue;
        if ((y0 <= y && y1 > y) || (y1 <= y && y0 > y)) xs.push(x0 + (y - y0) * (x1 - x0) / (y1 - y0));
      }
    }
    xs.sort((a, b) => a - b);
    for (let i = 0; i + 1 < xs.length; i += 2) {
      const xa = Math.ceil((xs[i] - minx) * SS), xb = Math.floor((xs[i + 1] - minx) * SS);
      for (let x = Math.max(0, xa); x <= Math.min(bw - 1, xb); x++) coarse[ys * bw + x] = 1;
    }
  }
  // downsample
  const w = Math.ceil(bw / SS), h = Math.ceil(bh / SS);
  const bitmap = new Uint8Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let s = 0, n = 0;
    for (let dy = 0; dy < SS; dy++) for (let dx = 0; dx < SS; dx++) {
      const cx = x * SS + dx, cy = y * SS + dy;
      if (cx < bw && cy < bh) { s += coarse[cy * bw + cx]; n++; }
    }
    bitmap[y * w + x] = Math.round(s / n * 255);
  }
  const res = { bitmap, w, h, top: -miny }; // distance above baseline to glyph top
  glyphCache.set(key, res);
  return res;
}
function flattenQ(pts, x1, y1, x, y) {
  const [x0, y0] = pts[pts.length - 1];
  const N = 8;
  for (let i = 1; i <= N; i++) {
    const t = i / N;
    const a = (1 - t) * (1 - t), b = 2 * (1 - t) * t, c = t * t;
    pts.push([a * x0 + b * x1 + c * x, a * y0 + b * y1 + c * y]);
  }
}
function flattenC(pts, x1, y1, x2, y2, x, y) {
  const [x0, y0] = pts[pts.length - 1];
  const N = 10;
  for (let i = 1; i <= N; i++) {
    const t = i / N, u = 1 - t;
    const a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t;
    pts.push([a * x0 + b * x1 + c * x2 + d * x, a * y0 + b * y1 + c * y2 + d * y]);
  }
}

// ---------------------------------------------------------------- PNG codec
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; }
  return t;
})();
function crc32(buf) { let c = -1; for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8); return (c ^ -1) >>> 0; }
function encodePNG(w, h, rgba) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) { raw[y * (w * 4 + 1)] = 0; rgba.copy ? rgba.copy(raw, y * (w * 4 + 1) + 1, y * w * 4, (y + 1) * w * 4) : raw.set(rgba.subarray(y * w * 4, (y + 1) * w * 4), y * (w * 4 + 1) + 1); }
  const idat = zlib.deflateSync(raw);
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 6; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  const chunk = (type, data) => { const t = Buffer.from(type, 'ascii'); const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, crc]); };
  return Buffer.concat([sig, chunk('IHDR', ihdr), chunk('IDAT', idat), chunk('IEND', Buffer.alloc(0))]);
}
function decodePNG(buf) {
  let pos = 8; let w = 0, h = 0, bd = 0, ct = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos); const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bd = data[8]; ct = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'PLTE') { /* palette ignored (only ct 2/6 expected) */ }
    pos += 12 + len;
  }
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = ct === 6 ? 4 : ct === 2 ? 3 : 0;
  const stride = w * bpp;
  const out = new Uint8Array(w * h * 4);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const f = raw[p++]; const row = raw.subarray(p, p + stride); p += stride;
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? row[x - bpp] : 0;
      const b = y > 0 ? raw[p - stride - stride + x] : 0; // handled below instead
      let v = row[x];
      if (f === 1) v += x >= bpp ? row[x - bpp] : 0;
      else if (f === 2) v += b;
      else if (f === 3) v += Math.floor(((x >= bpp ? row[x - bpp] : 0) + b) / 2);
      else if (f === 4) v += paeth(x >= bpp ? row[x - bpp] : 0, b, (x >= bpp && y > 0) ? raw[p - stride - stride + x - bpp] : 0);
      row[x] = v & 0xff;
    }
    for (let x = 0; x < w; x++) {
      const o = (y * w + x) * 4;
      if (ct === 6) { out[o] = row[x * 4]; out[o + 1] = row[x * 4 + 1]; out[o + 2] = row[x * 4 + 2]; out[o + 3] = row[x * 4 + 3]; }
      else { out[o] = row[x * 3]; out[o + 1] = row[x * 3 + 1]; out[o + 2] = row[x * 3 + 2]; out[o + 3] = 255; }
    }
  }
  return { w, h, d: out };
}
function paeth(a, b, c) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); return pa <= pb && pa <= pc ? a : pb <= pc ? b : c; }
function sample(img, x, y) {
  const fx = Math.max(0, Math.min(img.w - 1, x)), fy = Math.max(0, Math.min(img.h - 1, y));
  const x0 = Math.floor(fx), y0 = Math.floor(fy), x1 = Math.min(img.w - 1, x0 + 1), y1 = Math.min(img.h - 1, y0 + 1);
  const tx = fx - x0, ty = fy - y0;
  const i00 = (y0 * img.w + x0) * 4, i10 = (y0 * img.w + x1) * 4, i01 = (y1 * img.w + x0) * 4, i11 = (y1 * img.w + x1) * 4;
  const out = [];
  for (let k = 0; k < 4; k++) {
    const v = img.d[i00 + k] * (1 - tx) * (1 - ty) + img.d[i10 + k] * tx * (1 - ty) + img.d[i01 + k] * (1 - tx) * ty + img.d[i11 + k] * tx * ty;
    out.push(Math.round(v));
  }
  return out;
}

// ---------------------------------------------------------------- helpers
function roundedMask(w, h, r) {
  const c = new Canvas(w * SCALE, h * SCALE);
  c.fill([0, 0, 0, 0]);
  c.fillRounded(0, 0, w, h, r, [0, 0, 0, 255]);
  return { w: c.w, h: c.h, d: c.d };
}
function textWidth(font, size, str, tracking = 0) {
  const scale = size / font.unitsPerEm;
  let w = 0;
  for (const ch of str) w += font.charToGlyph(ch).advanceWidth * scale + tracking;
  return w;
}
function truncate(font, size, str, maxW, tracking = 0) {
  if (textWidth(font, size, str, tracking) <= maxW) return str;
  let s = str;
  while (s.length > 1 && textWidth(font, size, s + '…', tracking) > maxW) s = s.slice(0, -1);
  return s + '…';
}

// load covers
const covers = [];
for (let i = 1; i <= 8; i++) covers.push(decodePNG(fs.readFileSync(ROOT + '/ui-mockups/covers/0' + i + '.png')));

// ---------------------------------------------------------------- icons
function playIcon(cv, cx, cy, size, rgba) {
  cv.polygon([[cx - size * 0.28, cy - size * 0.42], [cx - size * 0.28, cy + size * 0.42], [cx + size * 0.42, cy]], rgba);
}
function pauseIcon(cv, cx, cy, size, rgba) {
  cv.fillRect(cx - size * 0.3, cy - size * 0.4, size * 0.22, size * 0.8, rgba);
  cv.fillRect(cx + size * 0.08, cy - size * 0.4, size * 0.22, size * 0.8, rgba);
}
function nextIcon(cv, cx, cy, size, rgba) {
  cv.polygon([[cx - size * 0.24, cy - size * 0.4], [cx - size * 0.24, cy + size * 0.4], [cx + size * 0.24, cy]], rgba);
  cv.fillRect(cx + size * 0.28, cy - size * 0.4, size * 0.14, size * 0.8, rgba);
}
function prevIcon(cv, cx, cy, size, rgba) {
  cv.polygon([[cx + size * 0.24, cy - size * 0.4], [cx + size * 0.24, cy + size * 0.4], [cx - size * 0.24, cy]], rgba);
  cv.fillRect(cx - size * 0.42, cy - size * 0.4, size * 0.14, size * 0.8, rgba);
}
function heartIcon(cv, cx, cy, size, rgba) {
  const r = size * 0.22;
  cv.disc(cx - r * 0.6, cy - r * 0.3, r, rgba);
  cv.disc(cx + r * 0.6, cy - r * 0.3, r, rgba);
  cv.polygon([[cx - r * 1.55, cy - r * 0.05], [cx + r * 1.55, cy - r * 0.05], [cx, cy + size * 0.5]], rgba);
}
function searchIcon(cv, cx, cy, size, rgba) {
  cv.circle(cx - size * 0.1, cy - size * 0.1, size * 0.32, rgba, size * 0.13);
  cv.line(cx + size * 0.14, cy + size * 0.14, cx + size * 0.42, cy + size * 0.42, size * 0.14, rgba);
}
function shuffleIcon(cv, cx, cy, size, rgba) {
  const t = size * 0.1;
  cv.line(cx - size * 0.4, cy - size * 0.35, cx + size * 0.4, cy + size * 0.35, t, rgba);
  cv.line(cx - size * 0.4, cy + size * 0.35, cx + size * 0.4, cy - size * 0.35, t, rgba);
  cv.polygon([[cx + size * 0.28, cy + size * 0.5], [cx + size * 0.5, cy + size * 0.28], [cx + size * 0.5, cy + size * 0.5]], rgba);
  cv.polygon([[cx + size * 0.28, cy - size * 0.5], [cx + size * 0.5, cy - size * 0.28], [cx + size * 0.5, cy - size * 0.5]], rgba);
}
function repeatIcon(cv, cx, cy, size, rgba) {
  const t = size * 0.12;
  cv.circle(cx - size * 0.12, cy - size * 0.12, size * 0.42, rgba, t);
  cv.polygon([[cx + size * 0.16, cy - size * 0.48], [cx + size * 0.4, cy - size * 0.22], [cx + size * 0.12, cy - size * 0.12]], rgba);
}
function gearIcon(cv, cx, cy, size, rgba) {
  const t = size * 0.09;
  cv.circle(cx, cy, size * 0.26, rgba, t);
  cv.disc(cx, cy, size * 0.1, rgba);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    cv.line(cx + Math.cos(a) * size * 0.32, cy + Math.sin(a) * size * 0.32, cx + Math.cos(a) * size * 0.46, cy + Math.sin(a) * size * 0.46, t, rgba);
  }
}
function eqIcon(cv, cx, cy, size, rgba) { // "playing" graphic eq
  const bw = size * 0.12;
  for (let i = 0; i < 3; i++) {
    const h = [0.3, 0.8, 0.55][i] * size;
    cv.fillRect(cx + (i - 1) * size * 0.24 - bw / 2, cy - h / 2, bw, h, rgba);
  }
}

// ---------------------------------------------------------------- ui atoms
const RR = 8; // card radius

function topBar(cv, active) {
  cv.fillGradientV(0, 0, W, 64, [{ t: 0, rgba: [0, 0, 0, 150] }, { t: 1, rgba: [0, 0, 0, 0] }]);
  cv.text('HIRENA', 24, 18, F.barlowBlack, 24, C.brandRed, { tracking: 1.6 });
  const items = ['Home', 'Search', 'Library'];
  let x = 150;
  for (const it of items) {
    const c = it === active ? C.inkPrimary : C.inkSecondary;
    cv.text(it, x, 24, F.barlowSemi, 15, c);
    x += textWidth(F.barlowSemi, 15, it) + 28;
  }
  gearIcon(cv, W - 34, 32, 22, C.inkPrimary);
}

function button(cv, x, y, label, { icon = 'play', primary = true } = {}) {
  const w = label ? textWidth(F.barlowSemi, 15, label) + 64 : 46;
  const h = 42;
  cv.fillRounded(x, y, w, h, 4, primary ? C.inkPrimary : [255, 255, 255, 10]);
  if (!primary) { cv.line(x + 1, y + 1, x + w - 1, y + 1, 1, C.hairline); cv.line(x + 1, y + h, x + w - 1, y + h, 1, C.hairline); }
  const ic = primary ? C.canvas : C.inkPrimary;
  if (icon === 'play') playIcon(cv, x + 20, y + h / 2, 18, ic);
  else if (icon === 'shuffle') shuffleIcon(cv, x + 20, y + h / 2, 16, ic);
  if (label) cv.text(label, x + 38, y + (h - 15) / 2 + 1, F.barlowSemi, 15, primary ? [0, 0, 0, 255] : C.inkPrimary);
  return w;
}

function posterCard(cv, x, y, w, img, title, subtitle, { hover = false, round = false } = {}) {
  const h = w * 1.5;
  const r = round ? w / 2 : RR;
  const mask = roundedMask(w, h, r);
  cv.blit(img, x, y, w, h, { mask });
  if (hover) {
    cv.disc(x + w - 22, y + h - 22, 18, C.brandRed);
    playIcon(cv, x + w - 22, y + h - 22, 14, C.inkPrimary);
  }
  const ty = y + h + 10;
  cv.text(truncate(F.inter, 14, title, w), x, ty, F.inter, 14, C.inkPrimary);
  cv.text(truncate(F.inter, 13, subtitle, w), x, ty + 20, F.inter, 13, C.inkSecondary);
}

function sectionTitle(cv, y, t) { cv.text(t, 24, y, F.barlow, 20, C.inkPrimary); }

function nowPlayingBar(cv, current, playing = true) {
  const y = H - 76;
  cv.fillRect(0, y, W, 76, C.surface);
  // progress
  cv.fillRect(0, y, W, 3, C.surfaceHover);
  cv.fillRect(0, y, W * 0.34, 3, C.brandRed);
  // art
  const mask = roundedMask(44, 44, 4);
  cv.blit(covers[0], 16, y + 15, 44, 44, { mask });
  cv.text(truncate(F.inter, 14, current[0], 360), 72, y + 16, F.barlowSemi, 14, C.inkPrimary);
  cv.text(truncate(F.inter, 13, current[1], 360), 72, y + 38, F.inter, 13, C.inkSecondary);
  pauseIcon(cv, W - 84, y + 38, 24, C.inkPrimary);
  nextIcon(cv, W - 40, y + 38, 24, C.inkPrimary);
}

function trackRow(cv, y, idx, title, artist, dur, { playing = false, hover = false, showAlbum = false } = {}) {
  if (hover) cv.fillRounded(8, y - 6, W - 16, 50, 4, C.surfaceRaised);
  if (playing) {
    eqIcon(cv, 36, y + 20, 20, C.brandRed);
  } else if (hover) {
    playIcon(cv, 36, y + 20, 20, C.inkPrimary);
  } else {
    cv.text(String(idx + 1), 36 - textWidth(F.inter, 13, String(idx + 1)) / 2, y + 12, F.inter, 13, C.inkSecondary);
  }
  cv.text(truncate(F.inter, 14, title, 520), 60, y + 8, F.inter, 14, playing ? C.brandRed : C.inkPrimary);
  cv.text(truncate(F.inter, 13, showAlbum ? artist : artist, 520), 60, y + 28, F.inter, 13, C.inkSecondary);
  heartIcon(cv, W - 92, y + 20, 16, hover ? C.inkSecondary : [255, 255, 255, 60]);
  cv.text(dur, W - 56, y + 13, F.inter, 13, C.inkSecondary);
}

// ---------------------------------------------------------------- screens
function renderHome() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  // hero
  const heroH = 480;
  cv.blit(covers[0], 0, 0, W, heroH, {});
  cv.fillGradientH(0, 0, W, heroH, [{ t: 0, rgba: [0, 0, 0, 230] }, { t: 0.55, rgba: [0, 0, 0, 102] }, { t: 1, rgba: [0, 0, 0, 0] }]);
  cv.fillGradientV(heroH - 160, 0, W, 160, [{ t: 0, rgba: [0, 0, 0, 0] }, { t: 1, rgba: [0, 0, 0, 204] }]);
  topBar(cv, 'Home');
  cv.text('HIRENA ORIGINAL', 64, heroH - 190, F.barlowSemi, 12, C.brandRed, { tracking: 1.6 });
  cv.text('Neon Skyline', 64, heroH - 160, F.barlowBlack, 56, C.inkPrimary);
  cv.text('Midnight Avenue · Neon Skyline', 64, heroH - 108, F.inter, 14, C.inkSecondary);
  button(cv, 64, heroH - 88, 'Play', { icon: 'play' });
  button(cv, 64 + 128, heroH - 88, 'Shuffle', { icon: 'shuffle', primary: false });
  // rows
  let y = heroH + 8;
  const mkRow = (title, items, cardW, round) => {
    sectionTitle(cv, y + 26, title);
    let x = 24;
    for (let i = 0; i < items.length; i++) {
      const it = items[i];
      posterCard(cv, x, y + 54, cardW, covers[it.img], it.t, it.s, { round });
      x += cardW + 12;
    }
    y += 54 + cardW * 1.5 + 30;
  };
  mkRow('Made for you', [
    { t: 'Neon Skyline', s: 'Midnight Avenue', img: 0 },
    { t: 'Deep Currents', s: 'Azure Theory', img: 1 },
    { t: 'Crimson Smoke', s: 'Velvet Saint', img: 2 },
    { t: 'Chrome Dreams', s: 'Nova Circuit', img: 3 },
    { t: 'Pastel Skies', s: 'Mirage Hotel', img: 4 },
    { t: 'Nebula Garden', s: 'Orion Fields', img: 5 },
  ], 148);
  mkRow('Top charts', [
    { t: 'Neon Skyline', s: 'Midnight Avenue', img: 0 },
    { t: 'Solar Tide', s: 'Retrograde', img: 7 },
    { t: 'Gilded Silence', s: 'Aurelia', img: 6 },
    { t: 'Deep Currents', s: 'Azure Theory', img: 1 },
    { t: 'Chrome Dreams', s: 'Nova Circuit', img: 3 },
    { t: 'Pastel Skies', s: 'Mirage Hotel', img: 4 },
  ], 148);
  mkRow('Popular albums', [
    { t: 'Neon Skyline', s: 'Midnight Avenue', img: 0 },
    { t: 'Deep Currents', s: 'Azure Theory', img: 1 },
    { t: 'Crimson Smoke', s: 'Velvet Saint', img: 2 },
    { t: 'Nebula Garden', s: 'Orion Fields', img: 5 },
    { t: 'Solar Tide', s: 'Retrograde', img: 7 },
  ], 168);
  mkRow('Popular artists', [
    { t: 'Lumen Arc', s: 'Artist', img: 1 },
    { t: 'Iris Vale', s: 'Artist', img: 4 },
    { t: 'Static Bloom', s: 'Artist', img: 3 },
    { t: 'Juno Wave', s: 'Artist', img: 5 },
    { t: 'Phantom Coast', s: 'Artist', img: 2 },
  ], 148);
  // now playing
  nowPlayingBar(cv, ['Neon Skyline', 'Midnight Avenue']);
  return cv;
}

function renderSearch() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  topBar(cv, 'Search');
  // search field
  cv.fillRounded(24, 88, W - 48, 52, 4, C.surfaceRaised);
  searchIcon(cv, 48, 114, 22, C.inkSecondary);
  cv.text('neon', 64, 104, F.inter, 15, C.inkPrimary);
  cv.text('|', 92 + textWidth(F.inter, 15, 'neon'), 104, F.inter, 15, C.inkSecondary);
  let y = 168;
  cv.text('Songs', 24, y, F.barlow, 20, C.inkPrimary);
  y += 34;
  const songs = [
    ['Neon Skyline', 'Midnight Avenue', '3:42'],
    ['Neon Nights', 'Static Bloom', '4:05'],
    ['Neon Rain', 'Juno Wave', '3:18'],
    ['Neon Skyline (Remix)', 'Midnight Avenue', '3:57'],
  ];
  songs.forEach((s, i) => { trackRow(cv, y, i, s[0], s[1], s[2], { hover: i === 0 }); y += 56; });
  // albums row
  y += 10;
  cv.text('Albums', 24, y, F.barlow, 20, C.inkPrimary);
  let x = 24;
  for (let i = 0; i < 5; i++) { posterCard(cv, x, y + 30, 150, covers[i], ['Neon Skyline', 'Deep Currents', 'Crimson Smoke', 'Chrome Dreams', 'Pastel Skies'][i], 'Album'); x += 162; }
  y += 30 + 150 * 1.5 + 40;
  // artists
  cv.text('Artists', 24, y, F.barlow, 20, C.inkPrimary);
  x = 24;
  for (let i = 0; i < 4; i++) { posterCard(cv, x, y + 30, 130, covers[4 + i], ['Lumen Arc', 'Static Bloom', 'Juno Wave', 'Phantom Coast'][i], 'Artist'); x += 142; }
  y += 30 + 130 * 1.5 + 40;
  cv.text('Playlists', 24, y, F.barlow, 20, C.inkPrimary);
  x = 24;
  const pl = ['Late Night Neon', 'Synthwave Essentials', 'Neon Drive', 'Midnight Sessions'];
  for (let i = 0; i < 4; i++) { posterCard(cv, x, y + 30, 130, covers[i], pl[i], 'Playlist'); x += 142; }
  nowPlayingBar(cv, ['Neon Skyline', 'Midnight Avenue']);
  return cv;
}

function renderAlbum() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  topBar(cv, 'Home');
  // header
  const mask = roundedMask(200, 200, 8);
  cv.blit(covers[0], 32, 96, 200, 200, { mask });
  cv.text('Neon Skyline', 256, 110, F.barlowBlack, 40, C.inkPrimary);
  cv.text('Midnight Avenue · 2024 · 12 tracks', 256, 168, F.inter, 13, C.inkSecondary);
  button(cv, 256, 196, 'Play', { icon: 'play' });
  button(cv, 256 + 128, 196, 'Shuffle', { icon: 'shuffle', primary: false });
  // tracks
  let y = 330;
  const tr = [
    ['Neon Skyline', '3:42'], ['Electric Horizon', '4:05'], ['Midnight Avenue', '3:18'],
    ['Cobalt Nights', '3:57'], ['Laser Bloom', '4:21'], ['Afterglow', '3:33'],
    ['Glass City', '3:49'], ['Voltage', '4:12'], ['Sunset Circuit', '3:26'],
    ['Echo Chamber', '4:02'], ['Neon Skyline (Outro)', '2:58'],
  ];
  tr.forEach((t, i) => { trackRow(cv, y, i, t[0], 'Midnight Avenue', t[1], { playing: i === 0, hover: i === 2 }); y += 54; });
  nowPlayingBar(cv, ['Neon Skyline', 'Midnight Avenue']);
  return cv;
}

function renderPlayer() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  cv.fillGradientV(0, 0, W, H, [{ t: 0, rgba: [20, 20, 20, 255] }, { t: 1, rgba: [0, 0, 0, 255] }]);
  // left: art + info
  const art = 380, ax = 80, ay = 90;
  const mask = roundedMask(art, art, 12);
  cv.blit(covers[0], ax, ay, art, art, { mask });
  const infoX = ax;
  cv.text('AUTO-ENHANCED', infoX, ay + art + 28, F.barlowSemi, 11, C.brandRed, { tracking: 1.6 });
  cv.text('Neon Skyline', infoX, ay + art + 48, F.barlowBlack, 34, C.inkPrimary);
  cv.text('Midnight Avenue', infoX, ay + art + 92, F.inter, 14, C.inkSecondary);
  // scrubber
  const sy = ay + art + 132;
  cv.fillRounded(infoX, sy, art, 4, 2, C.surfaceHover);
  cv.fillRounded(infoX, sy, art * 0.34, 4, 2, C.brandRed);
  cv.disc(infoX + art * 0.34, sy + 2, 7, C.brandRed);
  cv.text('1:14', infoX, sy + 14, F.inter, 12, C.inkSecondary);
  cv.text('3:42', infoX + art - 24, sy + 14, F.inter, 12, C.inkSecondary);
  // transport
  const ty = sy + 70;
  shuffleIcon(cv, infoX + 90, ty, 22, C.inkSecondary);
  prevIcon(cv, infoX + 190, ty, 30, C.inkPrimary);
  pauseIcon(cv, infoX + 300, ty, 46, C.inkPrimary);
  nextIcon(cv, infoX + 410, ty, 30, C.inkPrimary);
  repeatIcon(cv, infoX + 500, ty, 22, C.inkSecondary);
  // right: up next
  const rx = 780;
  cv.fillRect(rx, 0, W - rx, H, [20, 20, 20, 128]);
  cv.text('Up next', rx + 24, 40, F.barlow, 20, C.inkPrimary);
  const q = [
    ['Electric Horizon', 'Midnight Avenue', '4:05'],
    ['Cobalt Nights', 'Midnight Avenue', '3:57'],
    ['Laser Bloom', 'Midnight Avenue', '4:21'],
    ['Afterglow', 'Midnight Avenue', '3:33'],
    ['Glass City', 'Midnight Avenue', '3:49'],
  ];
  let qy = 84;
  q.forEach((t, i) => {
    cv.text(String(i + 1), rx + 24, qy + 12, F.inter, 13, C.inkSecondary);
    cv.text(t[0], rx + 48, qy + 8, F.inter, 14, C.inkPrimary);
    cv.text(t[1], rx + 48, qy + 28, F.inter, 13, C.inkSecondary);
    cv.text(t[2], W - 48, qy + 13, F.inter, 13, C.inkSecondary);
    qy += 60;
  });
  // smart shuffle banner
  cv.fillRounded(rx + 24, qy + 6, W - rx - 48, 44, 6, C.surfaceRaised);
  cv.text('AUTO', rx + 40, qy + 21, F.barlowSemi, 11, C.brandRed, { tracking: 1.2 });
  cv.text('Smart Shuffle will add similar tracks', rx + 84, qy + 19, F.inter, 13, C.inkSecondary);
  return cv;
}

function renderAuth() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  cv.fillGradientV(0, 0, W, H, [{ t: 0, rgba: [0, 0, 0, 230] }, { t: 1, rgba: [10, 10, 10, 255] }]);
  const cx = W / 2, cy = 300;
  cv.text('HIRENA', cx - textWidth(F.barlowBlack, 52, 'HIRENA') / 2, cy, F.barlowBlack, 52, C.brandRed, { tracking: 2 });
  const sub = 'Stream the Deezer catalog with your own ARL — used only as a streaming key.';
  cv.text(sub, cx - textWidth(F.inter, 14, sub) / 2, cy + 70, F.inter, 14, C.inkSecondary);
  // input
  cv.fillRounded(cx - 220, cy + 120, 440, 56, 4, C.surfaceRaised);
  cv.text('Deezer ARL token', cx - 200, cy + 140, F.inter, 14, C.inkDisabled);
  // button
  const bw = 200, bh = 48, bx = cx - bw / 2, by = cy + 200;
  cv.fillRounded(bx, by, bw, bh, 4, C.brandRed);
  cv.text('Start listening', bx + (bw - textWidth(F.barlowSemi, 15, 'Start listening')) / 2, by + 16, F.barlowSemi, 15, C.inkPrimary);
  // how-to card
  const hw = 480, hx = cx - hw / 2, hy = cy + 290;
  cv.fillRounded(hx, hy, hw, 64, 8, C.surfaceRaised);
  cv.text('How to get your ARL: log in at deezer.com → DevTools (F12) →', hx + 24, hy + 16, F.inter, 12, C.inkSecondary);
  cv.text('Application → Cookies → deezer.com → copy the “arl” cookie value.', hx + 24, hy + 38, F.inter, 12, C.inkSecondary);
  return cv;
}

function renderSettings() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  topBar(cv, 'Home');
  cv.text('Settings', 32, 100, F.barlowBlack, 34, C.inkPrimary);
  let y = 150;
  const sec = (title) => { cv.text(title, 32, y, F.barlow, 20, C.inkPrimary); y += 34; };
  const row = (label, value, accent = false) => {
    cv.text(label, 48, y + 14, F.inter, 14, C.inkPrimary);
    cv.text(value, W - 300, y + 14, F.inter, 13, accent ? C.brandRed : C.inkSecondary);
    y += 44;
  };
  sec('Playback');
  row('Streaming quality', 'MP3 320 kbps');
  cv.text('Crossfade', 48, y + 14, F.inter, 14, C.inkPrimary);
  cv.fillRounded(W - 400, y + 12, 260, 4, 2, C.surfaceHover);
  cv.fillRounded(W - 400, y + 12, 260 * 0.33, 4, 2, C.brandRed);
  cv.disc(W - 400 + 260 * 0.33, y + 14, 7, C.brandRed);
  cv.text('4000 ms', W - 300, y + 14, F.inter, 13, C.inkSecondary);
  y += 44;
  row('Automix', 'On', true);
  row('Default shuffle', 'Standard');
  y += 14;
  sec('Account');
  row('Deezer ARL', 'valid · profile never read', true);
  row('Sign out', '');
  y += 14;
  sec('About');
  cv.text('Hirena Music streams the Deezer catalog using your own ARL as a', 48, y, F.inter, 13, C.inkSecondary);
  cv.text('streaming key, for personal use only. Not affiliated with Deezer.', 48, y + 22, F.inter, 13, C.inkSecondary);
  nowPlayingBar(cv, ['Neon Skyline', 'Midnight Avenue']);
  return cv;
}

function renderLibrary() {
  const cv = new Canvas(W * SCALE, H * SCALE);
  cv.fill(C.canvas);
  topBar(cv, 'Library');
  cv.text('Library', 32, 100, F.barlowBlack, 34, C.inkPrimary);
  cv.text('Your saved tracks', 32, 150, F.barlow, 18, C.inkSecondary);
  const tr = [
    ['Neon Skyline', 'Midnight Avenue · Neon Skyline', '3:42'],
    ['Deep Currents', 'Azure Theory · Deep Currents', '4:05'],
    ['Crimson Smoke', 'Velvet Saint · Crimson Smoke', '3:18'],
    ['Chrome Dreams', 'Nova Circuit · Chrome Dreams', '3:57'],
    ['Pastel Skies', 'Mirage Hotel · Pastel Skies', '4:21'],
  ];
  let y = 190;
  tr.forEach((t, i) => { trackRow(cv, y, i, t[0], t[1], t[2], { showAlbum: true, hover: i === 0 }); y += 54; });
  nowPlayingBar(cv, ['Neon Skyline', 'Midnight Avenue']);
  return cv;
}

// ---------------------------------------------------------------- render all
const screens = [
  ['01-home', renderHome],
  ['02-search', renderSearch],
  ['03-album', renderAlbum],
  ['04-player', renderPlayer],
  ['05-auth', renderAuth],
  ['06-settings', renderSettings],
  ['07-library', renderLibrary],
];
for (const [name, fn] of screens) {
  const cv = fn();
  const png = encodePNG(cv.w, cv.h, cv.d);
  fs.writeFileSync(OUT + '/' + name + '.png', png);
  console.log('wrote', name + '.png', cv.w + 'x' + cv.h, (png.length / 1024).toFixed(0) + 'KB');
}
