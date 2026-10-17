// Generates the cyberpunk pixel-art assets into assets/. Run: node tools/gen_assets.js
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.join(__dirname, "..", "assets");
fs.mkdirSync(OUT, { recursive: true });

function crc32(buf) {
	let c, crc = 0xffffffff;
	for (let n = 0; n < buf.length; n++) {
		c = (crc ^ buf[n]) & 0xff;
		for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
		crc = (crc >>> 8) ^ c;
	}
	return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
	const len = Buffer.alloc(4);
	len.writeUInt32BE(data.length);
	const td = Buffer.concat([Buffer.from(type), data]);
	const crc = Buffer.alloc(4);
	crc.writeUInt32BE(crc32(td));
	return Buffer.concat([len, td, crc]);
}

function hex(s) {
	return [parseInt(s.slice(1, 3), 16), parseInt(s.slice(3, 5), 16), parseInt(s.slice(5, 7), 16)];
}

function mix(a, b, t) {
	return [0, 1, 2].map((i) => Math.round(a[i] + (b[i] - a[i]) * t));
}

function rng(seed) {
	return () => {
		seed |= 0; seed = (seed + 0x6d2b79f5) | 0;
		let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
		t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

class Img {
	constructor(w, h, wrap = false) {
		this.w = w; this.h = h; this.wrap = wrap;
		this.d = Buffer.alloc(w * h * 4);
	}
	px(x, y, c, a = 255) {
		x = Math.floor(x); y = Math.floor(y);
		if (this.wrap) x = ((x % this.w) + this.w) % this.w;
		if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
		const i = (y * this.w + x) * 4;
		const sa = a / 255, da = this.d[i + 3] / 255;
		const oa = sa + da * (1 - sa);
		if (oa === 0) return;
		for (let k = 0; k < 3; k++) {
			this.d[i + k] = Math.round((c[k] * sa + this.d[i + k] * da * (1 - sa)) / oa);
		}
		this.d[i + 3] = Math.round(oa * 255);
	}
	rect(x, y, w, h, c, a = 255) {
		for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.px(x + i, y + j, c, a);
	}
	save(name) {
		const rows = [];
		for (let y = 0; y < this.h; y++) {
			rows.push(Buffer.from([0]), this.d.subarray(y * this.w * 4, (y + 1) * this.w * 4));
		}
		const ihdr = Buffer.alloc(13);
		ihdr.writeUInt32BE(this.w, 0); ihdr.writeUInt32BE(this.h, 4);
		ihdr[8] = 8; ihdr[9] = 6;
		const png = Buffer.concat([
			Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
			chunk("IHDR", ihdr),
			chunk("IDAT", zlib.deflateSync(Buffer.concat(rows))),
			chunk("IEND", Buffer.alloc(0)),
		]);
		fs.writeFileSync(path.join(OUT, name), png);
		console.log("wrote", name, this.w + "x" + this.h);
	}
}

const P = {
	night: hex("#120a22"), dark: hex("#1e1236"), purple: hex("#3a2466"), violet: hex("#6a2c91"),
	magenta: hex("#c04fd0"), pink: hex("#ff6fd8"), cyan: hex("#38e8ff"), blue: hex("#2a6cff"),
	yellow: hex("#ffc03a"), green: hex("#4dff9a"), steel: hex("#232a52"), steelHi: hex("#3a4a8a"),
};
const LIGHTS = [P.cyan, P.yellow, P.pink, P.blue, P.green];

function windows(img, r, x, y, w, h, density, palette) {
	for (let wy = y + 4; wy < y + h - 3; wy += 6) {
		for (let wx = x + 3; wx < x + w - 3; wx += 5) {
			if (r() < density) img.rect(wx, wy, 2, 3, palette[Math.floor(r() * palette.length)], 200);
		}
	}
}

// Parallax skyline layers (tile horizontally). Shown at 2x scale.
function skyline(name, seed, opts) {
	const W = 512, H = 360;
	const img = new Img(W, H, true);
	const r = rng(seed);
	if (opts.sky) {
		for (let y = 0; y < H; y++) {
			const t = y / H;
			const c = t < 0.6 ? mix(hex("#1a1040"), hex("#7a2f9e"), t / 0.6) : mix(hex("#7a2f9e"), hex("#ff6fd8"), (t - 0.6) / 0.4);
			img.rect(0, y, W, 1, c);
		}
	}
	let x = -10;
	while (x < W) {
		const w = opts.minW + Math.floor(r() * (opts.maxW - opts.minW));
		const h = opts.minH + Math.floor(r() * (opts.maxH - opts.minH));
		const top = H - h;
		const body = mix(opts.base, opts.tint, r() * 0.6);
		img.rect(x, top, w, h, body);
		img.rect(x, top, 2, h, mix(body, P.magenta, 0.35));
		img.rect(x + w - 2, top, 2, h, mix(body, P.night, 0.4));
		if (r() < 0.5) img.rect(x + 3, top - 4, w - 6, 4, mix(body, P.night, 0.2));
		if (r() < 0.4) img.rect(x + Math.floor(w / 2), top - 14, 1, 14, mix(body, P.cyan, 0.4));
		windows(img, r, x, top, w, h, opts.windows, opts.lights);
		if (opts.neon && r() < 0.6) {
			const nc = LIGHTS[Math.floor(r() * LIGHTS.length)];
			const sy = top + 10 + Math.floor(r() * (h * 0.5));
			if (r() < 0.5) {
				img.rect(x + 4, sy, 4, 22, nc, 60);
				img.rect(x + 5, sy + 1, 2, 20, nc);
			} else {
				img.rect(x + 3, sy, w - 6, 12, nc, 50);
				img.rect(x + 4, sy + 1, w - 8, 10, mix(nc, P.night, 0.55));
				for (let gx = x + 6; gx < x + w - 8; gx += 4) {
					img.rect(gx, sy + 3, 2, 1 + Math.floor(r() * 5), nc);
				}
			}
		}
		if (opts.edge) img.rect(x, top, w, 1, opts.edge, 220);
		x += w - Math.floor(r() * 6);
	}
	img.save(name);
}

skyline("bg_far.png", 11, {
	sky: true, minW: 30, maxW: 60, minH: 140, maxH: 300, base: hex("#2a1a58"), tint: hex("#5a2a88"),
	windows: 0.06, lights: [P.cyan, P.pink, P.yellow], neon: false,
});
skyline("bg_mid.png", 22, {
	minW: 40, maxW: 80, minH: 100, maxH: 240, base: hex("#2b1a52"), tint: hex("#4a2a7a"),
	windows: 0.22, lights: LIGHTS, neon: true, edge: P.violet,
});
skyline("bg_near.png", 33, {
	minW: 50, maxW: 100, minH: 50, maxH: 150, base: P.night, tint: P.dark,
	windows: 0.1, lights: [P.yellow, P.cyan], neon: true, edge: P.cyan,
});

// Floor: bright walkway top + chain-link underside.
{
	const t = new Img(32, 16);
	t.rect(0, 0, 32, 16, P.steel);
	t.rect(0, 0, 32, 2, hex("#6fc7ff"));
	t.rect(0, 2, 32, 1, P.blue);
	t.rect(0, 12, 32, 4, hex("#151a38"));
	for (const x of [3, 15, 27]) { t.rect(x, 6, 2, 2, hex("#6a78c0")); t.rect(x, 8, 2, 1, P.night); }
	t.rect(0, 10, 32, 1, hex("#161c40"));
	t.save("tile_floor_top.png");

	const m = new Img(32, 32);
	m.rect(0, 0, 32, 32, hex("#0d0a1a"));
	for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) {
		if ((x + y) % 8 === 0 || (x - y + 64) % 8 === 0) m.px(x, y, hex("#2c2656"));
	}
	m.save("tile_floor_mesh.png");

	const p = new Img(32, 20);
	p.rect(0, 0, 32, 20, P.steel);
	p.rect(0, 0, 32, 3, P.steelHi);
	p.rect(0, 0, 32, 1, hex("#6fc7ff"));
	p.rect(0, 14, 32, 3, hex("#151a38"));
	for (const x of [3, 27]) p.rect(x, 6, 2, 2, hex("#6a78c0"));
	p.rect(0, 17, 32, 1, P.pink, 90);
	p.rect(0, 18, 32, 2, P.pink);
	p.save("tile_platform.png");

	const w = new Img(32, 32);
	w.rect(0, 0, 32, 32, hex("#161036"));
	w.rect(0, 0, 3, 32, hex("#2a2060"));
	w.rect(29, 0, 3, 32, hex("#0c0820"));
	for (let y = 0; y < 32; y += 8) w.rect(0, y, 32, 1, hex("#0c0820"));
	w.rect(14, 0, 4, 32, P.cyan, 60);
	w.rect(15, 0, 2, 32, P.cyan, 140);
	w.save("tile_wall.png");
}

// Props
{
	const c = new Img(16, 24);
	c.rect(2, 20, 12, 4, P.night);
	for (let y = 2; y < 20; y++) for (let x = 3; x < 13; x++) {
		c.px(x, y, Math.floor((x + y) / 3) % 2 ? P.yellow : P.night);
	}
	c.rect(4, 0, 8, 3, hex("#ffe58a"));
	c.rect(3, 1, 10, 2, P.yellow);
	c.save("prop_bollard.png");

	const d = new Img(40, 64);
	d.rect(0, 0, 40, 64, hex("#6a4a30"));
	d.rect(0, 0, 40, 3, hex("#8a6a4a"));
	d.rect(0, 61, 40, 3, hex("#3e2a1a"));
	d.rect(4, 8, 32, 48, hex("#7a5a3a"));
	d.rect(8, 22, 24, 16, hex("#10243a"));
	d.rect(8, 22, 24, 1, P.cyan); d.rect(8, 37, 24, 1, P.cyan);
	d.rect(8, 22, 1, 16, P.cyan); d.rect(31, 22, 1, 16, P.cyan);
	d.rect(14, 29, 14, 2, P.cyan);
	d.rect(14, 27, 2, 6, P.cyan); d.rect(12, 28, 2, 4, P.cyan);
	d.rect(6, 44, 10, 8, hex("#5a3e28")); d.rect(24, 12, 8, 6, hex("#5a3e28"));
	d.save("prop_door.png");

	const s = new Img(64, 40);
	const r = rng(77);
	s.rect(0, 0, 64, 40, P.pink, 40);
	s.rect(3, 3, 58, 34, P.night);
	s.rect(3, 3, 58, 1, P.cyan); s.rect(3, 36, 58, 1, P.cyan);
	s.rect(3, 3, 1, 34, P.cyan); s.rect(60, 3, 1, 34, P.cyan);
	for (let y = 4; y < 36; y++) s.rect(4, y, 56, 1, mix(hex("#2a1060"), hex("#b040e0"), (y - 4) / 32));
	for (let i = 0; i < 6; i++) {
		const gx = 8 + i * 9;
		for (let k = 0; k < 9; k++) if (r() < 0.6) s.px(gx + (k % 3) * 2, 10 + Math.floor(k / 3) * 3 + 8, P.cyan);
		s.rect(gx, 12, 6, 1, P.cyan);
		s.rect(gx, 26, 6, 1, P.yellow);
	}
	s.save("prop_sign_billboard.png");

	const v = new Img(20, 72);
	v.rect(0, 0, 20, 72, P.cyan, 35);
	v.rect(3, 2, 14, 68, P.night);
	v.rect(3, 2, 1, 68, P.blue); v.rect(16, 2, 1, 68, P.blue);
	for (let i = 0; i < 6; i++) {
		v.rect(7, 8 + i * 10, 6, 2, P.cyan);
		v.rect(7, 12 + i * 10, 3 + (i % 3) * 2, 2, i % 2 ? P.pink : P.cyan);
	}
	v.save("prop_sign_vertical.png");

	const l = new Img(48, 32);
	l.rect(2, 8, 44, 22, P.cyan, 30);
	l.rect(4, 0, 40, 6, hex("#2a2450"));
	l.rect(4, 6, 40, 1, P.pink);
	for (let y = 8; y < 26; y++) l.rect(8, y, 32, 1, mix(P.cyan, P.pink, (y - 8) / 18));
	l.rect(8, 8, 32, 1, hex("#e6ffff"));
	l.rect(6, 8, 2, 18, P.pink); l.rect(40, 8, 2, 18, P.yellow);
	l.save("prop_neon_lamp.png");

	const k = new Img(24, 24);
	k.rect(0, 0, 24, 24, hex("#3a2c60"));
	k.rect(2, 2, 20, 20, hex("#2a1f4a"));
	k.rect(0, 0, 24, 2, hex("#6a78c0"));
	for (let i = 0; i < 24; i++) { k.px(i, i, hex("#4a3a80")); k.px(23 - i, i, hex("#4a3a80")); }
	k.rect(10, 10, 4, 4, P.pink);
	k.save("prop_crate.png");
}
