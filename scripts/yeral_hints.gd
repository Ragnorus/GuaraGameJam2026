class_name YeralHints

# Hints Yeral blurts out when hit. Keyed by the boss they refer to.
# See .github/skills/yeral-hints/SKILL.md before adding or editing.
const HINTS := {
	"ema": [
		"Ema's acid comes in a fan. The more she's hurt, the wider it gets. Keep moving!",
		"Ema charges in a straight line. Jump over her, don't run from her.",
		"Her bugs are weak to your minions. Let the Shadows do the dirty work.",
		"Ema gets faster below two thirds health. Then again at one third. Brace yourself.",
		"Fill the army meter on her bugs, then unleash the GUARA ARMY on the queen.",
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
