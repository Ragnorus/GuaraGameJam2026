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
