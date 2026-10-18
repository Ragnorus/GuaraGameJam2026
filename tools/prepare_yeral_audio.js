// Usage: node tools/prepare_yeral_audio.js <ffmpeg executable> [source MP3]
const path = require("path");
const { spawnSync } = require("child_process");
const source = process.argv[3] || path.join(__dirname, "..", "assets", "audio", "source", "yeral_intro_original.mp3");
if (!process.argv[2]) throw new Error("Pass the path to an ffmpeg executable.");
const output = path.join(__dirname, "..", "assets", "audio", "yeral_intro.wav");
// Preserve speech: attenuate the opening burst rather than guessing a hard speech cut.
const filters = "highpass=f=100,afftdn=nf=-28,volume='if(lt(t,0.35),0.3,1)':eval=frame,afade=t=in:d=0.04,afade=t=out:st=4.82:d=0.13,alimiter=limit=0.95";
const result = spawnSync(process.argv[2], ["-hide_banner", "-loglevel", "error", "-y", "-i", source,
	"-af", filters, "-ar", "44100", "-ac", "1", "-c:a", "pcm_s16le", output], { stdio: "inherit" });
if (result.error) throw result.error;
if (result.status !== 0) throw new Error(`Yeral audio preparation failed (exit ${result.status})`);
console.log("Prepared", output);
