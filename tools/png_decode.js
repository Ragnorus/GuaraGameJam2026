// Minimal dependency-free PNG decoder (8-bit RGB/RGBA, non-interlaced) used by the sprite tools.
const fs = require("fs");
const zlib = require("zlib");

function decodePng(file) {
	const b = fs.readFileSync(file);
	let pos = 8, w = 0, h = 0, ct = 0;
	const idat = [];
	while (pos < b.length) {
		const len = b.readUInt32BE(pos);
		const type = b.toString("ascii", pos + 4, pos + 8);
		const data = b.subarray(pos + 8, pos + 8 + len);
		if (type === "IHDR") { w = data.readUInt32BE(0); h = data.readUInt32BE(4); ct = data[9]; }
		if (type === "IDAT") idat.push(data);
		pos += 12 + len;
	}
	const bpp = ct === 6 ? 4 : 3;
	const raw = zlib.inflateSync(Buffer.concat(idat));
	const stride = w * bpp;
	const out = Buffer.alloc(w * h * 4);
	let prev = Buffer.alloc(stride);
	for (let y = 0; y < h; y++) {
		const f = raw[y * (stride + 1)];
		const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
		for (let i = 0; i < stride; i++) {
			const a = i >= bpp ? line[i - bpp] : 0, up = prev[i], c = i >= bpp ? prev[i - bpp] : 0;
			let v = line[i];
			if (f === 1) v += a;
			else if (f === 2) v += up;
			else if (f === 3) v += (a + up) >> 1;
			else if (f === 4) {
				const p = a + up - c, pa = Math.abs(p - a), pb = Math.abs(p - up), pc = Math.abs(p - c);
				v += pa <= pb && pa <= pc ? a : pb <= pc ? up : c;
			}
			line[i] = v & 255;
		}
		for (let x = 0; x < w; x++) {
			const o = (y * w + x) * 4;
			out[o] = line[x * bpp]; out[o + 1] = line[x * bpp + 1]; out[o + 2] = line[x * bpp + 2];
			out[o + 3] = bpp === 4 ? line[x * bpp + 3] : 255;
		}
		prev = line;
	}
	return { w, h, d: out };
}

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

function encodePng(w, h, rgba) {
	const rows = [];
	for (let y = 0; y < h; y++) rows.push(Buffer.from([0]), rgba.subarray(y * w * 4, (y + 1) * w * 4));
	const ihdr = Buffer.alloc(13);
	ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
	ihdr[8] = 8; ihdr[9] = 6;
	return Buffer.concat([
		Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
		chunk("IHDR", ihdr),
		chunk("IDAT", zlib.deflateSync(Buffer.concat(rows))),
		chunk("IEND", Buffer.alloc(0)),
	]);
}

module.exports = { decodePng, encodePng };
