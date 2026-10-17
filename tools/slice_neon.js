// Cuts the Neon Gotham sheet (art/sheets/neon_gotham_sheet.png, white backdrop) into game-pixel sprites.
// Run: node tools/slice_neon.js
// Output: assets/sprites/neon/neon_<kind>_<n>.png (alpha cut-outs, 3x box-downsampled) and a bbox list on stdout.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const OUT = path.join(__dirname, "..", "assets", "sprites", "neon");
const im = decodePng(path.join(__dirname, "..", "art", "sheets", "neon_gotham_sheet.png"));
const { w: W, h: H, d } = im;
fs.mkdirSync(OUT, { recursive: true });
for (const f of fs.readdirSync(OUT)) if (f.endsWith(".png") || f.endsWith(".png.import")) fs.unlinkSync(path.join(OUT, f));

const FACTOR = 3;
const STEP = 8;

// The sheet is a real RGBA image: transparent (alpha ~0) outside the sprites.
const bg = new Uint8Array(W * H);
for (let i = 0; i < W * H; i++) bg[i] = d[i * 4 + 3] < 96 ? 1 : 0;

// Connected components of the foreground (dilated by GAP so thin gaps in one sprite do not split it).
const GAP = 3;
const fg = new Uint8Array(W * H);
for (let i = 0; i < W * H; i++) fg[i] = bg[i] ? 0 : 1;
const dil = new Uint8Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
	if (!fg[y * W + x]) continue;
	for (let dy = -GAP; dy <= GAP; dy++) for (let dx = -GAP; dx <= GAP; dx++) {
		const X = x + dx, Y = y + dy;
		if (X >= 0 && Y >= 0 && X < W && Y < H) dil[Y * W + X] = 1;
	}
}
const label = new Int32Array(W * H);
const comps = [];
for (let s = 0; s < W * H; s++) {
	if (!dil[s] || label[s]) continue;
	const id = comps.length + 1;
	const c = { id, x0: W, y0: H, x1: 0, y1: 0, n: 0 };
	const st = [s];
	label[s] = id;
	while (st.length) {
		const i = st.pop(), x = i % W, y = (i / W) | 0;
		c.n++;
		if (x < c.x0) c.x0 = x; if (x > c.x1) c.x1 = x;
		if (y < c.y0) c.y0 = y; if (y > c.y1) c.y1 = y;
		for (const [nx, ny] of [[x - 1, y], [x + 1, y], [x, y - 1], [x, y + 1]]) {
			if (nx < 0 || ny < 0 || nx >= W || ny >= H) continue;
			const j = ny * W + nx;
			if (dil[j] && !label[j]) { label[j] = id; st.push(j); }
		}
	}
	comps.push(c);
}

// Sheet sections (sheet px). kind is decided by the component's centre.
const SECTIONS = [
	{ kind: "skyline", x0: 0, y0: 50, x1: 1325, y1: 385 },
	{ kind: "sky", x0: 1325, y0: 50, x1: W, y1: 385 },
	{ kind: "tower", x0: 0, y0: 390, x1: 890, y1: 700 },
	{ kind: "roof", x0: 895, y0: 390, x1: W, y1: 700 },
	{ kind: "bridge", x0: 0, y0: 700, x1: 900, y1: 825 },
	{ kind: "platform", x0: 905, y0: 700, x1: W, y1: 825 },
	{ kind: "prop", x0: 0, y0: 825, x1: 825, y1: H },
	{ kind: "window", x0: 825, y0: 840, x1: 1195, y1: H },
	{ kind: "fx", x0: 1195, y0: 840, x1: W, y1: H },
];

const counts = {};
const list = [];
const sprites = [];
const sorted = comps.filter((c) => c.n > 1500 && c.y0 > 45).sort((a, b) => (a.y0 + a.y1) / 2 - (b.y0 + b.y1) / 2 || a.x0 - b.x0);
const rowKey = (c) => Math.round((c.y0 + c.y1) / 2 / 60);
sorted.sort((a, b) => rowKey(a) - rowKey(b) || a.x0 - b.x0);

for (const c of sorted) {
	const cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
	const sec = SECTIONS.find((s) => cx >= s.x0 && cx < s.x1 && cy >= s.y0 && cy < s.y1);
	if (!sec) continue;
	if (sec.kind === "skyline") continue;
	const bw = c.x1 - c.x0 + 1, bh = c.y1 - c.y0 + 1;
	if (bw < 24 || bh < 24) continue;
	const nw = Math.floor(bw / FACTOR), nh = Math.floor(bh / FACTOR);
	const o = Buffer.alloc(nw * nh * 4);
	for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
		let r = 0, g = 0, b = 0, a = 0;
		for (let dy = 0; dy < FACTOR; dy++) for (let dx = 0; dx < FACTOR; dx++) {
			const sx = c.x0 + x * FACTOR + dx, sy = c.y0 + y * FACTOR + dy;
			const i = sy * W + sx;
			if (fg[i] && label[i] === c.id || fg[i] && dil[i]) {
				r += d[i * 4]; g += d[i * 4 + 1]; b += d[i * 4 + 2]; a++;
			}
		}
		const t = (y * nw + x) * 4;
		if (a >= 5) {
			o[t] = Math.min(255, Math.round(r / a / STEP) * STEP);
			o[t + 1] = Math.min(255, Math.round(g / a / STEP) * STEP);
			o[t + 2] = Math.min(255, Math.round(b / a / STEP) * STEP);
			o[t + 3] = 255;
		}
	}
	const n = (counts[sec.kind] = (counts[sec.kind] || 0) + 1) - 1;
	const name = `neon_${sec.kind}_${n}.png`;
	fs.writeFileSync(path.join(OUT, name), encodePng(nw, nh, o));
	sprites.push({ kind: sec.kind, w: nw, h: nh, d: o });
	list.push(`${name} ${nw}x${nh} @${c.x0},${c.y0}`);
}
console.log(list.join("\n"));

// ---------------------------------------------------------------------------------------------
// Parallax background. Every layer is stored at game-pixel size and drawn by Godot at an integer
// scale (BG_SCALE in main.gd = 5): 256x144 * 5 = 1280x720. Buildings are stacked from the bottom edge up to
// the top of the screen so the skyline fills the whole height; deeper layers are hazed toward the fog colour.
const BG = path.join(__dirname, "..", "assets", "sprites", "city_bg");
fs.mkdirSync(BG, { recursive: true });
for (const f of fs.readdirSync(BG)) if (f.endsWith(".png") || f.endsWith(".png.import")) fs.unlinkSync(path.join(BG, f));
const SW = 256, SH = 144;

let seed = 7;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const canvas = (w, h) => ({ w, h, d: Buffer.alloc(w * h * 4) });
const writeBg = (name, img) => {
	fs.writeFileSync(path.join(BG, name), encodePng(img.w, img.h, img.d));
	console.log("city_bg/" + name, img.w + "x" + img.h);
};

const FOG = [14, 48, 20];
// Draw spr into dst at (ox, oy), wrapping in x so strips tile seamlessly. haze 0..1 blends toward FOG.
function put(dst, spr, ox, oy, haze = 0) {
	for (let y = 0; y < spr.h; y++) for (let x = 0; x < spr.w; x++) {
		const s = (y * spr.w + x) * 4;
		if (!spr.d[s + 3]) continue;
		const X = (((ox + x) % dst.w) + dst.w) % dst.w, Y = oy + y;
		if (Y < 0 || Y >= dst.h) continue;
		const t = (Y * dst.w + X) * 4;
		for (let c = 0; c < 3; c++) dst.d[t + c] = Math.round(spr.d[s + c] * (1 - haze) + FOG[c] * haze);
		dst.d[t + 3] = 255;
	}
}

// Make a tower taller by repeating a band of its shaft, keeping the spire on top and the base at the bottom.
function stretch(spr, targetH) {
	if (targetH <= spr.h) return spr;
	const top = Math.floor(spr.h * 0.4), b0 = Math.floor(spr.h * 0.45), bh = Math.max(4, Math.floor(spr.h * 0.2));
	const rows = [];
	for (let y = 0; y < top; y++) rows.push(y);
	for (let i = 0; i < targetH - spr.h; i++) rows.push(b0 + (i % bh));
	for (let y = top; y < spr.h; y++) rows.push(y);
	const o = Buffer.alloc(spr.w * rows.length * 4);
	rows.forEach((sy, y) => spr.d.copy(o, y * spr.w * 4, sy * spr.w * 4, (sy + 1) * spr.w * 4));
	return { w: spr.w, h: rows.length, d: o };
}

const towers = sprites.filter((s) => s.kind === "tower" && s.h >= 38 && s.w >= 10 && s.w <= 50);
const bridges = sprites.filter((s) => s.kind === "bridge" && s.w >= 50);
const skyS = sprites.filter((s) => s.kind === "sky");
const moon = skyS.find((s) => s.w > 24 && s.w < 32 && Math.abs(s.w - s.h) <= 2 && s.w === 27) || skyS[skyS.length - 2];
const clouds = skyS.filter((s) => s.w >= 40 && s.h <= 20);

// Sky: deep green gradient banded in 24 steps, with the moon.
{
	const L = canvas(SW, SH);
	for (let y = 0; y < SH; y++) {
		const t = y / (SH - 1), q = Math.floor(t * t * 24) / 24;
		const top = [4, 14, 8], bot = [18, 60, 22];
		for (let x = 0; x < SW; x++) {
			const o = (y * SW + x) * 4;
			for (let c = 0; c < 3; c++) L.d[o + c] = Math.round(top[c] + (bot[c] - top[c]) * q);
			L.d[o + 3] = 255;
		}
	}
	put(L, moon, 176, 12);
	writeBg("city_bg_sky.png", L);
}

// Clouds: transparent strip that Godot also drifts on its own.
{
	const L = canvas(512, 70);
	const spots = [[10, 6], [120, 24], [230, 4], [330, 30], [430, 12], [70, 44], [270, 50], [380, 52]];
	spots.forEach(([x, y], i) => put(L, clouds[i % clouds.length], x, y, 0.15));
	writeBg("city_bg_clouds.png", L);
}

// Building strips, bottom aligned, filling up to the top of the screen.
function strip(name, width, minH, maxH, haze, bridgeChance, gap) {
	const L = canvas(width, SH);
	let x = -4;
	const placed = [];
	while (x < width - 4) {
		const base = towers[Math.floor(rnd() * towers.length)];
		const h = Math.min(SH + 10, Math.round(minH + rnd() * (maxH - minH)));
		const t = stretch(base, h);
		put(L, t, x, SH - t.h, haze);
		placed.push({ x, w: t.w, h: t.h });
		x += t.w + Math.floor(rnd() * gap) - 1;
	}
	for (let i = 0; i + 1 < placed.length; i++) {
		if (rnd() > bridgeChance) continue;
		const b = bridges[Math.floor(rnd() * bridges.length)];
		const a = placed[i], c = placed[i + 1];
		const bx = Math.round((a.x + a.w + c.x) / 2 - b.w / 2);
		put(L, b, bx, SH - b.h - 12 - Math.floor(rnd() * 40), haze);
	}
	writeBg(name, L);
}
strip("city_bg_far.png", 384, 100, 150, 0.78, 0.0, 5);
strip("city_bg_mid.png", 320, 80, 140, 0.5, 0.25, 8);
strip("city_bg_near.png", 448, 60, 150, 0.3, 0.35, 16);
