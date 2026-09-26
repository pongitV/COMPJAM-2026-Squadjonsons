# Pen: stylized drawing shared by the whole game.
# Every shape goes through here, so the art style of the world follows the
# player's stress: clean art -> pencil sketch -> crayon chaos.
extends RefCounted

enum { FLAT, WATERCOLOR, RISO, COLLAGE }

static var stress := 0.0    # 0..1, drives the style
static var tick := 0        # "line boil" frame, changes a few times per second
static var base := FLAT     # base art style of the current scene
static var ink := Color(0.15, 0.15, 0.2)

const PAPER := Color(0.97, 0.95, 0.89)
const GRAPHITE := Color(0.25, 0.25, 0.3)
const RISO_PINK := Color(0.96, 0.36, 0.56)
const RISO_BLUE := Color(0.16, 0.38, 0.8)

static var _fonts := {}


# ---------------------------------------------------------------- fonts

static func sys_font(names: Array, weight := 400) -> Font:
	var key := str(names) + str(weight)
	if _fonts.has(key):
		return _fonts[key]
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	var fb: Array[Font] = [ThemeDB.fallback_font]
	f.fallbacks = fb
	_fonts[key] = f
	return f


static func hand() -> Font:
	return sys_font(["Segoe Print", "Comic Sans MS", "Chalkboard SE", "Bradley Hand"])


static func bold() -> Font:
	return sys_font(["Segoe UI Black", "Arial Black", "Impact", "Helvetica"], 900)


# ---------------------------------------------------------------- noise

static func _mix(h: int) -> float:
	h = ((h >> 13) ^ h) * 1274126177
	h = ((h >> 16) ^ h) * 668265263
	h = (h >> 15) ^ h
	return float(h & 0xFFFF) / 65535.0


# Random that changes every boil tick.
static func hrand(a: int, b: int = 0) -> float:
	return _mix((a * 73856093) ^ (b * 19349663) ^ (tick * 83492791))


# Random that never changes.
static func srand(a: int, b: int = 0) -> float:
	return _mix((a * 73856093) ^ (b * 19349663) ^ 1234567)


static func jv(a: int, b: int = 0) -> Vector2:
	return Vector2(hrand(a, b) - 0.5, hrand(a, b + 101) - 0.5) * 2.0


# Sketch factor: 0 while composed, 1 when the world is pure pencil.
static func sk() -> float:
	return clampf((stress - 0.35) / 0.3, 0.0, 1.0)


# Chaos factor: crayon, wrong colors, everything trembling.
static func ch() -> float:
	return clampf((stress - 0.7) / 0.3, 0.0, 1.0)


static func amp() -> float:
	var a := 0.35 + stress * stress * 8.0
	if base == WATERCOLOR:
		a += 0.8
	return a


static func style_name() -> String:
	if stress >= 0.7:
		return "giz de cera em pânico"
	if stress >= 0.35:
		return "rabisco a lápis"
	match base:
		WATERCOLOR:
			return "aquarela"
		RISO:
			return "risografia"
	return "vetor corporativo"


# ---------------------------------------------------------------- geometry

static func ellipse(c: Vector2, rx: float, ry: float, n := 28, rot := 0.0) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func rect(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


static func rrect(r: Rect2, rad: float, seg := 4) -> PackedVector2Array:
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var pts := PackedVector2Array()
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		var c: Vector2 = cs[k]
		for i in seg + 1:
			var a := -PI * 0.5 + PI * 0.5 * (k + float(i) / seg)
			pts.append(c + Vector2(cos(a), sin(a)) * rad)
	return pts


static func poly(arr: Array) -> PackedVector2Array:
	return PackedVector2Array(arr)


static func xf(pts: PackedVector2Array, ctr: Vector2, sc: float, off: Vector2, rot := 0.0) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = ctr + ((pts[i] - ctr) * sc).rotated(rot) + off
	return out


static func centroid(pts: PackedVector2Array) -> Vector2:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	return c / maxf(1.0, pts.size())


static func bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r


# Splits long edges so the wobble looks hand drawn instead of moving corners.
static func subdiv(pts: PackedVector2Array, step: float, closed := true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	var last := n if closed else n - 1
	for i in last:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		out.append(a)
		var k := int(a.distance_to(b) / step)
		for j in range(1, k + 1):
			out.append(a.lerp(b, float(j) / (k + 1)))
	if not closed:
		out.append(pts[n - 1])
	return out


static func wobble(pts: PackedVector2Array, sid: int, a: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = pts[i] + jv(sid + i * 31) * a
	return out


# ---------------------------------------------------------------- color

static func tint(c: Color, sid: int) -> Color:
	var orig := c
	var k := sk()
	if k > 0.0:
		var g := c.get_luminance()
		c = c.lerp(Color(g, g, g * 0.97, c.a), k * 0.75).lerp(Color(PAPER, c.a), k * 0.2)
	var x := ch()
	if x > 0.0:
		var h := fposmod(orig.h + (hrand(sid, 5) - 0.5) * 0.9 * x, 1.0)
		var cc := Color.from_hsv(h, clampf(orig.s + 0.55, 0.0, 1.0), clampf(orig.v + 0.1, 0.3, 1.0), c.a)
		c = c.lerp(cc, x * 0.85)
	return c


# ---------------------------------------------------------------- drawing

static func fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, sid: int, mode := -1) -> void:
	if pts.size() < 3:
		return
	var m := base if mode < 0 else mode
	var c := tint(col, sid)
	var k := sk()
	var a := c.a * (1.0 - k * 0.5)
	match m:
		WATERCOLOR:
			var ctr := centroid(pts)
			for i in 3:
				var off := Vector2(srand(sid, i) - 0.5, srand(sid, i + 9) - 0.5) * 8.0
				var sc := 1.0 + (srand(sid, i + 20) - 0.5) * 0.07
				ci.draw_colored_polygon(xf(pts, ctr, sc, off), Color(c, a * 0.42))
			ci.draw_polyline(_closed(pts), Color(c.darkened(0.3), a * 0.4), 2.2, true)
		RISO:
			ci.draw_colored_polygon(xf(pts, Vector2.ZERO, 1.0, Vector2(3, -2)), Color(c, a * 0.93))
		_:
			ci.draw_colored_polygon(pts, Color(c, a))
	if k > 0.0:
		hatch(ci, pts, Color(GRAPHITE, 0.5 * k), sid, lerpf(18.0, 8.0, k), 0.8)
	var x := ch()
	if x > 0.0:
		scribble(ci, pts, sid, x)


static func outline(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, sid: int, closed := true, mode := -1) -> void:
	if pts.size() < 2:
		return
	var m := base if mode < 0 else mode
	var k := sk()
	var c := tint(col, sid + 3).lerp(GRAPHITE, k * 0.6)
	var src := subdiv(pts, 26.0, closed)
	var passes := 1 + int(stress * 2.6)
	var a := amp()
	for p in passes:
		var w := wobble(src, sid + p * 977, a * (1.0 + p * 0.8))
		if closed:
			w.append(w[0])
		if m == RISO:
			w = xf(w, Vector2.ZERO, 1.0, Vector2(-1.5, 1.0))
		var alpha := c.a * (1.0 if p == 0 else 0.5)
		if m == WATERCOLOR:
			alpha *= 0.75
		ci.draw_polyline(w, Color(c, alpha), maxf(1.0, width * (1.0 - p * 0.3)), true)


static func shape(ci: CanvasItem, pts: PackedVector2Array, fcol: Color, lcol: Color, width: float, sid: int, mode := -1) -> void:
	fill(ci, pts, fcol, sid, mode)
	if width > 0.0:
		outline(ci, pts, lcol, width, sid, true, mode)


static func line(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, width: float, sid: int, mode := -1) -> void:
	outline(ci, PackedVector2Array([a, b]), col, width, sid, false, mode)


static func hatch(ci: CanvasItem, pts: PackedVector2Array, col: Color, sid: int, spacing: float, ang: float) -> void:
	var bb := bounds(pts)
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	var ctr := bb.get_center()
	var r := bb.size.length() * 0.5 + 2.0
	var a := amp()
	var o := -r + srand(sid, 3) * spacing
	var i := 0
	while o < r:
		var p1 := ctr + n * o - d * r + jv(sid, i) * a
		var p2 := ctr + n * o + d * r + jv(sid, i + 50) * a
		for seg in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([p1, p2]), pts):
			ci.draw_polyline(seg, col, 1.2, true)
		o += spacing
		i += 1


static func scribble(ci: CanvasItem, pts: PackedVector2Array, sid: int, x: float) -> void:
	var bb := bounds(pts)
	var n := int(clampf(bb.size.length() / 16.0, 4.0, 50.0))
	var zig := PackedVector2Array()
	for i in n:
		var t := float(i) / (n - 1)
		var px := bb.position.x if i % 2 == 0 else bb.end.x
		zig.append(Vector2(px, bb.position.y + t * bb.size.y) + jv(sid, i + 300) * 14.0)
	var crayon := Color.from_hsv(hrand(sid, 77), 0.85, 0.95, 0.5 * x)
	for seg in Geometry2D.intersect_polyline_with_polygon(zig, pts):
		ci.draw_polyline(seg, crayon, 3.0, true)


static func dots(ci: CanvasItem, r: Rect2, col: Color, spacing: float, size_at: Callable) -> void:
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var x := r.position.x + (spacing * 0.5 if row % 2 == 1 else 0.0)
		while x < r.end.x:
			var s: float = size_at.call(Vector2(x, y))
			if s > 0.4:
				ci.draw_circle(Vector2(x, y), s, col)
			x += spacing
		y += spacing * 0.87
		row += 1


static func dashed(ci: CanvasItem, pts: PackedVector2Array, col: Color, width: float, closed := true) -> void:
	var src := subdiv(pts, 8.0, closed)
	if closed:
		src.append(src[0])
	for i in range(0, src.size() - 1, 2):
		ci.draw_line(src[i], src[i + 1], col, width, true)


static func _closed(pts: PackedVector2Array) -> PackedVector2Array:
	var out := pts.duplicate()
	out.append(pts[0])
	return out


# ---------------------------------------------------------------- text

static func text_w(font: Font, s: String, size: int) -> float:
	return font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


# align: 0 left, 1 center, 2 right. pos.y is the baseline.
static func text(ci: CanvasItem, font: Font, pos: Vector2, s: String, size: int, col: Color, sid: int, align := 0) -> void:
	var w := text_w(font, s, size)
	var x := pos.x - (w * 0.5 if align == 1 else (w if align == 2 else 0.0))
	if stress < 0.3:
		ci.draw_string(font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		return
	var a := amp() * 0.45
	for i in s.length():
		var c := s[i]
		ci.draw_string(font, Vector2(x, pos.y) + jv(sid, i) * a, c, HORIZONTAL_ALIGNMENT_LEFT, -1, size, tint(col, sid + i))
		x += text_w(font, c, size)


static func wrap(font: Font, s: String, size: int, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var cur := ""
	for word in s.split(" "):
		var t: String = word if cur == "" else cur + " " + word
		if text_w(font, t, size) > width and cur != "":
			lines.append(cur)
			cur = word
		else:
			cur = t
	if cur != "":
		lines.append(cur)
	return lines


# Nervous speech: stutters, swapped letters and random shouting.
static func garble(s: String, st: float, sid: int) -> String:
	if st < 0.3:
		return s
	var p := (st - 0.3) / 0.7
	var words := s.split(" ")
	var out := PackedStringArray()
	for i in words.size():
		var w: String = words[i]
		var r := srand(sid, i)
		if w.length() > 2 and r < p * 0.4:
			w = w.substr(0, 1) + "-" + w.substr(0, 1).to_lower() + "-" + w
		elif w.length() > 3 and r < p * 0.7:
			var j := 1 + int(srand(sid, i + 40) * (w.length() - 2))
			w = w.substr(0, j - 1) + w[j] + w[j - 1] + w.substr(j + 1)
		elif r > 1.0 - p * 0.2:
			w = w.to_upper()
		out.append(w)
	if p > 0.55 and srand(sid, 99) < p:
		out.append("hehe...")
	return " ".join(out)
