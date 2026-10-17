// Slices the lair prop sheet (art/sheets/level_sheet.png) into trimmed PNGs in assets/sprites/lair/.
// Run: node tools/slice_lair.js
// Each named region is a rough [x, y, w, h] box in sheet pixels. Whole connected blobs whose centre falls
// inside a region are merged into that prop, so slightly loose boxes never cut a sprite.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const SCALE = 0.6;
const OUT = path.join(__dirname, "..", "assets", "sprites", "lair");

const REGIONS = {
	command_desk: [13, 12, 410, 265],
	desk_monitor: [432, 22, 340, 145],
	desk_banner: [434, 178, 340, 105],
	banner_a: [776, 14, 98, 184],
	banner_b: [879, 14, 70, 178],
	banner_c: [950, 14, 54, 158],
	banner_d: [1004, 14, 64, 178],
	banner_e: [1072, 14, 66, 186],
	books: [788, 210, 80, 80],
	crate_crown: [870, 203, 72, 74],
	cabinet: [942, 188, 64, 94],
	lamp_a: [1006, 186, 68, 96],
	lamp_b: [1054, 170, 54, 146],
	lamp_c: [1110, 204, 34, 96],
	stool: [796, 290, 56, 72],
	desk_small: [858, 282, 64, 74],
	crate_dark: [936, 280, 74, 90],
	lava_lamp: [1008, 284, 58, 116],
	globe: [1068, 322, 78, 84],
	scrolls: [796, 388, 116, 100],
	office_chair: [914, 372, 96, 112],
	plant: [990, 404, 62, 80],
	console: [1050, 404, 94, 82],
	platform_long: [17, 289, 303, 62],
	platform_neon: [334, 289, 168, 64],
	platform_slim: [516, 295, 148, 43],
	platform_truss: [17, 360, 240, 100],
	platform_chain: [270, 358, 102, 116],
	platform_hang: [382, 360, 114, 110],
	platform_moss: [512, 366, 150, 100],
	pillar_dark: [675, 289, 58, 170],
	pillar_glow: [737, 289, 50, 164],
	hologram: [15, 440, 244, 220],
	crown_screen: [286, 483, 218, 168],
	banner_tall_a: [512, 464, 64, 182],
	banner_tall_b: [576, 464, 64, 182],
	banner_short_a: [640, 488, 58, 140],
	banner_short_b: [698, 476, 74, 150],
	ruin_box: [778, 478, 56, 84],
	small_box: [843, 492, 40, 70],
	terminal: [884, 496, 94, 98],
	vat: [982, 486, 162, 132],
	spikes_wide: [17, 676, 208, 76],
	spikes_a: [229, 662, 98, 90],
	spikes_b: [327, 668, 104, 84],
	spikes_c: [435, 656, 96, 96],
	spikes_d: [528, 668, 96, 84],
	spikes_e: [616, 668, 102, 84],
	beam_arrow: [820, 592, 76, 160],
	crown_hologram: [898, 622, 128, 130],
	data_pillar: [1028, 606, 120, 146],
};

const im = decodePng(path.join(__dirname, "..", "art", "sheets", "level_sheet.png"));
const { w: W, h: H, d } = im;
const R = 2;

const solid = (x, y) => d[(y * W + x) * 4 + 3] > 60;
const mask = new Uint8Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
	if (!solid(x, y)) continue;
	for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) {
		const xx = x + dx, yy = y + dy;
		if (xx >= 0 && yy >= 0 && xx < W && yy < H) mask[yy * W + xx] = 1;
	}
}
const lab = new Int32Array(W * H);
const comps = [];
for (let s = 0; s < W * H; s++) {
	if (!mask[s] || lab[s]) continue;
	const id = comps.length + 1;
	const c = { id, area: 0, x0: W, y0: H, x1: 0, y1: 0 };
	const st = [s];
	lab[s] = id;
	while (st.length) {
		const p = st.pop(), x = p % W, y = (p / W) | 0;
		if (solid(x, y)) c.area++;
		c.x0 = Math.min(c.x0, x); c.x1 = Math.max(c.x1, x); c.y0 = Math.min(c.y0, y); c.y1 = Math.max(c.y1, y);
		for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
			const xx = x + dx, yy = y + dy;
			if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue;
			const q = yy * W + xx;
			if (mask[q] && !lab[q]) { lab[q] = id; st.push(q); }
		}
	}
	comps.push(c);
}

// Assign each blob to the region containing its centre; tiny specks are ignored.
const owner = new Map();
const names = Object.keys(REGIONS);
const assigned = new Set();
for (const c of comps) {
	if (c.area < 12) continue;
	const cx = (c.x0 + c.x1) / 2, cy = (c.y0 + c.y1) / 2;
	let best = null, bestD = Infinity;
	for (const n of names) {
		const [x, y, w, h] = REGIONS[n];
		if (cx < x || cx > x + w || cy < y || cy > y + h) continue;
		const dist = Math.hypot(cx - (x + w / 2), cy - (y + h / 2));
		if (dist < bestD) { bestD = dist; best = n; }
	}
	if (best) { owner.set(c.id, best); assigned.add(c.id); }
	else if (c.area > 150) console.log("unassigned blob", c.x0, c.y0, c.x1 - c.x0 + 1, c.y1 - c.y0 + 1, "area", c.area);
}

fs.mkdirSync(OUT, { recursive: true });
for (const n of names) {
	const mine = comps.filter((c) => owner.get(c.id) === n);
	if (!mine.length) { console.log("EMPTY region", n); continue; }
	const G = 6;
	const x0 = Math.max(0, Math.min(...mine.map((c) => c.x0)) - G), y0 = Math.max(0, Math.min(...mine.map((c) => c.y0)) - G);
	const x1 = Math.min(W - 1, Math.max(...mine.map((c) => c.x1)) + G), y1 = Math.min(H - 1, Math.max(...mine.map((c) => c.y1)) + G);
	const w = x1 - x0 + 1, h = y1 - y0 + 1;
	const f = Buffer.alloc(w * h * 4);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		const si = (y0 + y) * W + x0 + x;
		const l = lab[si];
		// Own blob pixels, plus unlabelled glow that is not owned by another prop.
		if (d[si * 4 + 3] > 4 && (owner.get(l) === n || (!l))) d.copy(f, (y * w + x) * 4, si * 4, si * 4 + 4);
	}
	// Trim and downscale (premultiplied area average).
	let tx0 = w, ty0 = h, tx1 = -1, ty1 = -1;
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (f[(y * w + x) * 4 + 3] > 8) {
		tx0 = Math.min(tx0, x); tx1 = Math.max(tx1, x); ty0 = Math.min(ty0, y); ty1 = Math.max(ty1, y);
	}
	const cw = tx1 - tx0 + 1, ch = ty1 - ty0 + 1;
	const nw = Math.max(1, Math.round(cw * SCALE)), nh = Math.max(1, Math.round(ch * SCALE));
	const out = Buffer.alloc(nw * nh * 4);
	const sx = cw / nw, sy = ch / nh;
	for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
		const ya = y * sy, yb = (y + 1) * sy, xa = x * sx, xb = (x + 1) * sx;
		let r = 0, g = 0, b = 0, a = 0, wt = 0;
		for (let py = Math.floor(ya); py < Math.ceil(yb); py++) {
			const wy = Math.min(yb, py + 1) - Math.max(ya, py);
			for (let px = Math.floor(xa); px < Math.ceil(xb); px++) {
				const wx = Math.min(xb, px + 1) - Math.max(xa, px);
				const k = wx * wy, i = ((ty0 + Math.min(py, ch - 1)) * w + tx0 + Math.min(px, cw - 1)) * 4;
				const al = f[i + 3] / 255;
				r += f[i] * al * k; g += f[i + 1] * al * k; b += f[i + 2] * al * k; a += al * k; wt += k;
			}
		}
		const o = (y * nw + x) * 4;
		if (a > 0) { out[o] = Math.round(r / a); out[o + 1] = Math.round(g / a); out[o + 2] = Math.round(b / a); }
		out[o + 3] = Math.round((a / wt) * 255);
	}
	fs.writeFileSync(path.join(OUT, `lair_${n}.png`), encodePng(nw, nh, out));
	console.log(n, nw + "x" + nh, mine.length, "blobs");
}
