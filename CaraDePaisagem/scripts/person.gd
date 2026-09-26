# Someone watching you. Alternates between looking away, a short warning
# and staring at your face. Drawn in the art style of the current level.
extends Node2D

const Pen = preload("res://scripts/pen.gd")

const AWAY := 0
const WARN := 1
const LOOK := 2

var look := AWAY
var timer := 2.0
var away_range := Vector2(2.6, 5.0)
var look_range := Vector2(1.6, 3.0)
var warn_time := 0.9
var forced := 0.0
var weight := 1.0
var target := Vector2(340, 395)
var talking := false
var judge := 0.0          # 0 pleased, 1 disapproving
var bounce := 0.0
var active := true
var voice := 1.0
var pseed := 0
var t := 0.0

var skin := Color(0.9, 0.7, 0.55)
var hair := Color(0.2, 0.15, 0.1)
var hstyle := "short"
var cloth := Color(0.3, 0.4, 0.6)
var acc: Array = []
var prop := ""
var style := -1           # overrides Pen.base when drawing (menus)

signal started_look(p)


func setup(d: Dictionary) -> void:
	position = d.get("pos", position)
	scale = Vector2.ONE * float(d.get("scale", 1.0))
	skin = d.get("skin", skin)
	hair = d.get("hair", hair)
	hstyle = d.get("hstyle", hstyle)
	cloth = d.get("cloth", cloth)
	acc = d.get("acc", [])
	prop = d.get("prop", "")
	voice = d.get("voice", 1.0)
	weight = d.get("weight", 1.0)
	away_range = d.get("away", away_range)
	look_range = d.get("look", look_range)
	pseed = d.get("seed", randi() % 5000)
	timer = randf_range(1.5, away_range.y)


func force_look(dur: float, warn := 0.7) -> void:
	if look == LOOK:
		timer = maxf(timer, dur)
		return
	look = WARN
	timer = warn
	forced = dur


func head_pos() -> Vector2:
	return to_global(Vector2(0, -205))


func eyes() -> Array:
	return [to_global(Vector2(-22, -212)), to_global(Vector2(22, -212))]


func _process(delta: float) -> void:
	t += delta
	bounce = maxf(0.0, bounce - delta * 3.0)
	if active:
		timer -= delta
		if timer <= 0.0:
			match look:
				AWAY:
					look = WARN
					timer = warn_time
				WARN:
					look = LOOK
					timer = forced if forced > 0.0 else randf_range(look_range.x, look_range.y)
					forced = 0.0
					started_look.emit(self)
				LOOK:
					look = AWAY
					timer = randf_range(away_range.x, away_range.y)
	queue_redraw()


func _draw() -> void:
	var old := Pen.base
	if style >= 0:
		Pen.base = style
	var ink := Pen.ink
	var hop := Vector2(0, -absf(sin(bounce * PI * 2.0)) * 18.0)
	draw_set_transform(hop, 0.0, Vector2.ONE)
	var hc := Vector2(0, -205)

	# hair behind the head
	if hstyle == "long" or hstyle == "veil":
		var back := Pen.poly([Vector2(-68, -240), Vector2(68, -240), Vector2(80, -110), Vector2(-80, -110)])
		Pen.shape(self, back, Color(1, 1, 1, 0.85) if hstyle == "veil" else hair, ink, 2.0, pseed + 1)
	if hstyle == "bun":
		Pen.shape(self, Pen.ellipse(hc + Vector2(0, -78), 28, 24, 20), hair, ink, 2.5, pseed + 2)

	# body
	var body := Pen.poly([Vector2(-120, 12), Vector2(-108, -118), Vector2(-42, -146), Vector2(42, -146), Vector2(108, -118), Vector2(120, 12)])
	Pen.shape(self, body, cloth, ink, 3.0, pseed + 3)
	Pen.shape(self, Pen.rect(Rect2(-20, -168, 40, 30)), skin.darkened(0.1), ink, 2.0, pseed + 4)
	if "tie" in acc:
		Pen.shape(self, Pen.poly([Vector2(-9, -146), Vector2(9, -146), Vector2(14, -60), Vector2(0, -48), Vector2(-14, -60)]), Pen.RISO_PINK, ink, 2.0, pseed + 5)
	if "bowtie" in acc:
		Pen.shape(self, Pen.poly([Vector2(-22, -150), Vector2(0, -142), Vector2(22, -150), Vector2(22, -130), Vector2(0, -138), Vector2(-22, -130)]), ink, ink, 1.5, pseed + 5)
	if "pearls" in acc:
		for k in 9:
			var a := PI * (0.15 + 0.7 * k / 8.0)
			var pp := Vector2(cos(a) * 36.0, -150.0 + sin(a) * 26.0)
			Pen.shape(self, Pen.ellipse(pp, 6, 6, 10), Color(0.98, 0.96, 0.9), ink, 1.0, pseed + 30 + k)
	if "badge" in acc:
		Pen.line(self, Vector2(-30, -145), Vector2(-45, -80), Pen.RISO_BLUE, 2.0, pseed + 6)
		Pen.line(self, Vector2(30, -145), Vector2(-25, -80), Pen.RISO_BLUE, 2.0, pseed + 7)
		Pen.shape(self, Pen.rect(Rect2(-55, -82, 36, 44)), Color(1, 1, 1), ink, 2.0, pseed + 8)
		Pen.shape(self, Pen.rect(Rect2(-49, -74, 24, 14)), Color(0.4, 0.6, 0.9), ink, 1.0, pseed + 9)
	if "flower" in acc:
		Pen.shape(self, Pen.ellipse(Vector2(-60, -110), 12, 12, 12), Pen.RISO_PINK, ink, 1.5, pseed + 10)

	# head
	Pen.shape(self, Pen.ellipse(hc, 58, 70, 30), skin, ink, 3.0, pseed + 11)
	for sd in [-1, 1]:
		Pen.shape(self, Pen.ellipse(hc + Vector2(58 * sd, 4), 10, 16, 14), skin, ink, 2.0, pseed + 12 + sd)
	_hair_front(hc, ink)

	# eyes
	for sd in [-1, 1]:
		var c := hc + Vector2(22 * sd, -7)
		if look == AWAY:
			var arc := PackedVector2Array()
			for i in 7:
				var a := PI * i / 6.0
				arc.append(c + Vector2(cos(a) * 10.0, sin(a) * 5.0 + 3.0))
			Pen.outline(self, arc, ink, 3.0, pseed + 20 + sd, false)
		else:
			var open := 1.0 if look == LOOK else 0.75
			Pen.shape(self, Pen.ellipse(c, 12, 10 * open + (2.0 if look == LOOK else 0.0), 14), Color(1, 1, 1), ink, 2.0, pseed + 22 + sd)
			var dir := (to_local(target) - hop - c).normalized()
			if look == WARN:
				dir = Vector2(0, 1).lerp(dir, clampf(1.0 - timer / warn_time, 0.0, 1.0)).normalized()
			draw_circle(c + dir * 5.0, 5.0 if look == LOOK else 4.0, ink)
		# brows
		var raise := 6.0 if look == LOOK else 0.0
		var inner := judge * 7.0 if look != AWAY else 0.0
		var b_in := c + Vector2(-13 * sd, -17 - raise + inner)
		var b_out := c + Vector2(13 * sd, -17 - raise)
		Pen.line(self, b_in, b_out, hair.darkened(0.2), 4.0, pseed + 26 + sd)
	if "glasses" in acc:
		for sd in [-1, 1]:
			var c := hc + Vector2(22 * sd, -7)
			Pen.outline(self, Pen.ellipse(c, 17, 15, 20), ink, 2.5, pseed + 40 + sd)
			if look == LOOK:
				Pen.line(self, c + Vector2(-8, 6), c + Vector2(4, -8), Color(1, 1, 1, 0.9), 3.0, pseed + 42 + sd)
		Pen.line(self, hc + Vector2(-5, -8), hc + Vector2(5, -8), ink, 2.5, pseed + 44)

	# nose + mouth
	Pen.outline(self, Pen.poly([hc + Vector2(0, 2), hc + Vector2(-7, 20), hc + Vector2(4, 22)]), ink, 2.0, pseed + 45, false)
	var mc := hc + Vector2(0, 40)
	if talking and fmod(t * 9.0, 1.0) < 0.6:
		Pen.shape(self, Pen.ellipse(mc, 12, 5 + 5 * absf(sin(t * 14.0)), 16), Color(0.45, 0.12, 0.15), ink, 2.0, pseed + 46)
	else:
		var curve := lerpf(4.0, -5.0, judge)
		Pen.outline(self, Pen.poly([mc + Vector2(-14, 0), mc + Vector2(0, curve), mc + Vector2(14, 0)]), ink, 3.0, pseed + 47, false)
	if "mustache" in acc:
		Pen.shape(self, Pen.poly([mc + Vector2(-26, -4), mc + Vector2(0, -12), mc + Vector2(26, -4), mc + Vector2(18, 2), mc + Vector2(0, -4), mc + Vector2(-18, 2)]), hair.darkened(0.1), ink, 1.5, pseed + 48)

	# hands and prop
	for sd in [-1, 1]:
		Pen.shape(self, Pen.ellipse(Vector2(70 * sd, -12), 18, 14, 14), skin, ink, 2.0, pseed + 50 + sd)
	match prop:
		"clipboard":
			var r := Pen.xf(Pen.rect(Rect2(-50, -70, 100, 70)), Vector2(0, -35), 1.0, Vector2(0, 0), 0.08)
			Pen.shape(self, r, Color(0.7, 0.5, 0.3), ink, 2.5, pseed + 52)
			Pen.shape(self, Pen.xf(Pen.rect(Rect2(-42, -64, 84, 58)), Vector2(0, -35), 1.0, Vector2.ZERO, 0.08), Color(1, 1, 1), ink, 1.5, pseed + 53)
			for k in 4:
				Pen.line(self, Vector2(-32, -52 + k * 12).rotated(0.08), Vector2(28, -52 + k * 12).rotated(0.08), Color(0.5, 0.5, 0.6), 1.5, pseed + 54 + k)
		"glass":
			var g := Vector2(-78, -30)
			Pen.shape(self, Pen.poly([g + Vector2(-14, -40), g + Vector2(14, -40), g + Vector2(8, -16), g + Vector2(-8, -16)]), Color(0.6, 0.1, 0.2, 0.8), ink, 1.5, pseed + 60)
			Pen.line(self, g + Vector2(0, -16), g + Vector2(0, 2), ink, 2.0, pseed + 61)
		"fork":
			Pen.line(self, Vector2(72, -12), Vector2(80, -70), Color(0.7, 0.7, 0.75), 4.0, pseed + 62)
			for k in 3:
				Pen.line(self, Vector2(74 + k * 4, -70), Vector2(76 + k * 4, -84), Color(0.7, 0.7, 0.75), 2.0, pseed + 63 + k)

	# warning mark
	if look == WARN and weight >= 0.5:
		var bob := sin(t * 20.0) * 3.0
		Pen.text(self, Pen.bold(), hc + Vector2(-8, -100 + bob), "!", 44, Color(0.9, 0.35, 0.1), pseed + 70)
	elif look == WARN:
		Pen.text(self, Pen.bold(), hc + Vector2(-6, -95), "!", 34, Color(0.9, 0.35, 0.1), pseed + 70)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	Pen.base = old


func _hair_front(hc: Vector2, ink: Color) -> void:
	match hstyle:
		"bun", "short", "long", "veil":
			var cap := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				cap.append(hc + Vector2(cos(a) * 62.0, sin(a) * 58.0 - 18.0))
			cap.append(hc + Vector2(40, -30))
			cap.append(hc + Vector2(0, -44))
			cap.append(hc + Vector2(-40, -30))
			Pen.shape(self, cap, Color(0.95, 0.95, 0.97) if hstyle == "veil" else hair, ink, 2.5, pseed + 80)
			if hstyle == "veil":
				Pen.shape(self, Pen.ellipse(hc + Vector2(0, -70), 30, 10, 16), Pen.RISO_PINK, ink, 1.5, pseed + 81)
		"curly":
			for k in 11:
				var a := PI * 0.95 + PI * 1.1 * k / 10.0
				var c := hc + Vector2(cos(a) * 58.0, sin(a) * 60.0 - 12.0)
				Pen.shape(self, Pen.ellipse(c, 24, 22, 16), hair, ink, 2.0, pseed + 82 + k)
		"bald":
			for sd in [-1, 1]:
				Pen.shape(self, Pen.ellipse(hc + Vector2(52 * sd, -18), 12, 26, 14), hair, ink, 2.0, pseed + 95 + sd)
		"tophat":
			Pen.shape(self, Pen.rect(Rect2(hc.x - 70, hc.y - 62, 140, 14)), Pen.ink, ink, 2.0, pseed + 97)
			Pen.shape(self, Pen.rect(Rect2(hc.x - 42, hc.y - 150, 84, 92)), Pen.ink, ink, 2.0, pseed + 98)
			Pen.shape(self, Pen.rect(Rect2(hc.x - 42, hc.y - 80, 84, 14)), Pen.RISO_PINK, ink, 1.5, pseed + 99)
