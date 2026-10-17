// Cuts the Spoiler Man Gotham sheet (art/sheets/spoiler_gotham_sheet.png, opaque dark-green backdrop).
// Run: node tools/slice_gotham.js
// Output:
//   assets/sprites/city_bg/city_bg_panorama.png - the sheet's painted skyline, copied pixel-for-pixel (no recolour/resample)
//   assets/sprites/city_bg/city_bg_sky.png      - plain gradient that fills above the panorama
//   assets/sprites/gotham/gotham_<kind>_<n>.png - cut-out towers, roofs, bridges, platforms, props, windows, ground
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const ROOT = path.join(__dirname, "..");
const OUT = path.join(ROOT, "assets", "sprites", "gotham");
const BG = path.join(ROOT, "assets", "sprites", "city_bg");
const im = decodePng(path.join(ROOT, "art", "sheets", "spoiler_gotham_sheet.png"));
const { w: W, h: H, d } = im;
for (const dir of [OUT, BG]) {
	fs.mkdirSync(dir, { recursive: true });
	for (const f of fs.readdirSync(dir)) if (f.endsWith(".png") || f.endsWith(".png.import")) fs.unlinkSync(path.join(dir, f));
}

// ---- Background: untouched crop of the painted skyline -------------------------------------------------------
// Starts right of the sheet's title text. Drawn by main.gd at 2x with nearest filtering.
const PX = { x0: 263, y0: 46, w: 1021, h: 322 };
{
	const o = Buffer.alloc(PX.w * PX.h * 4);
	for (let y = 0; y < PX.h; y++) for (let x = 0; x < PX.w; x++) {
		const s = ((PX.y0 + y) * W + PX.x0 + x) * 4;
		d.copy(o, (y * PX.w + x) * 4, s, s + 3);
		o[(y * PX.w + x) * 4 + 3] = 255;
	}
	fs.writeFileSync(path.join(BG, "city_bg_panorama.png"), encodePng(PX.w, PX.h, o));
	console.log("city_bg_panorama.png", PX.w + "x" + PX.h);

	// Sky strip: starts at the panorama's top-row colour and lightens slightly toward the horizon.
	const sw = 64, sh = 72, top = [3, 14, 9], bot = [6, 22, 12], s = Buffer.alloc(sw * sh * 4);
	for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
		for (let c = 0; c < 3; c++) s[(y * sw + x) * 4 + c] = Math.round(top[c] + (bot[c] - top[c]) * (y / (sh - 1)));
		s[(y * sw + x) * 4 + 3] = 255;
	}
	fs.writeFileSync(path.join(BG, "city_bg_sky.png"), encodePng(sw, sh, s));
	console.log("city_bg_sky.png", sw + "x" + sh);
}

// ---- Cut-out sprites -------------------------------------------------------------------------------------------
const FACTOR = 3;
const STEP = 8;

// Sprite mask: the backdrop is dark green smoke (low red); sprites have olive/gold trim and bright windows.
const fg = new Uint8Array(W * H);
for (let i = 0; i < W * H; i++) fg[i] = d[i * 4] >= 26 || d[i * 4 + 1] > 150 ? 1 : 0;

// Closing (dilate then erode by GAP) joins each sprite and fills small holes; components are the dilated blobs.
const GAP = 3;
const dil = new Uint8Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
	if (!fg[y * W + x]) continue;
	for (let dy = -GAP; dy <= GAP; dy++) for (let dx = -GAP; dx <= GAP; dx++) {
		const X = x + dx, Y = y + dy;
		if (X >= 0 && Y >= 0 && X < W && Y < H) dil[Y * W + X] = 1;
	}
}
const closed = new Uint8Array(W * H);
for (let y = GAP; y < H - GAP; y++) for (let x = GAP; x < W - GAP; x++) {
	if (!dil[y * W + x]) continue;
	let ok = 1;
	for (let dy = -GAP; dy <= GAP && ok; dy++) for (let dx = -GAP; dx <= GAP; dx++) {
		if (!dil[(y + dy) * W + x + dx]) { ok = 0; break; }
	}
	closed[y * W + x] = ok;
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
	{ kind: "tower", x0: 0, y0: 380, x1: 905, y1: 640 },
	{ kind: "roof", x0: 905, y0: 380, x1: W, y1: 640 },
	{ kind: "bridge", x0: 0, y0: 640, x1: 920, y1: 765 },
	{ kind: "platform", x0: 920, y0: 640, x1: W, y1: 765 },
	{ kind: "prop", x0: 0, y0: 765, x1: 810, y1: 925 },
	{ kind: "window", x0: 810, y0: 770, x1: 1160, y1: 935 },
	{ kind: "ground", x0: 0, y0: 935, x1: 985, y1: H },
];

const counts = {};
const rowKey = (c) => Math.round((c.y0 + c.y1) / 2 / 60);
const sorted = comps.filter((c) => c.n > 1500 && c.y0 > 45).sort((a, b) => rowKey(a) - rowKey(b) || a.x0 - b.x0);

for (const c of sorted) {
	const cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
	const sec = SECTIONS.find((s) => cx >= s.x0 && cx < s.x1 && cy >= s.y0 && cy < s.y1);
	if (!sec) continue;
	const bw = c.x1 - c.x0 + 1, bh = c.y1 - c.y0 + 1;
	if (bw < 24 || bh < 24) continue;
	const nw = Math.floor(bw / FACTOR), nh = Math.floor(bh / FACTOR);
	const o = Buffer.alloc(nw * nh * 4);
	for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
		let r = 0, g = 0, b = 0, a = 0;
		for (let dy = 0; dy < FACTOR; dy++) for (let dx = 0; dx < FACTOR; dx++) {
			const sx = c.x0 + x * FACTOR + dx, sy = c.y0 + y * FACTOR + dy;
			const i = sy * W + sx;
			if (closed[i] && label[i] === c.id) {
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
	if (["tower", "roof", "prop"].includes(sec.kind)) {
		// Solid silhouette: fill holes between the first and last opaque pixel of each row.
		for (let y = 0; y < nh; y++) {
			let a = -1, b = -1;
			for (let x = 0; x < nw; x++) if (o[(y * nw + x) * 4 + 3]) { if (a < 0) a = x; b = x; }
			for (let x = a; a >= 0 && x <= b; x++) {
				const t = (y * nw + x) * 4;
				if (!o[t + 3]) { o[t] = 8; o[t + 1] = 24; o[t + 2] = 8; o[t + 3] = 255; }
			}
		}
	}
	const n = (counts[sec.kind] = (counts[sec.kind] || 0) + 1) - 1;
	fs.writeFileSync(path.join(OUT, `gotham_${sec.kind}_${n}.png`), encodePng(nw, nh, o));
}
console.log("sprites:", JSON.stringify(counts));
