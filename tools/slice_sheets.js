// Slices the character sheets in art/sheets into per-frame PNGs in assets/sprites/<group>/.
// Run: node tools/slice_sheets.js
// Every frame in a group is placed on the same canvas, aligned to the feet (or the centre for effects),
// so Godot only needs to centre one sprite on the body. Boxes are [x, y, w, h] in sheet pixels.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const SHEETS = path.join(__dirname, "..", "art", "sheets");
const OUT = path.join(__dirname, "..", "assets", "sprites");

const GROUPS = [
	{
		sheet: "yeral_sheet.png", name: "yeral", scale: 0.32, align: "feet",
		frames: {
			idle_0: [40, 40, 195, 350], idle_1: [295, 45, 185, 340], run: [510, 60, 330, 330],
			announce: [875, 0, 250, 366], point: [1140, 80, 372, 305],
			swing: [10, 405, 330, 345, [[284, 640, 80, 120]]],
			cast: [275, 455, 295, 300, [[270, 440, 80, 125]]], taunt: [718, 430, 194, 325],
			summon: [914, 370, 266, 385],
			dash: [1195, 470, 317, 285],
		},
	},
	{
		sheet: "yeral_sheet.png", name: "yeral_fx", scale: 0.3, align: "center",
		frames: { orb: [572, 525, 143, 105] },
	},
	{
		sheet: "robot_sheet.png", name: "robot", scale: 0.5, align: "feet",
		frames: {
			idle_0: [28, 31, 95, 147], idle_1: [149, 29, 99, 149], idle_2: [265, 33, 91, 145],
			idle_3: [382, 25, 85, 153], idle_4: [494, 25, 94, 154], idle_5: [612, 10, 90, 170],
			idle_6: [729, 25, 99, 155],
			run_0: [39, 201, 128, 153], run_1: [181, 213, 130, 143], run_2: [330, 213, 126, 143],
			run_3: [487, 215, 104, 143], run_4: [621, 198, 108, 160], run_5: [760, 214, 119, 142],
			run_6: [905, 192, 116, 162], run_7: [1056, 192, 119, 158], run_8: [1191, 205, 102, 148],
			warn_0: [23, 386, 118, 157], warn_1: [161, 386, 124, 158], warn_2: [314, 383, 133, 162],
			warn_3: [469, 386, 105, 159],
			shoot_0: [600, 389, 149, 155], shoot_1: [766, 394, 140, 151],
			hurt_0: [1034, 399, 100, 148], hurt_1: [1168, 403, 95, 144], hurt_2: [1289, 392, 95, 153],
			hurt_3: [1405, 384, 91, 161],
			dead_0: [60, 550, 115, 140], dead_1: [215, 550, 140, 140], dead_2: [362, 560, 150, 130],
			dead_3: [526, 575, 142, 115], dead_4: [688, 575, 135, 115],
		},
	},
	{
		sheet: "robot_sheet.png", name: "robot_fx", scale: 0.5, align: "center",
		frames: {
			bolt: [923, 441, 65, 41],
			boom_0: [1163, 704, 50, 47], boom_1: [1231, 698, 54, 53], boom_2: [1303, 688, 61, 65],
			boom_3: [1382, 697, 57, 55], boom_4: [1457, 699, 51, 49],
		},
	},
];

const PAD = 6;
const ALPHA_KEEP = 24;

function crop(im, [bx, by, bw, bh, exclude = []]) {
	const x0 = Math.max(0, bx - PAD), y0 = Math.max(0, by - PAD);
	const x1 = Math.min(im.w, bx + bw + PAD), y1 = Math.min(im.h, by + bh + PAD);
	const w = x1 - x0, h = y1 - y0;
	const d = Buffer.alloc(w * h * 4);
	for (let y = 0; y < h; y++) im.d.copy(d, y * w * 4, ((y0 + y) * im.w + x0) * 4, ((y0 + y) * im.w + x1) * 4);
	// Exclude rects (sheet coordinates) wipe pixels that belong to a neighbouring frame.
	for (const [ex, ey, ew, eh] of exclude) {
		for (let y = Math.max(ey, y0); y < Math.min(ey + eh, y1); y++) {
			for (let x = Math.max(ex, x0); x < Math.min(ex + ew, x1); x++) d[((y - y0) * w + (x - x0)) * 4 + 3] = 0;
		}
	}
	return { w, h, d };
}

// Keeps the largest blob and blobs touching its surroundings; drops fragments of neighbouring sprites.
function clean(f) {
	const { w, h, d } = f;
	const R = 4;
	const solid = (i) => d[i * 4 + 3] > ALPHA_KEEP;
	const mask = new Uint8Array(w * h);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		if (!solid(y * w + x)) continue;
		for (let dy = -R; dy <= R; dy++) for (let dx = -R; dx <= R; dx++) {
			const xx = x + dx, yy = y + dy;
			if (xx >= 0 && yy >= 0 && xx < w && yy < h) mask[yy * w + xx] = 1;
		}
	}
	const lab = new Int32Array(w * h);
	const comps = [];
	for (let s = 0; s < w * h; s++) {
		if (!mask[s] || lab[s]) continue;
		const id = comps.length + 1;
		const c = { id, area: 0, x0: w, y0: h, x1: 0, y1: 0 };
		const st = [s];
		lab[s] = id;
		while (st.length) {
			const p = st.pop(), x = p % w, y = (p / w) | 0;
			if (solid(p)) c.area++;
			c.x0 = Math.min(c.x0, x); c.x1 = Math.max(c.x1, x); c.y0 = Math.min(c.y0, y); c.y1 = Math.max(c.y1, y);
			for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
				const xx = x + dx, yy = y + dy;
				if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
				const q = yy * w + xx;
				if (mask[q] && !lab[q]) { lab[q] = id; st.push(q); }
			}
		}
		comps.push(c);
	}
	if (!comps.length) return f;
	const main = comps.reduce((a, b) => (b.area > a.area ? b : a));
	const M = 20;
	const keep = new Set(comps.filter((c) => c === main || (c.x1 >= main.x0 - M && c.x0 <= main.x1 + M &&
		c.y1 >= main.y0 - M && c.y0 <= main.y1 + M && c.area >= main.area * 0.01)).map((c) => c.id));
	for (let i = 0; i < w * h; i++) if (!keep.has(lab[i])) d[i * 4 + 3] = 0;
	return f;
}

function trim(f) {
	let x0 = f.w, y0 = f.h, x1 = -1, y1 = -1;
	for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) {
		if (f.d[(y * f.w + x) * 4 + 3] > 8) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
	}
	const w = x1 - x0 + 1, h = y1 - y0 + 1;
	const d = Buffer.alloc(w * h * 4);
	for (let y = 0; y < h; y++) f.d.copy(d, y * w * 4, ((y0 + y) * f.w + x0) * 4, ((y0 + y) * f.w + x0 + w) * 4);
	return { w, h, d };
}

// Area-average downscale on premultiplied colour, so edges stay clean without halos.
function scaleDown(f, s) {
	const w = Math.max(1, Math.round(f.w * s)), h = Math.max(1, Math.round(f.h * s));
	const d = Buffer.alloc(w * h * 4);
	const sx = f.w / w, sy = f.h / h;
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		const ya = y * sy, yb = (y + 1) * sy, xa = x * sx, xb = (x + 1) * sx;
		let r = 0, g = 0, b = 0, a = 0, wt = 0;
		for (let py = Math.floor(ya); py < Math.ceil(yb); py++) {
			const wy = Math.min(yb, py + 1) - Math.max(ya, py);
			for (let px = Math.floor(xa); px < Math.ceil(xb); px++) {
				const wx = Math.min(xb, px + 1) - Math.max(xa, px);
				const k = wx * wy, i = (Math.min(py, f.h - 1) * f.w + Math.min(px, f.w - 1)) * 4;
				const al = f.d[i + 3] / 255;
				r += f.d[i] * al * k; g += f.d[i + 1] * al * k; b += f.d[i + 2] * al * k; a += al * k; wt += k;
			}
		}
		const o = (y * w + x) * 4;
		if (a > 0) { d[o] = Math.round(r / a); d[o + 1] = Math.round(g / a); d[o + 2] = Math.round(b / a); }
		d[o + 3] = Math.round((a / wt) * 255);
	}
	return { w, h, d };
}

// Horizontal anchor: the feet centre for characters, the middle for effects.
function anchorX(f, align) {
	if (align === "center") return f.w / 2;
	const from = Math.floor(f.h * 0.85);
	let sum = 0, n = 0;
	for (let y = from; y < f.h; y++) for (let x = 0; x < f.w; x++) {
		if (f.d[(y * f.w + x) * 4 + 3] > 100) { sum += x; n++; }
	}
	return n ? sum / n : f.w / 2;
}

for (const g of GROUPS) {
	const sheet = decodePng(path.join(SHEETS, g.sheet));
	const frames = Object.entries(g.frames).map(([name, box]) => {
		const f = scaleDown(trim(clean(crop(sheet, box))), g.scale);
		return { name, f, ax: anchorX(f, g.align) };
	});
	const half = Math.ceil(Math.max(...frames.map(({ f, ax }) => Math.max(ax, f.w - ax))));
	const cw = half * 2, ch = Math.max(...frames.map(({ f }) => f.h));
	const dir = path.join(OUT, g.name);
	fs.mkdirSync(dir, { recursive: true });
	for (const { name, f, ax } of frames) {
		const d = Buffer.alloc(cw * ch * 4);
		const ox = Math.round(half - ax);
		const oy = g.align === "center" ? Math.floor((ch - f.h) / 2) : ch - f.h;
		for (let y = 0; y < f.h; y++) for (let x = 0; x < f.w; x++) {
			const tx = x + ox;
			if (tx < 0 || tx >= cw) continue;
			f.d.copy(d, ((y + oy) * cw + tx) * 4, (y * f.w + x) * 4, (y * f.w + x) * 4 + 4);
		}
		fs.writeFileSync(path.join(dir, `${g.name}_${name}.png`), encodePng(cw, ch, d));
	}
	console.log(g.name, frames.length, "frames,", cw + "x" + ch);
}
