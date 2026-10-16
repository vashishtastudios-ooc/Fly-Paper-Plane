class_name FoldingLoader
extends Control
## Loading animation: a sheet of paper folds itself into a paper plane (top corners to the
## middle, the edges in again, then in half) in step with the loading, so the last fold lands as
## loading finishes; then the finished plane flies off and `finished` is emitted.

signal finished

## Returns loading progress 0..1.
var progress_source: Callable
var _pos := 0.0
var _done := false

const SHEET := Vector2(1.0, 1.4)
## Fastest folding speed (folds per second) when catching up with the loading.
const FOLD_SPEED := 5.0
const PAUSE := 0.0
const FLY_TIME := 0.55
const FRONT := Color("#ffffff")
const BACK := Color("#efe3c8")
const EDGE := Color(0.32, 0.25, 0.18, 0.55)

## Each fold: a line (two points in sheet units) and a point on the side that folds over.
var _folds := [
	[Vector2(0.5, 0.0), Vector2(0.0, 0.5), Vector2(0.05, 0.05)],
	[Vector2(0.5, 0.0), Vector2(1.0, 0.5), Vector2(0.95, 0.05)],
	[Vector2(0.5, 0.0), Vector2(0.0, 1.207), Vector2(0.05, 0.9)],
	[Vector2(0.5, 0.0), Vector2(1.0, 1.207), Vector2(0.95, 0.9)],
	[Vector2(0.5, 0.0), Vector2(0.5, 1.4), Vector2(0.1, 0.9)],
]

var _t := 0.0
## Paper pieces: {"pts": PackedVector2Array, "back": bool}, drawn in order (later on top).
var _pieces: Array = []
var _step := 0
var _fly := 0.0
var _label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_label = UIKit.label("Folding the plane...", UIKit.display_font(), 48, UIKit.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_reset()


func _reset() -> void:
	_pieces = [{"pts": PackedVector2Array([Vector2.ZERO, Vector2(SHEET.x, 0), SHEET, Vector2(0, SHEET.y)]), "back": false}]
	_step = 0
	_t = 0.0
	_fly = 0.0


func _process(delta: float) -> void:
	var dt := minf(delta, 0.1)
	var prog := clampf(float(progress_source.call()), 0.0, 1.0) if progress_source.is_valid() else 1.0
	# Follow the loading: each fold is a fifth of it; never faster than FOLD_SPEED.
	var target := prog * _folds.size()
	_pos = move_toward(_pos, target, FOLD_SPEED * dt)
	while _step < _folds.size() and _pos >= _step + 1:
		_apply_fold(_folds[_step])
		_step += 1
	_t = _pos - _step
	if _step >= _folds.size():
		_fly += dt
		if _fly >= FLY_TIME and not _done:
			_done = true
			finished.emit()
	var s := get_viewport_rect().size
	_label.size = Vector2(s.x, 60)
	_label.position = Vector2(0, s.y * 0.5 + _scale() * SHEET.y * 0.5 + 24.0)
	queue_redraw()


func _scale() -> float:
	var s := get_viewport_rect().size
	return clampf(minf(s.x, s.y) * 0.42, 140.0, 340.0)


func _origin() -> Vector2:
	var s := get_viewport_rect().size
	return s * 0.5 - SHEET * _scale() * 0.5 - Vector2(0, 30)


func _to_screen(p: Vector2) -> Vector2:
	return _origin() + p * _scale()


## Signed distance from the fold line (positive on the flap side).
func _side(p: Vector2, a: Vector2, b: Vector2, flap: Vector2) -> float:
	var n := (b - a).orthogonal().normalized()
	if (flap - a).dot(n) < 0.0:
		n = -n
	return (p - a).dot(n)


## Splits a convex polygon by the line: [stay part, flap part].
func _split(pts: PackedVector2Array, a: Vector2, b: Vector2, flap: Vector2) -> Array:
	var stay := PackedVector2Array()
	var move := PackedVector2Array()
	for i in pts.size():
		var p := pts[i]
		var q := pts[(i + 1) % pts.size()]
		var dp := _side(p, a, b, flap)
		var dq := _side(q, a, b, flap)
		if dp <= 0.0:
			stay.append(p)
		if dp >= 0.0:
			move.append(p)
		if (dp < 0.0 and dq > 0.0) or (dp > 0.0 and dq < 0.0):
			var x := p.lerp(q, dp / (dp - dq))
			stay.append(x)
			move.append(x)
	return [stay, move]


## A point of the folding flap at progress t (0 flat, 1 folded over): it swings across the line.
func _fold_point(p: Vector2, a: Vector2, b: Vector2, flap: Vector2, t: float) -> Vector2:
	var n := (b - a).orthogonal().normalized()
	if (flap - a).dot(n) < 0.0:
		n = -n
	var d := (p - a).dot(n)
	return p - n * d * (1.0 - cos(PI * t))


func _apply_fold(f: Array) -> void:
	var out: Array = []
	var flipped: Array = []
	for pc in _pieces:
		var parts := _split(pc.pts, f[0], f[1], f[2])
		if (parts[0] as PackedVector2Array).size() >= 3:
			out.append({"pts": parts[0], "back": pc.back})
		if (parts[1] as PackedVector2Array).size() >= 3:
			var r := PackedVector2Array()
			for p in parts[1]:
				r.append(_fold_point(p, f[0], f[1], f[2], 1.0))
			flipped.push_front({"pts": r, "back": not pc.back})
	_pieces = out + flipped


func _poly(pts: PackedVector2Array, col: Color) -> void:
	var sp := PackedVector2Array()
	for p in pts:
		sp.append(_to_screen(p))
	draw_colored_polygon(sp, col)
	sp.append(sp[0])
	draw_polyline(sp, EDGE, 2.0, true)


func _draw() -> void:
	if _step >= _folds.size():
		_draw_flying()
		return
	var f: Array = _folds[_step]
	var t := smoothstep(0.0, 1.0, clampf(_t, 0.0, 1.0))
	var flat: Array = []
	var moving: Array = []
	for pc in _pieces:
		var parts := _split(pc.pts, f[0], f[1], f[2])
		if (parts[0] as PackedVector2Array).size() >= 3:
			flat.append([parts[0], pc.back])
		if (parts[1] as PackedVector2Array).size() >= 3:
			var r := PackedVector2Array()
			for p in parts[1]:
				r.append(_fold_point(p, f[0], f[1], f[2], t))
			moving.push_front([r, pc.back])
	# Soft shadow of the paper (where it is right now) on the table.
	for pc in flat + moving:
		var sp := PackedVector2Array()
		for p in pc[0]:
			sp.append(_to_screen(p) + Vector2(7, 11))
		draw_colored_polygon(sp, Color(0.35, 0.22, 0.1, 0.12))
	for pc in flat:
		_poly(pc[0], BACK if pc[1] else FRONT)
	for m in moving:
		# Past halfway the other side of the paper shows.
		var back: bool = m[1] != (t > 0.5)
		var col := BACK if back else FRONT
		_poly(m[0], col.darkened(0.12 * sin(PI * t)))


func _draw_flying() -> void:
	var k := _scale()
	var t := clampf(_fly / FLY_TIME, 0.0, 1.0)
	var start := _to_screen(Vector2(0.5, 0.7))
	var s := get_viewport_rect().size
	var end := Vector2(s.x + k, s.y * 0.2)
	var e := t * t
	var p := start.lerp(end, e) + Vector2(0, -sin(t * PI) * k * 0.4)
	# Dashed trail behind it.
	var trail := MenuUI.bezier(start, start + Vector2(k * 0.4, -k * 0.6), p + Vector2(-k * 0.5, k * 0.2), p, 18)
	MenuUI.draw_dashes(self, trail, Color(UIKit.INK_DARK, 0.6 * (1.0 - t)), 3.0)
	MenuUI.draw_paper_plane(self, p, k * 0.32, UIKit.INK_DARK, -0.5 + t * 0.2)
