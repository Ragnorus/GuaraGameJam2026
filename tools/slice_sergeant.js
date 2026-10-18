// Builds assets/sergeant_atlas.png and assets/sergeant_frames.tres from the supplied, unaltered
// art/sheets/football_sergeant_sheet.png. Run: node tools/slice_sergeant.js [preview.png]
// Boxes are [x, y, w, h] in sheet pixels (optional 5th value: body centre x). The black backdrop is removed only
// where it connects to the crop border, so interior outlines stay opaque; faint glow edges fade to alpha.
const fs = require("fs");
const path = require("path");
const { decodePng, encodePng } = require("./png_decode");

const ROOT = path.join(__dirname, "..");
const SHEET = path.join(ROOT, "art", "sheets", "football_sergeant_sheet.png");
const CELL_W = 448, CELL_H = 256, FEET_X = 224, FEET_Y = 244, COLS = 8;
const BG_LIMIT = 20;

// [animation, fps, loop, frames]
const ANIMS = [
	["idle", 8, true, [[20, 96, 110, 156], [130, 96, 96, 156], [226, 96, 96, 156], [322, 96, 96, 156], [414, 96, 96, 156], [506, 96, 104, 156]]],
	["charge", 12, false, [[662, 120, 116, 132], [778, 120, 132, 132], [910, 120, 168, 132, 1020], [1078, 120, 156, 132, 1190], [1234, 100, 290, 152, 1440]]],
	["transform", 8, false, [[8, 296, 108, 190], [116, 296, 112, 190], [228, 296, 118, 190], [346, 296, 112, 190], [458, 296, 124, 190], [582, 296, 142, 190], [724, 288, 160, 198]]],
	["rage_idle", 8, true, [[904, 300, 134, 188], [1040, 300, 128, 188], [1168, 300, 146, 188], [1314, 300, 200, 188, 1410]]],
	["rage_charge", 12, false, [[12, 540, 124, 160], [140, 540, 140, 160], [282, 540, 168, 160, 380], [452, 524, 186, 176, 560], [640, 515, 200, 190, 745]]],
	["punch", 12, false, [[868, 525, 100, 125], [968, 525, 88, 125], [1056, 525, 124, 125], [1180, 525, 116, 125], [1296, 525, 132, 125]]],
	["rage_punch", 12, false, [[872, 650, 108, 120], [984, 650, 160, 120], [1144, 648, 148, 122], [1292, 648, 196, 122, 1350]]],
	["scream", 8, false, [[12, 755, 116, 107], [144, 755, 112, 107], [276, 755, 90, 107]]],
	["rage_scream", 8, false, [[12, 870, 120, 116], [136, 870, 124, 116], [268, 870, 96, 116]]],
	["hurt", 14, false, [[644, 776, 80, 106], [736, 776, 84, 106], [820, 776, 100, 106]]],
	["rage_hurt", 14, false, [[636, 884, 96, 116], [732, 884, 94, 116], [828, 884, 100, 116]]],
	["death", 8, false, [[1130, 802, 84, 88], [1228, 802, 72, 88], [1304, 840, 96, 50], [1400, 840, 108, 50]]],
	["rage_death", 8, false, [[1124, 894, 100, 106], [1228, 894, 76, 106], [1308, 894, 100, 106], [1412, 894, 104, 106]]],
	// Leap/acid-escape poses: the sheet's most airborne frames (charge stride, rage lunge).
	["jump", 1, false, [[778, 120, 132, 132]]],
	["rage_jump", 1, false, [[1314, 300, 200, 188, 1410]]],
	// Sonic scream waves are centred effect cells, not feet-aligned characters.
	["wave", 1, false, [[362, 742, 246, 114]]],
	["rage_wave", 1, false, [[362, 858, 246, 128]]],
];

function cut(im, [bx, by, bw, bh]) {
	const d = Buffer.alloc(bw * bh * 4);
	for (let y = 0; y < bh; y++) im.d.copy(d, y * bw * 4, ((by + y) * im.w + bx) * 4, ((by + y) * im.w + bx + bw) * 4);
	const lum = (i) => Math.max(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]);
	const seen = new Uint8Array(bw * bh);
	const stack = [];
	for (let x = 0; x < bw; x++) stack.push(x, (bh - 1) * bw + x);
	for (let y = 0; y < bh; y++) stack.push(y * bw, y * bw + bw - 1);
	while (stack.length) {
		const i = stack.pop();
		if (seen[i] || lum(i) > BG_LIMIT) continue;
		seen[i] = 1;
		const x = i % bw, y = (i / bw) | 0;
		if (x > 0) stack.push(i - 1);
		if (x < bw - 1) stack.push(i + 1);
		if (y > 0) stack.push(i - bw);
		if (y < bh - 1) stack.push(i + bw);
	}
	for (let i = 0; i < bw * bh; i++) {
		if (!seen[i]) continue;
		const a = lum(i) / BG_LIMIT;
		d[i * 4 + 3] = Math.round(a * 255);
		// Un-premultiply from black so glow edges keep their hue as they fade out.
		for (let c = 0; c < 3; c++) d[i * 4 + c] = a > 0 ? Math.min(255, Math.round(d[i * 4 + c] / a)) : 0;
	}
	// Drop small detached specks (neighbouring poses' dust or label pixels).
	const comp = new Int32Array(bw * bh).fill(-1);
	const sizes = [];
	for (let i = 0; i < bw * bh; i++) {
		if (comp[i] >= 0 || d[i * 4 + 3] < 128) continue;
		const id = sizes.length;
		let size = 0;
		const st = [i];
		comp[i] = id;
		while (st.length) {
			const j = st.pop();
			size++;
			const x = j % bw, y = (j / bw) | 0;
			for (const n of [x > 0 ? j - 1 : -1, x < bw - 1 ? j + 1 : -1, y > 0 ? j - bw : -1, y < bh - 1 ? j + bw : -1]) {
				if (n >= 0 && comp[n] < 0 && d[n * 4 + 3] >= 128) { comp[n] = id; st.push(n); }
			}
		}
		sizes.push(size);
	}
	const largest = Math.max(...sizes);
	for (let i = 0; i < bw * bh; i++) if (comp[i] >= 0 && sizes[comp[i]] < Math.max(30, largest * 0.01)) d[i * 4 + 3] = 0;
	return { w: bw, h: bh, d };
}

function bounds(f) {
	let minX = f.w, maxX = -1, maxY = -1;
	for (let y = 0; y < f.h; y++) {
		let count = 0;
		for (let x = 0; x < f.w; x++) {
			if (f.d[(y * f.w + x) * 4 + 3] < 128) continue;
			count++;
			minX = Math.min(minX, x); maxX = Math.max(maxX, x);
		}
		if (count >= 3) maxY = y;
	}
	return { minX, maxX, maxY };
}

const sheet = decodePng(SHEET);
const cells = [];
for (const [name, , , frames] of ANIMS) {
	frames.forEach((box, index) => {
		const f = cut(sheet, box);
		const b = bounds(f);
		const effect = name.endsWith("wave");
		const centreX = box[4] !== undefined ? box[4] - box[0] : (b.minX + b.maxX) / 2;
		const ox = Math.round(FEET_X - centreX);
		const oy = effect ? Math.round((CELL_H - f.h) / 2) : FEET_Y - b.maxY;
		cells.push({ name, index, f, ox, oy });
	});
}

const rows = Math.ceil(cells.length / COLS);
const AW = COLS * CELL_W, AH = rows * CELL_H;
const atlas = Buffer.alloc(AW * AH * 4);
cells.forEach((cell, n) => {
	cell.x = (n % COLS) * CELL_W;
	cell.y = Math.floor(n / COLS) * CELL_H;
	for (let y = 0; y < cell.f.h; y++) for (let x = 0; x < cell.f.w; x++) {
		const tx = cell.ox + x, ty = cell.oy + y;
		const s = (y * cell.f.w + x) * 4;
		if (tx < 0 || ty < 0 || tx >= CELL_W || ty >= CELL_H || cell.f.d[s + 3] === 0) continue;
		cell.f.d.copy(atlas, ((cell.y + ty) * AW + cell.x + tx) * 4, s, s + 4);
	}
});
fs.writeFileSync(path.join(ROOT, "assets", "sergeant_atlas.png"), encodePng(AW, AH, atlas));

let tres = `[gd_resource type="SpriteFrames" load_steps=${cells.length + 2} format=3]\n\n`;
tres += `[ext_resource type="Texture2D" path="res://assets/sergeant_atlas.png" id="1"]\n\n`;
for (const c of cells) {
	tres += `[sub_resource type="AtlasTexture" id="AtlasTexture_${c.name}_${c.index}"]\natlas = ExtResource("1")\n`;
	tres += `region = Rect2(${c.x}, ${c.y}, ${CELL_W}, ${CELL_H})\n\n`;
}
tres += "[resource]\nanimations = [";
tres += ANIMS.map(([name, fps, loop, frames]) => `{\n"frames": [${frames.map((_, i) =>
	`{\n"duration": 1.0,\n"texture": SubResource("AtlasTexture_${name}_${i}")\n}`).join(", ")}],\n"loop": ${loop},\n"name": &"${name}",\n"speed": ${fps}.0\n}`).join(", ");
tres += "]\n";
fs.writeFileSync(path.join(ROOT, "assets", "sergeant_frames.tres"), tres);

// Optional contact sheet with a gold feet marker, for checking crops and alignment.
const preview = process.argv[2];
if (preview) {
	const out = Buffer.from(atlas);
	for (let i = 0; i < AW * AH; i++) {
		const a = out[i * 4 + 3] / 255;
		for (let c = 0; c < 3; c++) out[i * 4 + c] = Math.round(out[i * 4 + c] * a + 70 * (1 - a));
		out[i * 4 + 3] = 255;
	}
	for (const c of cells) {
		for (let x = 0; x < CELL_W; x++) out.fill(30, ((c.y) * AW + c.x + x) * 4, ((c.y) * AW + c.x + x) * 4 + 3);
		for (let y = 0; y < CELL_H; y++) out.fill(30, ((c.y + y) * AW + c.x) * 4, ((c.y + y) * AW + c.x) * 4 + 3);
		for (let x = -12; x <= 12; x++) {
			const o = ((c.y + FEET_Y) * AW + c.x + FEET_X + x) * 4;
			out[o] = 217; out[o + 1] = 154; out[o + 2] = 40;
		}
	}
	fs.writeFileSync(preview, encodePng(AW, AH, out));
}
console.log(`sergeant atlas ${AW}x${AH}, ${cells.length} frames`);
