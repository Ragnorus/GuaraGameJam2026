// Original art. Usage: node tools/build_yeral_environments.js "<Chrome-or-Edge-executable>"
const fs = require("fs");
const path = require("path");
const os = require("os");
const { spawnSync } = require("child_process");
const { pathToFileURL } = require("url");
const out = path.join(__dirname, "..", "assets", "backgrounds", "yeral");
const source = path.join(__dirname, "..", "art", "sheets", "generated_yeral");
fs.mkdirSync(out, { recursive: true });
fs.mkdirSync(source, { recursive: true });
const browser = process.argv[2];
if (!browser) throw new Error("Pass a Chromium/Edge executable to rasterize SVG patterns and text accurately.");
const defs = `<defs>
<linearGradient id="wall" x2="0" y2="1"><stop stop-color="#152623"/><stop offset="1" stop-color="#07100f"/></linearGradient>
<linearGradient id="metal" x2="0" y2="1"><stop stop-color="#48554b"/><stop offset=".3" stop-color="#29372d"/><stop offset=".7" stop-color="#101b18"/><stop offset="1" stop-color="#3b493a"/></linearGradient>
<radialGradient id="light"><stop stop-color="#a7ed58" stop-opacity=".24"/><stop offset="1" stop-color="#7fe536" stop-opacity="0"/></radialGradient>
<pattern id="brick" width="128" height="64" patternUnits="userSpaceOnUse"><rect width="128" height="64" fill="url(#wall)"/><path d="M0 0H128M0 32H128M0 64H128M64 0V32M0 32V64M128 32V64" stroke="#304038" stroke-width="3"/><path d="M4 4H60M68 4H124M4 36H124" stroke="#52604a" stroke-opacity=".22" stroke-width="2"/></pattern>
<pattern id="steel" width="160" height="120" patternUnits="userSpaceOnUse"><rect width="160" height="120" fill="#14201d"/><rect x="3" y="3" width="154" height="114" rx="2" fill="none" stroke="#35433a" stroke-width="3"/><path d="M12 12L148 108M148 12L12 108" stroke="#26362e" stroke-width="8"/><circle cx="10" cy="10" r="3" fill="#7c8055"/><circle cx="150" cy="110" r="3" fill="#7c8055"/></pattern>
</defs>`;
function save(name, content, width = 1280, height = 720) {
	const svg = path.join(source, name + ".svg");
	fs.writeFileSync(svg,
		`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="0 0 ${width} ${height}">${defs}${content}</svg>\n`);
	const profile = fs.mkdtempSync(path.join(os.tmpdir(), "guara-art-"));
	try {
		const result = spawnSync(browser, ["--headless", "--disable-gpu", "--hide-scrollbars",
			"--no-first-run", "--no-default-browser-check", "--force-device-scale-factor=1",
			`--user-data-dir=${profile}`, `--window-size=${width},${height}`,
			`--screenshot=${path.join(out, name + ".png")}`, pathToFileURL(svg).href],
			{ encoding: "utf8", timeout: 30000 });
		if (result.error) throw result.error;
		if (result.status !== 0) throw new Error(result.stderr || `Renderer exit ${result.status}`);
		if (!fs.existsSync(path.join(out, name + ".png"))) throw new Error("Renderer did not create " + name);
	} finally {
		fs.rmSync(profile, { recursive: true, force: true, maxRetries: 5, retryDelay: 200 });
	}
	console.log(`Generated ${name}.png (${width}x${height}); SVG source retained in art/sheets/generated_yeral`);
}
let sewer = `<rect width="1280" height="720" fill="url(#brick)"/>`;
for (let x = 80; x < 1280; x += 320) {
	sewer += `<path d="M${x} 610V240A130 130 0 0 1 ${x + 260} 240V610" fill="#06100e" stroke="#3a4b3b" stroke-width="22"/>
<path d="M${x + 12} 600V240A118 118 0 0 1 ${x + 248} 240V600" fill="url(#brick)" stroke="#101d18" stroke-width="8"/>
<rect x="${x + 36}" y="248" width="188" height="290" fill="#08110e"/>
<path d="M${x + 60} 250V538M${x + 100} 250V538M${x + 140} 250V538M${x + 180} 250V538" stroke="#28392c" stroke-width="9"/>
<ellipse cx="${x + 130}" cy="260" rx="190" ry="220" fill="url(#light)"/>
<rect x="${x + 107}" y="156" width="46" height="18" rx="5" fill="#0a100b" stroke="#a18c43" stroke-width="3"/>
<rect x="${x + 113}" y="161" width="34" height="7" fill="#b8e96b"/>`;
}
sewer += `<path d="M-30 72H1310M-30 652H1310" stroke="#07100c" stroke-width="48"/>
<path d="M-30 72H1310M-30 652H1310" stroke="url(#metal)" stroke-width="34"/>`;
for (let x = 0; x < 1280; x += 160) {
	sewer += `<rect x="${x}" y="49" width="14" height="46" rx="2" fill="#56614b" stroke="#121e15" stroke-width="3"/>
<path d="M${x + 35} 96v${30 + x % 90}" stroke="#3b5d32" stroke-opacity=".6" stroke-width="7"/>`;
}
save("sewer", sewer);
let warehouse = `<rect width="1280" height="720" fill="#090f12"/><rect width="1280" height="605" fill="url(#steel)"/>
<path d="M0 80L640 4L1280 80M0 80H1280M0 100H1280" fill="none" stroke="#465044" stroke-width="14"/>`;
for (let x = 80; x < 1250; x += 280) {
	warehouse += `<rect x="${x}" y="105" width="180" height="170" fill="#070e10" stroke="#465649" stroke-width="8"/>
<rect x="${x + 9}" y="114" width="162" height="151" fill="#213b38"/>
<path d="M${x + 90} 110V270M${x} 185H${x + 180}" stroke="#0d1b1b" stroke-width="9"/>
<path d="M${x} 87V590" stroke="#555b48" stroke-width="15"/>
<path d="M${x + 12} 87V590" stroke="#17271f" stroke-width="8"/>
<ellipse cx="${x + 100}" cy="365" rx="185" ry="235" fill="url(#light)"/>
<path d="M${x + 100} 8V72" stroke="#656846" stroke-width="4"/>
<path d="M${x + 70} 86L${x + 88} 65H${x + 112}L${x + 130} 86Z" fill="#61704c" stroke="#0a140d" stroke-width="4"/>
<rect x="${x + 80}" y="86" width="40" height="5" fill="#dded9b"/>`;
}
warehouse += `<rect x="460" y="295" width="360" height="305" fill="#111c17" stroke="#8a7c3c" stroke-width="10"/>`;
for (let y = 310; y < 600; y += 22) {
	warehouse += `<rect x="468" y="${y}" width="344" height="16" fill="url(#metal)"/>`;
}
warehouse += `<path d="M640 598V315" stroke="#0a120e" stroke-width="5"/>
<rect x="510" y="300" width="260" height="57" fill="#0b130c" stroke="#8e7b36" stroke-width="4"/>
<text x="640" y="337" font-family="sans-serif" font-size="26" font-weight="bold" text-anchor="middle" fill="#bfdd74">SPOILER STORAGE</text>`;
for (const [x, y, w, h] of [[20, 510, 160, 90], [60, 420, 110, 88], [1010, 470, 190, 130], [1110, 380, 130, 88]]) {
	warehouse += `<rect x="${x}" y="${y}" width="${w}" height="${h}" fill="#37432b" stroke="#0a140c" stroke-width="6"/>
<path d="M${x + 8} ${y + 8}L${x + w - 8} ${y + h - 8}M${x + w - 8} ${y + 8}L${x + 8} ${y + h - 8}" stroke="#69704a" stroke-width="8"/>`;
}
warehouse += `<rect y="600" width="1280" height="120" fill="#11191a"/>
<path d="M0 603H1280M0 618H1280" stroke="#6c7756" stroke-width="5"/>`;
for (let x = 0; x < 1280; x += 48) {
	warehouse += `<path d="M${x} 604l14 12h22l-14-12" fill="#b09842"/>`;
}
save("warehouse", warehouse);
let entrance = `<rect x="4" y="4" width="252" height="352" fill="url(#brick)" stroke="#6d795c" stroke-width="8"/>
<path d="M30 355V80H230V355" fill="#050c0a" stroke="#6b7453" stroke-width="12"/>
<rect x="40" y="85" width="180" height="32" fill="url(#metal)"/>
<path d="M30 117H230" stroke="#b6bf73" stroke-width="4"/>
<rect x="18" y="15" width="224" height="50" fill="#0b130c" stroke="#9f914a" stroke-width="4"/>
<text x="130" y="37" font-family="sans-serif" font-size="16" font-weight="bold" text-anchor="middle" fill="#d6e88c">SPOILER STORAGE</text>
<text x="130" y="55" font-family="sans-serif" font-size="12" text-anchor="middle" fill="#aabf82">WAREHOUSE  /  05</text>
<path d="M30 356H230" stroke="#e2cf69" stroke-width="8"/>`;
save("warehouse_entrance", entrance, 260, 360);
