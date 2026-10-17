// Debug: lays a group's frames side by side on a grey background. node tools/contact_sheet.js <group> <out.png>
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const dir = path.join(__dirname, "..", "assets", "sprites", process.argv[2]);
const files = fs.readdirSync(dir).filter((f) => f.endsWith(".png")).sort();
const imgs = files.map((f) => decodePng(path.join(dir, f)));
const mw = Math.max(...imgs.map((i) => i.w)), mh = Math.max(...imgs.map((i) => i.h));
const cols = Math.min(files.length, Math.max(1, Math.floor(1600 / (mw + 6))));
const cw = mw + 6, ch = mh + 6;
const rows = Math.ceil(files.length / cols);
const W = cols * cw, H = rows * ch;
const out = Buffer.alloc(W * H * 4);
for (let i = 0; i < W * H; i++) { out[i * 4] = 90; out[i * 4 + 1] = 100; out[i * 4 + 2] = 110; out[i * 4 + 3] = 255; }
imgs.forEach((im, n) => {
	const ox = (n % cols) * cw + 3, oy = Math.floor(n / cols) * ch + 3;
	for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
		const s = (y * im.w + x) * 4, o = ((oy + y) * W + ox + x) * 4, a = im.d[s + 3] / 255;
		for (let k = 0; k < 3; k++) out[o + k] = Math.round(im.d[s + k] * a + out[o + k] * (1 - a));
	}
});
fs.writeFileSync(process.argv[3], encodePng(W, H, out));
console.log(files.join(" "));
