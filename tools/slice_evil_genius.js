// Slices art/sheets/evil_genius_sheet.png (opaque, near-black backdrop) into transparent sprites.
//   node tools/slice_evil_genius.js          -> assets/sprites/evil_genius/evil_genius_<pose>.png (shared canvas, feet-aligned)
//                                               assets/sprites/evil_genius_fx/evil_genius_fx_lawyer.png
//                                               assets/sprites/bichema/bichema_<holo>.png (hologram panels, recolored red)
//                                               assets/sprites/truffle_android/truffle_android_<anim>_<n>.png (mob frames, half resolution)
// The boss art itself is never recolored or resampled.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode.js");

const ROOT = path.join(__dirname, "..");
const SHEET = path.join(ROOT, "art", "sheets", "evil_genius_sheet.png");
const SPRITES = path.join(ROOT, "assets", "sprites");
const img = decodePng(SHEET);
const { w, h, d } = img;
const mx = (i) => Math.max(d[i], d[i + 1], d[i + 2]);

// Backdrop = near-black pixels connected to the sheet border, so the black coat stays opaque.
const bg = new Uint8Array(w * h);
{
	const st = [];
	const push = (x, y) => {
		if (x < 0 || y < 0 || x >= w || y >= h) return;
		const p = y * w + x;
		if (bg[p] || mx(p * 4) > 9) return;
		bg[p] = 1;
		st.push(p);
	};
	for (let x = 0; x < w; x++) { push(x, 0); push(x, h - 1); }
	for (let y = 0; y < h; y++) { push(0, y); push(w - 1, y); }
	while (st.length) {
		const p = st.pop(), x = p % w, y = (p / w) | 0;
		push(x - 1, y); push(x + 1, y); push(x, y - 1); push(x, y + 1);
	}
}
const alpha = new Uint8Array(w * h);
for (let p = 0; p < w * h; p++) alpha[p] = bg[p] ? 0 : 255;
// Soft rim: dim glow pixels within 2px of the backdrop fade out instead of leaving a dark fringe.
{
	let front = [];
	for (let p = 0; p < w * h; p++) if (bg[p]) front.push(p);
	const seen = new Uint8Array(w * h);
	for (let step = 0; step < 2; step++) {
		const next = [];
		for (const p of front) {
			const x = p % w, y = (p / w) | 0;
			for (const q of [p - 1, p + 1, p - w, p + w]) {
				if (q < 0 || q >= w * h || bg[q] || seen[q] || (q % w === 0 && x === w - 1) || (q % w === w - 1 && x === 0)) continue;
				seen[q] = 1;
				const m = mx(q * 4);
				if (m < 40) { alpha[q] = Math.round(Math.max(0, (m - 9) / 31) * 255); next.push(q); }
			}
		}
		front = next;
	}
}
// Label connected pieces (4-neighbour, small gap bridged by dilation).

const solid = new Uint8Array(w * h);
for (let p = 0; p < w * h; p++) solid[p] = alpha[p] > 90 ? 1 : 0;
function dilate(src, R = 5) {
	const a = new Uint8Array(w * h), b = new Uint8Array(w * h);
	for (let y = 0; y < h; y++) {
		let last = -1e9;
		for (let x = 0; x < w; x++) { if (src[y * w + x]) last = x; if (x - last <= R) a[y * w + x] = 1; }
		last = 1e9;
		for (let x = w - 1; x >= 0; x--) { if (src[y * w + x]) last = x; if (last - x <= R) a[y * w + x] = 1; }
	}
	for (let x = 0; x < w; x++) {
		let last = -1e9;
		for (let y = 0; y < h; y++) { if (a[y * w + x]) last = y; if (y - last <= R) b[y * w + x] = 1; }
		last = 1e9;
		for (let y = h - 1; y >= 0; y--) { if (a[y * w + x]) last = y; if (last - y <= R) b[y * w + x] = 1; }
	}
	return b;
}
const dil = dilate(solid);
const lab = new Int32Array(w * h);
const comps = [];
for (let s = 0; s < w * h; s++) {
	if (!dil[s] || lab[s]) continue;
	const id = comps.length + 1, st = [s];
	lab[s] = id;
	const c = { id, x0: w, y0: h, x1: 0, y1: 0, n: 0, sx: 0, sy: 0 };
	while (st.length) {
		const p = st.pop(), x = p % w, y = (p / w) | 0;
		c.n++; c.sx += x; c.sy += y;
		if (x < c.x0) c.x0 = x; if (x > c.x1) c.x1 = x; if (y < c.y0) c.y0 = y; if (y > c.y1) c.y1 = y;
		for (const q of [p - 1, p + 1, p - w, p + w]) {
			if (q >= 0 && q < w * h && dil[q] && !lab[q]) { lab[q] = id; st.push(q); }
		}
	}
	c.cx = c.sx / c.n; c.cy = c.sy / c.n;
	comps.push(c);
}
const real = comps.filter((c) => c.n > 150);

if (process.argv[2] === "--list") {
	for (const c of real) console.log(c.id, "bbox", c.x0, c.y0, c.x1, c.y1, "n", c.n, "centroid", Math.round(c.cx), Math.round(c.cy));
	process.exit(0);
}

// Pose zones (x ranges per row, split at y = 470); poses listed in game order.
const ROW_Y = 470;
const POSES = [
	{ name: "idle", row: 0, x: [0, 300], feetY: 446 },
	{ name: "staff", row: 0, x: [300, 830], feetY: 446 },
	{ name: "run", row: 0, x: [830, 1280], feetY: 446, band: 90 },
	{ name: "jump", row: 0, x: [1280, w], feetY: 446, band: 150 },
	{ name: "point", row: 1, x: [0, 412], feetY: 854 },
	{ name: "blast", row: 1, x: [412, 875], feetY: 854 },
	{ name: "shield", row: 1, x: [875, 1255], feetY: 854 },
	{ name: "hurt", row: 1, x: [1255, w], feetY: 854 },
];
// Cut between the Evil Genius (paper burst up top, boots down low) and the glowing lawyer.
const lawyerCut = (y) => (y > 700 ? 1565 : 1535);

function mask(poseComps, extra) {
	const ids = new Set(poseComps.map((c) => c.id));
	return (x, y) => {
		const L = lab[y * w + x];
		return L && ids.has(L) && (!extra || extra(x, y));
	};
}

function writeCrop(file, x0, y0, cw, ch, keep, ox, oy, outW, outH, buf) {
	for (let y = 0; y < ch; y++) {
		for (let x = 0; x < cw; x++) {
			const sx = x0 + x, sy = y0 + y;
			if (sx < 0 || sy < 0 || sx >= w || sy >= h || !keep(sx, sy) || !alpha[sy * w + sx]) continue;
			const si = (sy * w + sx) * 4, di = ((oy + y) * outW + ox + x) * 4;
			buf[di] = d[si]; buf[di + 1] = d[si + 1]; buf[di + 2] = d[si + 2]; buf[di + 3] = alpha[sy * w + sx];
		}
	}
}

const placed = POSES.map((p) => {
	const cs = real.filter((c) => (c.cy < ROW_Y ? 0 : 1) === p.row && c.cx >= p.x[0] && c.cx < p.x[1]);
	return { p, cs };
});
// Hurt pose: the lawyer is its own asset.
const hurt = placed.find((e) => e.p.name === "hurt");
const lawyerKeep = (x, y) => x >= lawyerCut(y);
const bodyKeep = (x, y) => x < lawyerCut(y);

let fL = 0, fR = 0, fH = 0;
for (const e of placed) {
	e.keep = e === hurt ? mask(e.cs, bodyKeep) : mask(e.cs);
	let x0 = w, x1 = 0, y0 = h;
	for (const c of e.cs) {
		x0 = Math.min(x0, c.x0); x1 = Math.max(x1, e === hurt ? Math.min(c.x1, 1564) : c.x1); y0 = Math.min(y0, c.y0);
	}
	// Feet x = centre of the boot pixels (the lowest 30 rows of the opaque figure, excluding fx to the sides).
	let sx = 0, n = 0;
	for (let y = e.p.feetY - (e.p.band || 30); y <= e.p.feetY; y++) {
		for (let x = x0; x <= x1; x++) {
			const i = (y * w + x) * 4;
			if (alpha[y * w + x] === 255 && e.keep(x, y) && !(d[i + 1] > 150 && d[i] < 120)) { sx += x; n++; }
		}
	}
	e.feetX = n ? Math.round(sx / n) : (x0 + x1) >> 1;
	e.box = { x0, x1, y0 };
	fL = Math.max(fL, e.feetX - x0); fR = Math.max(fR, x1 - e.feetX); fH = Math.max(fH, e.p.feetY - y0);
}
const half = Math.max(fL, fR) + 6, CW = half * 2, CH = fH + 12;
const bossDir = path.join(SPRITES, "evil_genius");
fs.rmSync(bossDir, { recursive: true, force: true });
fs.mkdirSync(bossDir, { recursive: true });
for (const e of placed) {
	const buf = Buffer.alloc(CW * CH * 4);
	const ox = half - (e.feetX - e.box.x0), oy = CH - 4 - (e.p.feetY - e.box.y0);
	writeCrop(null, e.box.x0, e.box.y0, e.box.x1 - e.box.x0 + 1, e.p.feetY - e.box.y0 + 8, e.keep, ox, oy, CW, CH, buf);
	fs.writeFileSync(path.join(bossDir, `evil_genius_${e.p.name}.png`), encodePng(CW, CH, buf));
}
console.log(`evil_genius frames: ${placed.length}, canvas ${CW}x${CH}, feet at (${half}, ${CH - 4})`);

// Lawyer (weakness) as a standalone FX sprite.
{
	const lc = hurt.cs;
	const ids = new Set(lc.map((c) => c.id));
	let x0 = w, x1 = 0, y0 = h, y1 = 0;
	for (let y = 0; y < h; y++) {
		for (let x = lawyerCut(y); x < w; x++) {
			if (ids.has(lab[y * w + x]) && alpha[y * w + x]) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
		}
	}
	const buf = Buffer.alloc((x1 - x0 + 1) * (y1 - y0 + 1) * 4);
	writeCrop(null, x0, y0, x1 - x0 + 1, y1 - y0 + 1, mask(lc, lawyerKeep), 0, 0, x1 - x0 + 1, y1 - y0 + 1, buf);
	const dir = path.join(SPRITES, "evil_genius_fx");
	fs.mkdirSync(dir, { recursive: true });
	fs.writeFileSync(path.join(dir, "evil_genius_fx_lawyer.png"), encodePng(x1 - x0 + 1, y1 - y0 + 1, buf));
	console.log("lawyer", x1 - x0 + 1, y1 - y0 + 1);
}

// Hologram panels: pieces of the idle/staff/point poses that float beside the figure, recolored red for Bichema's World.
const HOLO = [
	// name, hint box in sheet coordinates (read off the staff and point poses)
	["chart", [378, 36, 478, 130]],
	["capitol", [363, 130, 452, 216]],
	["chip", [360, 218, 452, 316]],
	["sports", [700, 106, 774, 226]],
	["globe", [683, 244, 762, 332]],
	["graph", [10, 490, 114, 590]],
	["debate", [248, 493, 374, 582]],
	["sports2", [10, 596, 87, 722]],
	["bars", [243, 663, 304, 727]],
	["chip2", [310, 648, 402, 742]],
];const holoDir = path.join(SPRITES, "bichema");
fs.rmSync(holoDir, { recursive: true, force: true });
fs.mkdirSync(holoDir, { recursive: true });

for (const [name, [hx0, hy0, hx1, hy1]] of HOLO) {
	const keep = [];
	let x0 = w, y0 = h, x1 = 0, y1 = 0;
	for (let y = hy0; y <= hy1; y++) {
		for (let x = hx0; x <= hx1; x++) {
			const p = y * w + x, i = p * 4;
			if (!alpha[p]) continue;
			const glow = d[i + 1] >= 18 && d[i + 1] >= d[i] * 1.15 && d[i + 1] >= d[i + 2];
			if (!glow && mx(i) >= 60) continue; // skip skin, coat and gold trim
			keep.push(p);
			x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y);
		}
	}
	const cw = x1 - x0 + 1, ch = y1 - y0 + 1;
	const buf = Buffer.alloc(cw * ch * 4);
	for (const p of keep) {
		const x = (p % w) - x0, y = ((p / w) | 0) - y0, i = p * 4, di = (y * cw + x) * 4;
		const r = d[i], g = d[i + 1], b = d[i + 2];
		// green glow -> red glow
		buf[di] = Math.min(255, Math.round(g * 1.05)); buf[di + 1] = Math.round(r * 0.3 + b * 0.25); buf[di + 2] = Math.round(b * 0.5);
		buf[di + 3] = alpha[p];
	}
	fs.writeFileSync(path.join(holoDir, `bichema_holo_${name}.png`), encodePng(cw, ch, buf));
}
console.log("holo panels:", HOLO.length);
// ---- Truffle androids: the Evil Genius art with a truffle head, steel skin and red glow, at half resolution ----
const MOB = [
	// anim frame name, source pose, excluded boxes [x0, y0, x1, y1], optional dy shift
	{ name: "idle_0", src: "idle" },
	{ name: "idle_1", src: "idle", dy: 6 },
	{ name: "run_0", src: "run" },
	{ name: "run_1", src: "run", dy: -8 },
	{ name: "warn_0", src: "point", ex: HOLO.filter((hh) => hh[1][1] > 470).map(([, [a, b, c, dd]]) => [a - 2, b - 2, c + 2, dd + 2]),
		soft: HOLO.filter((hh) => hh[1][1] > 470).map(([, [a, b, c, dd]]) => [a - 18, b - 18, c + 18, dd + 18]) },
	{ name: "shoot_0", src: "blast", ex: [[632, 400, w, h], [560, 480, 632, 545]] },
	{ name: "hurt_0", src: "hurt", ex: [[1400, 470, 1564, 650]], soft: [[1350, 470, 1400, 650]] },
	{ name: "dead_0", src: "hurt", ex: [[1400, 470, 1564, 650]], soft: [[1350, 470, 1400, 650]], drop: 0.3, dy: 14 },
	{ name: "dead_1", src: "hurt", ex: [[1400, 470, 1564, 650]], soft: [[1350, 470, 1400, 650]], drop: 0.6, dy: 30 },
	{ name: "dead_2", src: "hurt", ex: [[1400, 470, 1564, 650]], soft: [[1350, 470, 1400, 650]], drop: 0.85, dy: 46 },
	{ name: "dead_3", src: "hurt", ex: [[1400, 470, 1564, 650]], soft: [[1350, 470, 1400, 650]], drop: 0.97, dy: 60 },
];
const hash = (x, y, s) => {
	let v = Math.imul(x * 374761393 + y * 668265263 + s * 2147483647, 1274126177);
	v = Math.imul(v ^ (v >>> 13), 1103515245);
	return ((v ^ (v >>> 16)) >>> 0) / 4294967296;
};
const isSkin = (r, g, b) => r > 140 && r > g && g > b && g > 85 && r - b > 45;
const lerp = (a, b, t) => a + (b - a) * t;

function mobPixels(spec) {
	const e = placed.find((q) => q.p.name === spec.src);
	const out = [];
	let eyeY = 0, eyeN = 0;
	for (let y = e.box.y0; y <= e.p.feetY; y++) {
		for (let x = e.box.x0; x <= e.box.x1; x++) {
			const p = y * w + x, i = p * 4;
			if (!alpha[p] || !e.keep(x, y) || (spec.ex || []).some(([a, b, c, dd]) => x >= a && y >= b && x <= c && y <= dd)) continue;
			// soft zones only drop leftover hologram/paper glow, never the coat or skin
			if ((spec.soft || []).some(([a, b, c, dd]) => x >= a && y >= b && x <= c && y <= dd)
				&& ((d[i + 1] >= d[i] * 1.15 && d[i + 1] >= d[i + 2]) || Math.min(d[i], d[i + 1], d[i + 2]) > 150)) continue;
			if (d[i] > 170 && d[i + 1] < 70 && d[i + 2] < 70 && y < e.box.y0 + 300) { eyeY += y; eyeN++; }
			out.push([x, y, p]);
		}
	}
	return { e, px: out, eyeY: eyeN ? eyeY / eyeN : e.box.y0 + 130 };
}

const frames = MOB.map((spec) => {
	const { e, px, eyeY } = mobPixels(spec);
	const pts = [];
	for (const [x, y, p] of px) {
		const i = p * 4;
		let r = d[i], g = d[i + 1], b = d[i + 2];
		if (isSkin(r, g, b)) {
			const lum = (r * 0.3 + g * 0.59 + b * 0.11);
			if (y < eyeY + 6) {
				// truffle: dark warty rind with pale marbling, shaded by the original skin lighting
				const n = hash(Math.floor(x / 6), Math.floor(y / 6), 1), n2 = hash(Math.floor(x / 3), Math.floor(y / 3), 2);
				const shade = Math.min(1, lum / 200) * 0.75 + n * 0.25;
				r = lerp(26, 104, shade); g = lerp(18, 72, shade); b = lerp(15, 50, shade);
				if (n2 > 0.93) { r = 196; g = 176; b = 140; }
				else if (n < 0.22) { r *= 0.6; g *= 0.6; b *= 0.6; }
			} else {
				r = lum * 0.72; g = lum * 0.78; b = lum * 0.9; // steel android face
			}
		} else if (g >= r * 1.12 && g >= b) {
			[r, g, b] = [Math.min(255, g * 1.05), r * 0.45 + b * 0.1, b * 0.5];
		}
		pts.push([x - e.feetX, y - e.p.feetY, r, g, b, alpha[p]]);
	}
	return { spec, pts };
});

// Shared half-resolution canvas, feet at the bottom centre.
let mL = 0, mR = 0, mU = 0;
for (const f of frames) for (const [dx, dy] of f.pts) {
	const yy = dy + (f.spec.dy || 0);
	mL = Math.max(mL, -dx); mR = Math.max(mR, dx); mU = Math.max(mU, -yy);
}
const mhalf = Math.ceil(Math.max(mL, mR) / 2) + 4, mW = mhalf * 2, mH = Math.ceil(mU / 2) + 8;
const mobDir = path.join(SPRITES, "truffle_android");
fs.rmSync(mobDir, { recursive: true, force: true });
fs.mkdirSync(mobDir, { recursive: true });
for (const f of frames) {
	const acc = new Float32Array(mW * mH * 5);
	for (const [dx, dy, r, g, b, a] of f.pts) {
		if (f.spec.drop && hash(dx, dy, 7) < f.spec.drop) continue;
		const X = Math.floor((dx + mhalf * 2) / 2) - mhalf + mhalf, Y = Math.floor((dy + (f.spec.dy || 0) + 2 * (mH - 4)) / 2);
		if (X < 0 || Y < 0 || X >= mW || Y >= mH) continue;
		const k = (Y * mW + X) * 5, aw = a / 255;
		acc[k] += r * aw; acc[k + 1] += g * aw; acc[k + 2] += b * aw; acc[k + 3] += aw; acc[k + 4] += 1;
	}
	const buf = Buffer.alloc(mW * mH * 4);
	for (let k = 0; k < mW * mH; k++) {
		const aw = acc[k * 5 + 3];
		if (aw <= 0) continue;
		buf[k * 4] = Math.round(acc[k * 5] / aw); buf[k * 4 + 1] = Math.round(acc[k * 5 + 1] / aw); buf[k * 4 + 2] = Math.round(acc[k * 5 + 2] / aw);
		buf[k * 4 + 3] = Math.min(255, Math.round((aw / 4) * 255 * 1.15));
	}
	fs.writeFileSync(path.join(mobDir, `truffle_android_${f.spec.name}.png`), encodePng(mW, mH, buf));
}
console.log(`truffle_android frames: ${frames.length}, canvas ${mW}x${mH}, feet at (${mhalf}, ${mH - 4})`);