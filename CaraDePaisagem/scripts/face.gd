# The player's face: a paper collage whose pieces want to drift apart.
# Loose pieces float away from the head; the player drags them back,
# holds trembling ones, tapes them, wipes sweat and picks an expression.
extends Node2D

const Pen = preload("res://scripts/pen.gd")

signal snapped
signal dripped
signal popped(count: int)
signal held
signal note(text: String, pos: Vector2, col: Color)

const RX := 150.0
const RY := 188.0
const SKIN := Color(0.98, 0.79, 0.64)
const HAIR := Color(0.33, 0.2, 0.14)
const LIP := Color(0.78, 0.24, 0.3)

const SLOTS := [
	{"kind": "ear", "home": Vector2(-150, 0), "side": -1},
	{"kind": "ear", "home": Vector2(150, 0), "side": 1},
	{"kind": "hair", "home": Vector2(0, -168), "side": 0},
	{"kind": "brow", "home": Vector2(-60, -82), "side": -1},
	{"kind": "brow", "home": Vector2(60, -82), "side": 1},
	{"kind": "eye", "home": Vector2(-60, -38), "side": -1},
	{"kind": "eye", "home": Vector2(60, -38), "side": 1},
	{"kind": "nose", "home": Vector2(0, 22), "side": 0},
	{"kind": "mouth", "home": Vector2(0, 94), "side": 0},
]

const GRAB := {"hair": 95.0, "ear": 48.0, "brow": 48.0, "eye": 48.0, "nose": 45.0, "mouth": 55.0}
const SNAP := {"hair": 95.0, "ear": 60.0, "brow": 50.0, "eye": 55.0, "nose": 60.0, "mouth": 65.0}


class Part:
	var kind := ""
	var side := 0
	var pos := Vector2.ZERO
	var vel := Vector2.ZERO
	var rot := 0.0
	var spin := 0.0
	var slot := -1
	var itch := -1.0     # seconds until it pops, -1 = calm
	var hold := 0.0      # how long the player has been holding it
	var tape := 0.0      # seconds of tape left
	var tape_ang := 0.0
	var pop := 0.0       # snap animation
	var id := 0


var parts: Array = []
var owner_of: Array = []        # part index per slot, -1 = empty
var sweat: Array = []           # {pos, speed, id}
var expr := 0                   # 0 serious, 1 smile, 2 sad
var puff := 0.0                 # cheeks puffed while holding breath
var tapes := 3
var drift := 1.0
var outfit := 0
var active := true
var dragging := -1
var holding := -1
var drag_off := Vector2.ZERO
var mouse_vel := Vector2.ZERO
var last_mouse := Vector2.ZERO
var mouse_down := false
var blink := 0.0
var blink_t := 3.0
var shake := 0.0
var loosen := 0.0
var t := 0.0
var stats := {"snaps": 0, "pops": 0, "tapes": 0, "wipes": 0, "holds": 0}
var hair_pts := PackedVector2Array()


func _ready() -> void:
	for i in SLOTS.size():
		var p := Part.new()
		p.kind = SLOTS[i]["kind"]
		p.side = SLOTS[i]["side"]
		p.pos = SLOTS[i]["home"]
		p.slot = i
		p.id = 100 + i * 17
		parts.append(p)
		owner_of.append(i)
	# toupee: round top and a zigzag fringe
	for i in 21:
		var a := PI + PI * i / 20.0
		hair_pts.append(Vector2(cos(a) * 152.0, sin(a) * 72.0 + 20.0))
	for j in 10:
		var x := 150.0 - 300.0 * j / 9.0
		hair_pts.append(Vector2(x, 24.0 if j % 2 == 0 else 48.0))


# ---------------------------------------------------------------- queries

func missing() -> int:
	var n := 0
	for p in parts:
		if p.slot == -1:
			n += 1
	return n


func itching() -> int:
	var n := 0
	for p in parts:
		if p.slot != -1 and p.itch >= 0.0:
			n += 1
	return n


func sweat_count() -> int:
	return sweat.size()


# Expression as seen from outside: 3 = puffed cheeks, 4 = no mouth.
func face_expr() -> int:
	if puff > 0.3:
		return 3
	if owner_of[8] == -1:
		return 4
	return expr


func set_expr(e: int) -> void:
	if e != expr:
		expr = e
		Sfx.play("click", -8.0, 0.8 + e * 0.2)


# ---------------------------------------------------------------- events

func pop_random(n: int, strength := 1.0) -> int:
	var cand := []
	for i in parts.size():
		if parts[i].slot != -1 and i != holding:
			cand.append(i)
	cand.shuffle()
	var count := 0
	for k in mini(n, cand.size()):
		var p: Part = parts[cand[k]]
		if p.tape > 0.0:
			p.tape = maxf(0.0, p.tape - 5.0)
			p.pop = 0.6
			note.emit("a fita segurou!", to_global(p.pos), Color(0.6, 0.45, 0.2))
			continue
		_detach(cand[k], strength)
		count += 1
	if count > 0:
		Sfx.play("boing", -2.0, randf_range(0.9, 1.15))
		shake = 1.0
		popped.emit(count)
	return count


func jolt(chance: float) -> void:
	shake = 1.6
	var count := 0
	for i in parts.size():
		var p: Part = parts[i]
		if p.slot == -1 or i == holding:
			continue
		if p.tape > 0.0:
			p.tape = maxf(0.0, p.tape - 3.0)
			continue
		if randf() < chance:
			_detach(i, 1.2)
			count += 1
	if count > 0:
		Sfx.play("boing", 0.0, 0.8)
		popped.emit(count)


func explode() -> void:
	for i in parts.size():
		parts[i].tape = 0.0
		_detach(i, 1.8)
	dragging = -1
	holding = -1


func start_itch(n: int) -> void:
	var cand := []
	for i in parts.size():
		var p: Part = parts[i]
		if p.slot != -1 and p.itch < 0.0 and p.tape <= 0.0:
			cand.append(i)
	cand.shuffle()
	for k in mini(n, cand.size()):
		var p: Part = parts[cand[k]]
		p.itch = randf_range(2.4, 3.2) / (0.8 + drift * 0.2)
		p.hold = 0.0


func add_sweat(n: int) -> void:
	for i in n:
		var pos := Vector2(randf_range(-95.0, 95.0), randf_range(-150.0, -100.0))
		sweat.append({"pos": pos, "speed": randf_range(7.0, 13.0), "id": randi() % 9999})


# ---------------------------------------------------------------- input (called by the level)

func press(gp: Vector2) -> void:
	if not active:
		return
	mouse_down = true
	var m := to_local(gp)
	var best := -1
	var bd := 1e9
	for i in parts.size():
		var p: Part = parts[i]
		if p.slot == -1:
			var d := p.pos.distance_to(m)
			if d < GRAB[p.kind] and d < bd:
				bd = d
				best = i
	if best != -1:
		dragging = best
		drag_off = parts[best].pos - m
		Sfx.play("grab", -4.0)
		return
	if _wipe(m):
		return
	best = _attached_at(m)
	if best != -1:
		holding = best
		if parts[best].itch >= 0.0:
			Sfx.play("grab", -6.0, 0.7)


func release() -> void:
	mouse_down = false
	if dragging != -1:
		var p: Part = parts[dragging]
		var s := _free_slot_near(p)
		if s != -1:
			_attach(dragging, s)
		else:
			p.vel = mouse_vel.limit_length(900.0) * 0.5
		dragging = -1
	holding = -1


func tape_at(gp: Vector2) -> void:
	if not active:
		return
	var i := _attached_at(to_local(gp))
	if i == -1:
		return
	if tapes <= 0:
		Sfx.play("nope", -6.0)
		note.emit("acabou a fita!", gp, Color(0.8, 0.2, 0.2))
		return
	var p: Part = parts[i]
	p.tape = 14.0
	p.tape_ang = randf_range(-0.5, 0.5)
	p.itch = -1.0
	tapes -= 1
	stats["tapes"] += 1
	Sfx.play("tape", -2.0)


func _attached_at(m: Vector2) -> int:
	var best := -1
	var bd := 1e9
	for i in parts.size():
		var p: Part = parts[i]
		if p.slot == -1:
			continue
		var d := p.pos.distance_to(m)
		if d < GRAB[p.kind] * 0.9 and d < bd:
			bd = d
			best = i
	return best


func _free_slot_near(p: Part) -> int:
	var best := -1
	var bd: float = SNAP[p.kind]
	for s in SLOTS.size():
		if SLOTS[s]["kind"] != p.kind or owner_of[s] != -1:
			continue
		var d := p.pos.distance_to(SLOTS[s]["home"])
		if d < bd:
			bd = d
			best = s
	return best


func _attach(i: int, s: int) -> void:
	var p: Part = parts[i]
	p.slot = s
	p.side = SLOTS[s]["side"]
	owner_of[s] = i
	p.pop = 1.0
	p.itch = -1.0
	p.vel = Vector2.ZERO
	stats["snaps"] += 1
	Sfx.play("pop", -1.0, randf_range(0.95, 1.1))
	snapped.emit()


func _detach(i: int, strength: float) -> void:
	var p: Part = parts[i]
	if p.slot == -1:
		return
	var home: Vector2 = SLOTS[p.slot]["home"]
	owner_of[p.slot] = -1
	p.slot = -1
	p.itch = -1.0
	p.hold = 0.0
	var dir := home.normalized() if home.length() > 5.0 else Vector2.DOWN
	dir = dir.rotated(randf_range(-0.9, 0.9))
	p.vel = dir * randf_range(260.0, 420.0) * strength
	p.spin = randf_range(-6.0, 6.0)
	stats["pops"] += 1
	if holding == i:
		holding = -1


func _wipe(m: Vector2) -> bool:
	var hit := false
	for k in range(sweat.size() - 1, -1, -1):
		if sweat[k]["pos"].distance_to(m) < 28.0:
			sweat.remove_at(k)
			stats["wipes"] += 1
			hit = true
	if hit:
		Sfx.play("wipe", -4.0, randf_range(0.9, 1.2))
	return hit


# ---------------------------------------------------------------- update

func _process(delta: float) -> void:
	t += delta
	var mouse := to_local(get_global_mouse_position())
	mouse_vel = mouse_vel.lerp((mouse - last_mouse) / maxf(delta, 0.001), 0.35)
	last_mouse = mouse
	var s := Pen.stress
	shake = maxf(0.0, shake - delta * 3.0)

	blink_t -= delta
	if blink_t <= 0.0:
		blink = 0.13
		blink_t = randf_range(2.0, 4.5) * (1.0 - s * 0.6)
	blink = maxf(0.0, blink - delta)

	if active:
		loosen += delta
		if loosen >= 1.0:
			loosen -= 1.0
			if randf() < maxf(0.0, s - 0.5) * 0.4 * drift:
				start_itch(1)
		if mouse_down and dragging == -1:
			_wipe(mouse)
		if randf() < maxf(0.0, s - 0.45) * 0.5 * delta:
			add_sweat(1)

	for i in parts.size():
		var p: Part = parts[i]
		p.pop = maxf(0.0, p.pop - delta * 3.5)
		if p.tape > 0.0:
			p.tape = maxf(0.0, p.tape - delta)
		if p.slot != -1:
			var home: Vector2 = SLOTS[p.slot]["home"] + _expr_offset(p)
			p.pos = p.pos.lerp(home, 1.0 - pow(0.0005, delta))
			p.rot = lerp_angle(p.rot, 0.0, 1.0 - pow(0.001, delta))
			if p.itch >= 0.0 and active:
				if holding == i:
					p.hold += delta
					if p.hold >= 0.9:
						p.itch = -1.0
						p.hold = 0.0
						stats["holds"] += 1
						Sfx.play("held", -6.0)
						note.emit("segurou!", to_global(p.pos), Color(0.2, 0.55, 0.3))
						held.emit()
				else:
					p.itch -= delta
					if p.itch <= 0.0:
						_detach(i, 0.8)
						Sfx.play("boing", -3.0, 1.2)
						popped.emit(1)
		elif i == dragging:
			var target := mouse + drag_off
			p.pos = p.pos.lerp(target, 1.0 - pow(0.00002, delta))
			p.rot = lerp_angle(p.rot, 0.0, 1.0 - pow(0.02, delta))
		else:
			var away := p.pos.normalized() if p.pos.length() > 1.0 else Vector2.RIGHT
			p.vel += away * (22.0 + 45.0 * s) * drift * delta
			p.vel *= pow(0.5, delta)
			p.pos += p.vel * delta
			p.rot += p.spin * delta
			p.spin *= pow(0.6, delta)
			_bounce(p)

	for k in range(sweat.size() - 1, -1, -1):
		var d: Dictionary = sweat[k]
		var pos: Vector2 = d["pos"]
		pos.y += d["speed"] * delta
		pos.x += signf(pos.x) * delta * 3.0
		d["pos"] = pos
		if pos.y > 150.0:
			sweat.remove_at(k)
			dripped.emit()

	_cursor(mouse)
	queue_redraw()


func _bounce(p: Part) -> void:
	var r := Rect2(-global_position + Vector2(40, 110), Vector2(1200, 560))
	if p.pos.x < r.position.x:
		p.pos.x = r.position.x
		p.vel.x = absf(p.vel.x) * 0.5
	elif p.pos.x > r.end.x:
		p.pos.x = r.end.x
		p.vel.x = -absf(p.vel.x) * 0.5
	if p.pos.y < r.position.y:
		p.pos.y = r.position.y
		p.vel.y = absf(p.vel.y) * 0.5
	elif p.pos.y > r.end.y:
		p.pos.y = r.end.y
		p.vel.y = -absf(p.vel.y) * 0.5


func _cursor(m: Vector2) -> void:
	if not active:
		return
	var shape := Input.CURSOR_ARROW
	if dragging != -1 or holding != -1:
		shape = Input.CURSOR_DRAG
	else:
		for p in parts:
			if p.slot == -1 and p.pos.distance_to(m) < GRAB[p.kind]:
				shape = Input.CURSOR_POINTING_HAND
				break
	Input.set_default_cursor_shape(shape)


func _expr_offset(p: Part) -> Vector2:
	if p.kind == "brow":
		if expr == 1:
			return Vector2(0, -8)
		if expr == 2:
			return Vector2(0, -4)
	return Vector2.ZERO


# ---------------------------------------------------------------- drawing

func _paper(pts: PackedVector2Array, col: Color, sid: int, lift := 0.0) -> void:
	var sh := Vector2(3, 5) + Vector2(9, 14) * lift
	draw_colored_polygon(Pen.xf(pts, Vector2.ZERO, 1.0, sh), Color(0, 0, 0, 0.12 + 0.06 * lift))
	Pen.outline(self, pts, Color.WHITE, 7.0, sid, true, Pen.COLLAGE)
	Pen.fill(self, pts, col, sid, Pen.COLLAGE)
	Pen.outline(self, pts, col.darkened(0.45), 1.4, sid + 5, true, Pen.COLLAGE)


func _draw() -> void:
	var sh := Pen.jv(7) * shake * 10.0
	draw_set_transform(sh, 0.0, Vector2.ONE)
	_draw_body()
	var head := Pen.ellipse(Vector2.ZERO, RX, RY, 40)
	_paper(head, SKIN, 1)
	# stress blush
	var s := Pen.stress
	if s > 0.2:
		for sd in [-1, 1]:
			draw_colored_polygon(Pen.ellipse(Vector2(95 * sd, 50), 34, 20, 18), Color(1, 0.35, 0.4, (s - 0.2) * 0.5))
	# puffed cheeks
	if puff > 0.05:
		for sd in [-1, 1]:
			var ck := Pen.ellipse(Vector2(100 * sd, 55), 30 + puff * 24, 26 + puff * 20, 20)
			_paper(ck, SKIN.lerp(Color(1, 0.6, 0.6), 0.3), 900 + sd)
	# ghost slots
	for i in SLOTS.size():
		if owner_of[i] == -1:
			var home: Vector2 = SLOTS[i]["home"]
			var kind: String = SLOTS[i]["kind"]
			var near := dragging != -1 and parts[dragging].kind == kind and parts[dragging].pos.distance_to(home) < SNAP[kind]
			var col := Color(0.95, 0.55, 0.1, 0.95) if near else Color(0.35, 0.25, 0.25, 0.35 + 0.2 * sin(t * 5.0))
			draw_set_transform(sh + home, 0.0, Vector2.ONE * (1.12 if near else 1.0))
			Pen.dashed(self, _shape(kind, SLOTS[i]["side"], 0), col, 3.0 if near else 2.0)
	draw_set_transform(sh, 0.0, Vector2.ONE)
	# attached parts
	for i in parts.size():
		if parts[i].slot != -1:
			_draw_part(i, sh)
	# sweat
	for d in sweat:
		var pos: Vector2 = d["pos"]
		var drop := _drop(pos, 7.0)
		Pen.shape(self, drop, Color(0.55, 0.82, 0.98, 0.9), Color(0.2, 0.45, 0.7), 1.5, d["id"], Pen.COLLAGE)
		draw_circle(pos + Vector2(-2, -2), 2.0, Color(1, 1, 1, 0.9))
	# loose parts on top, dragged last
	for i in parts.size():
		if parts[i].slot == -1 and i != dragging:
			_draw_part(i, sh)
	if dragging != -1:
		_draw_part(dragging, sh)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_part(i: int, sh: Vector2) -> void:
	var p: Part = parts[i]
	var pos := p.pos + sh
	var rot := p.rot
	var sc := 1.0 + p.pop * 0.25
	var loose := p.slot == -1
	var lift := 0.0
	if loose:
		lift = 1.0 if i == dragging else 0.5
		if i != dragging and p.pos.distance_to(last_mouse) < GRAB[p.kind]:
			sc *= 1.08
	if p.itch >= 0.0 and not loose:
		var k := 1.0 - clampf(p.itch / 2.5, 0.0, 1.0)
		var held_k := 0.3 if holding == i else 1.0
		pos += Vector2(sin(t * 47.0), cos(t * 39.0)) * (2.0 + k * 6.0) * held_k
		rot += sin(t * 31.0) * 0.12 * (0.3 + k) * held_k
	elif not loose:
		pos += Pen.jv(p.id) * Pen.stress * 2.5
	var side := p.side
	if p.kind == "brow" and not loose:
		if expr == 2:
			rot += side * 0.3
		elif expr == 1:
			rot += -side * 0.1
	draw_set_transform(pos, rot, Vector2.ONE * sc)
	_paper(_shape(p.kind, side, expr), _color(p.kind), p.id, lift)
	_details(p)
	if p.tape > 0.0:
		draw_set_transform(pos, rot + p.tape_ang, Vector2.ONE)
		var a := clampf(p.tape / 3.0, 0.2, 1.0)
		var tp := _tape_pts(40.0 if p.kind != "hair" else 70.0)
		draw_colored_polygon(tp, Color(0.96, 0.9, 0.7, 0.8 * a))
		Pen.outline(self, tp, Color(0.7, 0.6, 0.4, 0.8 * a), 1.2, p.id + 44, true, Pen.COLLAGE)
	if holding == i and p.itch >= 0.0:
		draw_set_transform(pos, 0.0, Vector2.ONE)
		var arc_end := -PI * 0.5 + TAU * clampf(p.hold / 0.9, 0.0, 1.0)
		draw_arc(Vector2.ZERO, 44.0, -PI * 0.5, arc_end, 32, Color(0.2, 0.6, 0.3), 5.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _color(kind: String) -> Color:
	match kind:
		"hair", "brow":
			return HAIR
		"eye":
			return Color(1, 1, 1)
		"nose":
			return SKIN.darkened(0.1)
		"mouth":
			return LIP
	return SKIN


func _shape(kind: String, side: int, e: int) -> PackedVector2Array:
	match kind:
		"hair":
			return hair_pts
		"ear":
			return Pen.ellipse(Vector2.ZERO, 26, 42, 20)
		"brow":
			return Pen.rrect(Rect2(-33, -8, 66, 16), 7)
		"eye":
			return Pen.ellipse(Vector2.ZERO, 32, 22, 24)
		"nose":
			return Pen.poly([Vector2(0, -40), Vector2(10, -8), Vector2(24, 14), Vector2(14, 26),
				Vector2(-14, 26), Vector2(-24, 14), Vector2(-10, -8)])
		"mouth":
			if puff > 0.3:
				return Pen.ellipse(Vector2.ZERO, 12, 13, 16)
			var pts := PackedVector2Array()
			match e:
				1:
					for k in 17:
						var a := PI * k / 16.0
						pts.append(Vector2(cos(a) * 46.0, 4.0 + sin(a) * 32.0))
					pts.append_array(Pen.poly([Vector2(-23, -3), Vector2(0, -5), Vector2(23, -3)]))
				2:
					for k in 17:
						var a := PI * k / 16.0
						pts.append(Vector2(cos(a) * 38.0, 8.0 - sin(a) * 22.0))
					pts.append_array(Pen.poly([Vector2(-19, 11), Vector2(0, 13), Vector2(19, 11)]))
				_:
					return Pen.rrect(Rect2(-38, -8, 76, 16), 7)
			return pts
	return Pen.ellipse(Vector2.ZERO, 20, 20)


func _details(p: Part) -> void:
	match p.kind:
		"eye":
			var closed := blink > 0.0 or (puff > 0.5)
			if closed:
				Pen.line(self, Vector2(-26, 2), Vector2(26, 2), Color(0.2, 0.15, 0.15), 3.0, p.id + 2, Pen.COLLAGE)
				return
			var look := (last_mouse - p.pos).rotated(-p.rot)
			var off := look.normalized() * minf(look.length() * 0.05, 9.0)
			if Pen.stress > 0.75:
				off += Pen.jv(p.id + 9) * 4.0
			draw_circle(off, 13.0, Pen.tint(Color(0.2, 0.55, 0.55), p.id))
			draw_circle(off, 6.5, Color(0.08, 0.06, 0.08))
			draw_circle(off + Vector2(-4, -4), 3.0, Color(1, 1, 1))
			if expr == 1 and p.slot != -1:
				draw_colored_polygon(Pen.ellipse(Vector2(0, 26), 36, 12, 16), SKIN)
		"ear":
			var arc := PackedVector2Array()
			for k in 9:
				var a := -1.2 + 2.4 * k / 8.0
				arc.append(Vector2(-cos(a) * 12.0 * p.side, sin(a) * 26.0))
			Pen.outline(self, arc, SKIN.darkened(0.35), 3.0, p.id + 1, false, Pen.COLLAGE)
		"nose":
			draw_colored_polygon(Pen.ellipse(Vector2(-9, 18), 5, 3, 10), SKIN.darkened(0.45))
			draw_colored_polygon(Pen.ellipse(Vector2(9, 18), 5, 3, 10), SKIN.darkened(0.45))
		"mouth":
			if expr == 1 and puff <= 0.3:
				draw_colored_polygon(Pen.rrect(Rect2(-30, 2, 60, 9), 3), Color(1, 1, 1))
		"hair":
			for k in 4:
				var x := -90.0 + k * 55.0
				Pen.line(self, Vector2(x, -30), Vector2(x + 25, 0), HAIR.lightened(0.25), 3.0, p.id + k, Pen.COLLAGE)


func _drop(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 13:
		var a := -PI * 0.5 + 0.55 + (TAU - 1.1) * i / 12.0
		pts.append(c + Vector2(cos(a), sin(a)) * r)
	pts.append(c + Vector2(0, -r * 2.2))
	return pts


func _tape_pts(w: float) -> PackedVector2Array:
	var h := 12.0
	return Pen.poly([Vector2(-w, -h), Vector2(w, -h), Vector2(w + 4, -h * 0.5), Vector2(w, 0),
		Vector2(w + 4, h * 0.5), Vector2(w, h), Vector2(-w, h), Vector2(-w - 4, h * 0.5),
		Vector2(-w, 0), Vector2(-w - 4, -h * 0.5)])


func _draw_body() -> void:
	var neck := Pen.rect(Rect2(-44, 140, 88, 110))
	_paper(neck, SKIN.darkened(0.12), 11)
	var body := Pen.poly([Vector2(-260, 430), Vector2(-235, 300), Vector2(-160, 250), Vector2(-55, 232),
		Vector2(55, 232), Vector2(160, 250), Vector2(235, 300), Vector2(260, 430)])
	match outfit:
		0:
			_paper(body, Color(0.95, 0.96, 0.98), 12)
			_paper(Pen.poly([Vector2(-58, 230), Vector2(0, 262), Vector2(-20, 292)]), Color(1, 1, 1), 13)
			_paper(Pen.poly([Vector2(58, 230), Vector2(0, 262), Vector2(20, 292)]), Color(1, 1, 1), 14)
			_paper(Pen.poly([Vector2(-14, 262), Vector2(14, 262), Vector2(26, 400), Vector2(0, 430), Vector2(-26, 400)]), Color(0.85, 0.2, 0.25), 15)
		1:
			_paper(body, Color(0.86, 0.6, 0.24), 12)
			_paper(Pen.ellipse(Vector2(0, 240), 70, 26, 24), Color(0.78, 0.52, 0.2), 13)
			var zig := PackedVector2Array()
			for k in 13:
				zig.append(Vector2(-240 + k * 40, 330 + (0 if k % 2 == 0 else 22)))
			Pen.outline(self, zig, Color(0.95, 0.9, 0.8), 6.0, 16, false, Pen.COLLAGE)
		_:
			_paper(body, Color(0.18, 0.22, 0.42), 12)
			_paper(Pen.poly([Vector2(-48, 232), Vector2(48, 232), Vector2(0, 360)]), Color(1, 1, 1), 13)
			_paper(Pen.poly([Vector2(-30, 250), Vector2(0, 262), Vector2(30, 250), Vector2(30, 276), Vector2(0, 264), Vector2(-30, 276)]), Pen.RISO_PINK, 14)
			for k in 6:
				var a := TAU * k / 6.0
				_paper(Pen.ellipse(Vector2(-150, 310) + Vector2(cos(a), sin(a)) * 14.0, 11, 11, 10), Pen.RISO_PINK.lightened(0.2), 20 + k)
			draw_circle(Vector2(-150, 310), 8.0, Color(1, 0.85, 0.3))
