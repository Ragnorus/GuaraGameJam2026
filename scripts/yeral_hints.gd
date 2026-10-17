class_name YeralHints

# Hints Yeral blurts out when hit. Keyed by the boss they refer to.
# See .github/skills/yeral-hints/SKILL.md before adding or editing.
const HINTS := {
	"glizzy": [
		"Spoiler: the sauce strip is safe until it splashes. Move before dinner is served.",
		"My puddles only burn near the floor. Jump over the extra sauce.",
		"Even this bun can't turn mid-charge. Jump once I commit.",
		"Two-thirds health means a faster Gobler. Save your dash for the rush.",
		"Ketchup and mustard both hurt. Keep moving through the gaps.",
	],
	"evil_genius": [
		"Ema sprays a fan of cash bills. The more he's hurt, the wider it gets. Keep moving!",
		"He stops and braces before a charge. Jump over him, don't run from him.",
		"His truffle androids die in one hit. Let the Shadows clear them while you aim at the boss.",
		"He gets faster at two-thirds health, then again at one-third. Brace yourself.",
		"His only weakness? A girl boss lawyer. Objection!",
	],
	"ponce": [
		"Ponce slams the ground and sends shockwaves. Jump the wave, then punish.",
		"When Ponce charges, step aside. He can't turn mid-rush.",
		"Careful: Ponce's platforms are destructible. Don't get comfy.",
	],
	"zinna": [
		"Zinna boosts before every dive. Listen for the engine, then move.",
		"Zinna's shots ricochet. Stay off the walls.",
	],
	"javi": [
		"Javi teleports behind you. Keep moving and don't hug him.",
		"Javi chains combos. Dodge the third hit, that's where he's open.",
	],
	"omi": [
		"Omi's decoys look real. The real one never moves with the lights.",
		"Watch the stage lights. They mean a hazard is coming.",
	],
	"rodolfo": [
		"Rodolfo's jokes are projectiles. Bad puns hurt, so don't laugh.",
		"Rodolfo feints. Wait for the real swing before you dodge.",
	],
	"ragn0rus": [
		"Ragn0rus fires mustard lasers. Hide behind a minion.",
		"Ketchup sigils on the floor mean an explosion. Leave the circle.",
		"The hot dog meteor is slow. Run, don't jump.",
	],
	"vakka": [
		"Vakka knows exactly one move. Hadouken. Its size grows each phase.",
		"Vakka teleports before he shoots. Hit him as he lands.",
	],
	"ludo": [
		"Ludo's screen-filling attack always follows a roll. Save your dodge.",
		"Ludo chains abilities. Count them, then punish the last one.",
	],
	"general": [
		"Every boss telegraphs. Learn the tell, not the damage number.",
		"Minions soak hits meant for you. Summon before the fight, recall when it ends.",
		"Don't waste the Army meter on trash. Save it for a boss phase change.",
		"Phase changes make bosses faster, not smarter. Stay patient.",
		"I could tell you what comes next... but would you believe me?",
	],
}

static func all_hints() -> Array:
	var out: Array = []
	for k in HINTS:
		out.append_array(HINTS[k])
	return out
