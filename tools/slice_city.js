// Builds the Yeral city background layers and sprites from art/sheets/city_sheet.png (opaque sheet).
// Run: node tools/slice_city.js
// Output (assets/sprites/city/): city_bg_far/mid/near.png parallax layers and city_<section>_<n>.png cut-outs.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const OUT = path.join(__dirname, "..", "assets", "sprites", "city");
const im = decodePng(path.join(__dirname, "..", "art", "sheets", "city_sheet.png"));
const { w: W, h: H, d } = im;
const BG = path.join(__dirname, "..", "assets", "sprites", "city_bg");
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(BG, { recursive: true });

const px = (x, y) => { const i = (y * W + x) * 4; return [d[i], d[i + 1], d[i + 2]]; };

// Crop a sheet rect to RGBA, nearest-scaled by k.
function crop(x0, y0, w, h, k = 1) {
	const nw = Math.round(w * k), nh = Math.round(h * k);
	const o = Buffer.alloc(nw * nh * 4);
	for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
		const si = (Math.min(H - 1, y0 + Math.floor(y / k)) * W + Math.min(W - 1, x0 + Math.floor(x / k))) * 4;
		d.copy(o, (y * nw + x) * 4, si, si + 4);
	}
	return { w: nw, h: nh, d: o };
}

const mirrorTile = (c) => {
	const o = Buffer.alloc(c.w * 2 * c.h * 4);
	for (let y = 0; y < c.h; y++) for (let x = 0; x < c.w; x++) {
		const si = (y * c.w + x) * 4;
		c.d.copy(o, (y * c.w * 2 + x) * 4, si, si + 4);
		c.d.copy(o, (y * c.w * 2 + (c.w * 2 - 1 - x)) * 4, si, si + 4);
	}
	return { w: c.w * 2, h: c.h, d: o };
};

function blit(dst, src, ox, oy, alphaFn) {
	for (let y = 0; y < src.h; y++) for (let x = 0; x < src.w; x++) {
		const X = ox + x, Y = oy + y;
		if (X < 0 || Y < 0 || X >= dst.w || Y >= dst.h) continue;
		const s = (y * src.w + x) * 4, t = (Y * dst.w + X) * 4;
		const a = (alphaFn ? alphaFn(x, y, src.d, s) : src.d[s + 3] / 255);
		for (let c = 0; c < 3; c++) dst.d[t + c] = Math.round(src.d[s + c] * a + dst.d[t + c] * (1 - a));
		dst.d[t + 3] = Math.max(dst.d[t + 3], Math.round(a * 255));
	}
}

const write = (name, img) => {
	fs.writeFileSync(path.join(BG, name), encodePng(img.w, img.h, img.d));
	console.log(name, img.w + "x" + img.h);
};

// Far layer: night sky gradient, cloud banks and the moon (screen space, 1280x720 repeating).
{
	const L = { w: 1280, h: 720, d: Buffer.alloc(1280 * 720 * 4) };
	const top = [4, 14, 8], bot = [18, 60, 22];
	for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) {
		const t = y / L.h, o = (y * L.w + x) * 4;
		for (let c = 0; c < 3; c++) L.d[o + c] = Math.round(top[c] + (bot[c] - top[c]) * t * t);
		L.d[o + 3] = 255;
	}
	const fade = null;
	void fade;
	// Clouds: soft-edged by distance to the crop border.
	const cloud = (sx, sy, sw, sh, ox, oy, k) => {
		const c = crop(sx, sy, sw, sh, k);
		blit(L, c, ox, oy, (x, y, sd, i) => {
			const e = Math.min(x, y, c.w - 1 - x, c.h - 1 - y) / 24;
			const lum = Math.max(sd[i], sd[i + 1], sd[i + 2]);
			return Math.min(1, e) * Math.min(1, Math.max(0, (lum - 45) / 60));
		});
	};
	cloud(972, 54, 166, 50, 40, 60, 2.6);
	cloud(972, 92, 166, 50, 560, 150, 2.4);
	cloud(972, 132, 166, 50, 880, 40, 2.2);
	cloud(972, 172, 88, 26, 200, 250, 2.6);
	write("city_bg_far.png", L);
}

// Mid layer: the skyline panorama (mirrored so it tiles), top edge fading into the sky.
{
	const p = mirrorTile(crop(14, 64, 948, 211, 1.7));
	const fadeH = 70;
	for (let y = 0; y < p.h; y++) for (let x = 0; x < p.w; x++) {
		p.d[(y * p.w + x) * 4 + 3] = y < fadeH ? Math.round(255 * (y / fadeH)) : 255;
	}
	write("city_bg_mid.png", p);
}

// Near layer: low fog and silhouette skyline, alpha from brightness so only glow and shapes remain.
{
	const n = mirrorTile(crop(880, 592, 270, 175, 2.2));
	for (let y = 0; y < n.h; y++) for (let x = 0; x < n.w; x++) {
		const i = (y * n.w + x) * 4;
		const lum = Math.max(n.d[i], n.d[i + 1], n.d[i + 2]);
		const edge = Math.min(1, y / 40);
		n.d[i + 3] = Math.round(Math.min(1, lum / 70) * edge * 235);
	}
	write("city_bg_near.png", n);
}

// Cut-outs: flood-fill the dark sheet background from the box border, then split into blobs.
const SECTIONS = {
	tower: [10, 290, 1140, 190],
	bridge: [10, 486, 600, 80],
	platform: [695, 486, 440, 92],
	prop: [10, 574, 600, 120],
	window: [620, 594, 250, 105],
	ground: [10, 706, 720, 50],
};
const DARK = 48;
for (const [name, [bx, by, bw, bh]] of Object.entries(SECTIONS)) {
	const bg = new Uint8Array(bw * bh);
	const isDark = (x, y) => { const [r, g, b] = px(bx + x, by + y); return Math.max(r, g, b) < DARK; };
	const st = [];
	for (let x = 0; x < bw; x++) { st.push([x, 0], [x, bh - 1]); }
	for (let y = 0; y < bh; y++) { st.push([0, y], [bw - 1, y]); }
	while (st.length) {
		const [x, y] = st.pop();
		if (x < 0 || y < 0 || x >= bw || y >= bh || bg[y * bw + x] || !isDark(x, y)) continue;
		bg[y * bw + x] = 1;
		st.push([x + 1, y], [x - 1, y], [x, y + 1], [x, y - 1]);
	}
	// Blob labelling with dilation so windows/antennas stay attached.
	const R = 2;
	const fg = new Uint8Array(bw * bh);
	for (let y = 0; y < bh; y++) for (let x = 0; x < bw; x++) {
		if (bg[y * bw + x]) continue;
		for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) {
			const xx = x + dx, yy = y + dy;
			if (xx >= 0 && yy >= 0 && xx < bw && yy < bh) fg[yy * bw + xx] = 1;
		}
	}
	const lab = new Int32Array(bw * bh);
	const comps = [];
	for (let s = 0; s < bw * bh; s++) {
		if (!fg[s] || lab[s]) continue;
		const c = { id: comps.length + 1, x0: bw, y0: bh, x1: 0, y1: 0, area: 0 };
		const q = [s];
		lab[s] = c.id;
		while (q.length) {
			const p = q.pop(), x = p % bw, y = (p / bw) | 0;
			if (!bg[p]) c.area++;
			c.x0 = Math.min(c.x0, x); c.x1 = Math.max(c.x1, x); c.y0 = Math.min(c.y0, y); c.y1 = Math.max(c.y1, y);
			for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				const xx = x + dx, yy = y + dy;
				if (xx < 0 || yy < 0 || xx >= bw || yy >= bh) continue;
				const k = yy * bw + xx;
				if (fg[k] && !lab[k]) { lab[k] = c.id; q.push(k); }
			}
		}
		comps.push(c);
	}
	const keep = comps.filter((c) => c.area > 300 && c.x1 - c.x0 > 14 && c.y1 - c.y0 > 10)
		.sort((a, b) => a.y0 - b.y0 > 40 ? 1 : (b.y0 - a.y0 > 40 ? -1 : a.x0 - b.x0));
	// Rows first (by y band), then left to right.
	keep.sort((a, b) => (Math.round(a.y0 / 60) - Math.round(b.y0 / 60)) || (a.x0 - b.x0));
	keep.forEach((c, i) => {
		const w = c.x1 - c.x0 + 1, h = c.y1 - c.y0 + 1;
		const o = Buffer.alloc(w * h * 4);
		for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
			const sx = c.x0 + x, sy = c.y0 + y;
			if (lab[sy * bw + sx] !== c.id) continue;
			d.copy(o, (y * w + x) * 4, ((by + sy) * W + bx + sx) * 4, ((by + sy) * W + bx + sx) * 4 + 4);
			o[(y * w + x) * 4 + 3] = 255;
		}
		const file = `city_${name}_${i}.png`;
		fs.writeFileSync(path.join(OUT, file), encodePng(w, h, o));
	});
	console.log(name, keep.length, "sprites");
}
