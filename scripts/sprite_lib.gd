class_name SpriteLib
extends RefCounted

const ROOT := "res://assets/sprites/"

# anims: { name: [frame_suffixes, fps, loop] }. Frames live in assets/sprites/<group>/<group>_<suffix>.png
# (made by tools/slice_sheets.js). All frames of a group share one canvas, so one centred sprite is enough.
static func build(group: String, anims: Dictionary) -> SpriteFrames:
	var sf := SpriteFrames.new()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in anims:
		var a: Array = anims[anim]
		sf.add_animation(anim)
		sf.set_animation_speed(anim, a[1])
		sf.set_animation_loop(anim, a[2])
		for suffix in a[0]:
			sf.add_frame(anim, texture(group, suffix))
	return sf

static func texture(group: String, suffix: String) -> Texture2D:
	return load("%s%s/%s_%s.png" % [ROOT, group, group, suffix])

# Sprite whose canvas bottom (the feet) sits at feet_y in the parent's space.
static func make_sprite(frames: SpriteFrames, feet_y: float) -> AnimatedSprite2D:
	var s := AnimatedSprite2D.new()
	s.sprite_frames = frames
	var first := frames.get_animation_names()[0]
	s.position.y = feet_y - frames.get_frame_texture(first, 0).get_height() / 2.0
	return s
