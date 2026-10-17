// Debug: composites the Yeral background like main.gd does (sky + 2x panorama, mirrored). node tools/preview_bg.js <out.png> [scrollX]
const path = require("path");
const fs = require("fs");
const { decodePng, encodePng } = require("./png_decode");

const dir = path.join(__dirname, "..", "assets", "sprites", "city_bg");
const sky = decodePng(path.join(dir, "city_bg_sky.png"));
const pan = decodePng(path.join(dir, "city_bg_panorama.png"));
const scroll = Number(process.argv[3] || 0);
const PX = 2, OW = 1280, OH = 720, PW = pan.w * PX;
const off = Math.floor(scroll * 0.25);
const out = Buffer.alloc(OW * OH * 4);
for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
	const o = (y * OW + x) * 4;
	let s = (Math.floor((y * sky.h) / OH) * sky.w + Math.floor((x * sky.w) / OW)) * 4, src = sky.d;
	const py = y;
	if (py >= 0) {
		const gx = (((x + off) % (PW * 2)) + PW * 2) % (PW * 2);
		const flip = gx >= PW;
		const lx = Math.floor((flip ? PW * 2 - 1 - gx : gx) / PX);
		s = (Math.floor(py / PX) * pan.w + lx) * 4;
		src = pan.d;
	}
	out[o] = src[s]; out[o + 1] = src[s + 1]; out[o + 2] = src[s + 2]; out[o + 3] = 255;
}
fs.writeFileSync(process.argv[2], encodePng(OW, OH, out));
