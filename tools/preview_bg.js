// Debug: composites the city_bg layers at 5x like the game does. node tools/preview_bg.js <out.png> [scrollX]
const path = require("path");
const fs = require("fs");
const { decodePng, encodePng } = require("./png_decode");

const dir = path.join(__dirname, "..", "assets", "sprites", "city_bg");
const scroll = Number(process.argv[3] || 0);
const S = 5, OW = 1280, OH = 720;
const out = Buffer.alloc(OW * OH * 4);
// [file, parallax speed, y offset in game px, alpha]
for (const [f, speed, y0, a] of [["sky", 0.02, 0, 1], ["clouds", 0.1, 4, 0.9], ["far", 0.08, 0, 1], ["mid", 0.18, 0, 1], ["near", 0.32, 0, 1]]) {
	const im = decodePng(path.join(dir, `city_bg_${f}.png`));
	const off = Math.floor((scroll * speed) / S);
	for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
		const gy = Math.floor(y / S) - y0;
		if (gy < 0 || gy >= im.h) continue;
		const gx = (((Math.floor(x / S) + off) % im.w) + im.w) % im.w;
		const s = (gy * im.w + gx) * 4, o = (y * OW + x) * 4, al = (im.d[s + 3] / 255) * a;
		for (let k = 0; k < 3; k++) out[o + k] = Math.round(im.d[s + k] * al + out[o + k] * (1 - al));
		out[o + 3] = 255;
	}
}
fs.writeFileSync(process.argv[2], encodePng(OW, OH, out));
