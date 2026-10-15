class_name MenuUI
extends CanvasLayer
## Title screen and flight select: a torn scrapbook page with a photo card for each flight
## (a snapshot of its key moment), a big Play button, and paper chips for the Hangar, Settings
## and Credits. Tap a card to pick it, then Play (or tap the picked card again).

signal level_chosen(index: int)
signal hangar_pressed
signal settings_pressed
signal credits_pressed

const TITLE := "Paper Plane Playground"
const SUBTITLE := "Fun paper plane flying challenges"
const THUMB_PATH := "res://ui/thumbs/flight_%d.jpg"
const PAPER := Color("#fbf6ea")
const TAPE := Color("#f4a7b5")
const HIGHLIGHT := Color("#f8d24a")

var _root: Control
var _page: ScrapPage
var _title: Label
var _subtitle: Label
var _cards: Array[PhotoCard] = []
var _play: PaperChip
var _chips: Array[PaperChip] = []
var _hint: KeyHint
var _selected := 0


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_page = ScrapPage.new()
	_root.add_child(_page)
	_title = UIKit.label(TITLE, UIKit.display_font(), 72, UIKit.INK_DARK)
	_title.rotation = deg_to_rad(-3.0)
	_page.add_child(_title)
	_subtitle = UIKit.label(SUBTITLE, UIKit.display_font(), 32, UIKit.INK_DARK)
	_subtitle.rotation = deg_to_rad(-3.0)
	_page.add_child(_subtitle)
	for i in Game.levels.size():
		var card := PhotoCard.new()
		card.index = i
		card.thumb = load(THUMB_PATH % (i + 1)) if ResourceLoader.exists(THUMB_PATH % (i + 1)) else null
		card.title = Game.levels[i].level_name
		card.tilt = [-1.6, 1.1, -0.8, 1.5, 1.2, -1.3, 0.9][i % 7]
		card.pressed.connect(_on_card_pressed.bind(i))
		card.focus_entered.connect(_on_card_focus.bind(i))
		_page.add_child(card)
		_cards.append(card)
	_play = PaperChip.new()
	_play.text_label = "Play"
	_play.kind = "play"
	_play.pressed.connect(func():
		Audio.play("click", -6.0)
		_start(_selected))
	_root.add_child(_play)
	for def in [["Hangar", "hanger", hangar_pressed], ["Settings", "gear", settings_pressed], ["Credits", "book", credits_pressed]]:
		var chip := PaperChip.new()
		chip.text_label = def[0]
		chip.kind = def[1]
		var sig: Signal = def[2]
		chip.pressed.connect(func():
			Audio.play("click", -6.0)
			sig.emit())
		_root.add_child(chip)
		_chips.append(chip)
	_hint = KeyHint.new()
	_root.add_child(_hint)
	get_viewport().size_changed.connect(_layout)
	refresh()
	_layout()


func open() -> void:
	refresh()
	visible = true
	_layout()
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)
	var first := _first_unplayed()
	if first >= 0:
		_select(first)
	_cards[_selected].grab_focus()


func close() -> void:
	visible = false


func _first_unplayed() -> int:
	for i in _cards.size():
		if Game.is_unlocked(i) and not Game.best_scores.has(i):
			return i
	return -1


func refresh() -> void:
	for i in _cards.size():
		var card := _cards[i]
		card.unlocked = Game.is_unlocked(i)
		card.disabled = not card.unlocked
		card.best = Game.best_scores.get(i, -1)
		card.ribbons = int(Game.best_ribbons.get(i, 0))
		card.queue_redraw()
	if not Game.is_unlocked(_selected):
		_selected = 0
	_select(_selected)


func _select(i: int) -> void:
	_selected = i
	for c in _cards:
		c.selected = c.index == i
		c.queue_redraw()


func _on_card_focus(i: int) -> void:
	# Keyboard and gamepad focus picks the card; a mouse or touch press picks it on release.
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_select(i)


func _on_card_pressed(i: int) -> void:
	Audio.play("click", -6.0)
	if _selected == i:
		_start(i)
	else:
		_select(i)


func _start(i: int) -> void:
	if Game.is_unlocked(i):
		level_chosen.emit(i)


func _layout() -> void:
	var s := Settings.viewport_size()
	var portrait := s.y > s.x
	var page: Rect2
	if portrait:
		page = Rect2(s.x * 0.03, s.y * 0.02, s.x * 0.94, s.y * 0.7)
	else:
		var w := minf(s.x * 0.66, 1180.0)
		page = Rect2(s.x * 0.035, s.y * 0.03, w, s.y * 0.78)
	_page.position = page.position
	_page.size = page.size
	var k := clampf(page.size.x / 1000.0, 0.45, 1.25)
	# Title fitted to the page width.
	var inner_x := 70.0 * k
	var title_w := page.size.x - inner_x - 190.0 * k
	var ts := int(84.0 * k)
	while ts > 24 and UIKit.display_font().get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x > title_w:
		ts -= 2
	_title.add_theme_font_size_override("font_size", ts)
	_title.position = Vector2(inner_x + 20.0 * k, 18.0 * k)
	var sub_fs := int(ts * 0.42)
	_subtitle.add_theme_font_size_override("font_size", sub_fs)
	var sub_size := UIKit.display_font().get_string_size(SUBTITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, sub_fs)
	_subtitle.position = _title.position + Vector2(ts * 1.4, ts * 1.22)
	_page.subtitle_rect = Rect2(_subtitle.position + Vector2(-14, sub_size.y * 0.12), sub_size + Vector2(34, -sub_size.y * 0.08))
	_page.k = k
	# Cards: four across in landscape (4 + 3), two across in portrait.
	var cols := 2 if portrait else 4
	var rows := int(ceil(float(_cards.size()) / cols))
	var top := _subtitle.position.y + sub_size.y + 26.0 * k
	var area := Rect2(inner_x, top, page.size.x - inner_x - 26.0 * k, page.size.y - top - 30.0 * k)
	var gap := 16.0 * k
	var cw := (area.size.x - gap * (cols - 1)) / cols
	var ch := minf((area.size.y - gap * (rows - 1)) / rows, cw * 1.05)
	for i in _cards.size():
		var c := _cards[i]
		var col := i % cols
		var row := i / cols
		c.position = area.position + Vector2(col * (cw + gap), row * (ch + gap))
		c.size = Vector2(cw, ch)
		c.pivot_offset = c.size * 0.5
		c.rotation = deg_to_rad(c.tilt)
		c.k = k
		c.queue_redraw()
	# The empty slot after the last card gets the doodles.
	var last := _cards.size()
	_page.doodle_rect = Rect2(area.position + Vector2((last % cols) * (cw + gap), (last / cols) * (ch + gap)), Vector2(cw, ch)) if last % cols != 0 else Rect2()
	_page.queue_redraw()
	# Play and the paper chips below the page.
	var ck := clampf(s.x / 1600.0, 0.55, 1.0) if not portrait else clampf(s.x / 800.0, 0.6, 1.0)
	var play_size := Vector2(300, 110) * ck
	var base_y := page.end.y - play_size.y * 0.25
	_play.size = play_size
	_play.position = Vector2(page.get_center().x - play_size.x * 0.5, base_y)
	var chip_size := Vector2(190, 66) * ck
	var chip_y := base_y + play_size.y * 0.42
	if portrait:
		var total := chip_size.x * 3 + 24 * ck * 2
		for i in _chips.size():
			_chips[i].size = chip_size
			_chips[i].position = Vector2((s.x - total) * 0.5 + i * (chip_size.x + 24 * ck), _play.position.y + play_size.y + 14 * ck)
	else:
		_chips[0].size = chip_size
		_chips[0].position = Vector2(_play.position.x - chip_size.x - 30 * ck, chip_y)
		for i in [1, 2]:
			_chips[i].size = chip_size
			_chips[i].position = Vector2(_play.position.x + play_size.x + 30 * ck + (i - 1) * (chip_size.x + 20 * ck), chip_y)
	for c in _chips + [_play]:
		c.k = ck
		c.pivot_offset = c.size * 0.5
		c.queue_redraw()
	_hint.visible = not portrait
	_hint.k = ck
	_hint.size = Vector2(_hint.content_width(52 * ck), 52 * ck)
	_hint.position = Vector2(s.x - _hint.size.x - 24 * ck, s.y - _hint.size.y - 20 * ck)
	_hint.queue_redraw()


# --- Drawing helpers --------------------------------------------------------------------------

## A rectangle with slightly ragged (torn paper) edges.
static func torn_rect(r: Rect2, jag: float, seed_value: int, step := 14.0) -> PackedVector2Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pts := PackedVector2Array()
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for e in 4:
		var a: Vector2 = corners[e]
		var b: Vector2 = corners[(e + 1) % 4]
		var n := maxi(2, int(a.distance_to(b) / step))
		var normal := (b - a).normalized().orthogonal()
		for i in n:
			pts.append(a.lerp(b, float(i) / n) + normal * rng.randf_range(-jag, jag))
	return pts


static func draw_paper_plane(ci: CanvasItem, at: Vector2, s: float, col: Color, angle := -0.35) -> void:
	var xf := Transform2D(angle, at)
	var nose := xf * Vector2(s, 0)
	var tail_top := xf * Vector2(-s, -s * 0.55)
	var tail_bot := xf * Vector2(-s * 0.7, s * 0.45)
	var fold := xf * Vector2(-s * 0.45, s * 0.05)
	ci.draw_polyline(PackedVector2Array([nose, tail_top, fold, nose, tail_bot, fold]), col, maxf(1.5, s * 0.09), true)


static func draw_dashes(ci: CanvasItem, pts: PackedVector2Array, col: Color, w: float, dash := 9.0) -> void:
	var on := true
	var left := dash
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var seg := a.distance_to(b)
		var t := 0.0
		while t < seg:
			var step := minf(left, seg - t)
			if on:
				ci.draw_line(a.lerp(b, t / seg), a.lerp(b, (t + step) / seg), col, w, true)
			t += step
			left -= step
			if left <= 0.001:
				on = not on
				left = dash


static func bezier(a: Vector2, c1: Vector2, c2: Vector2, b: Vector2, n := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		var u := 1.0 - t
		pts.append(a * u * u * u + c1 * 3.0 * u * u * t + c2 * 3.0 * u * t * t + b * t * t * t)
	return pts


# --- The scrapbook page ----------------------------------------------------------------------

class ScrapPage extends Control:
	var k := 1.0
	var subtitle_rect := Rect2()
	var doodle_rect := Rect2()
	var _stamp_tex: Texture2D

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(MenuUI.THUMB_PATH % 2):
			_stamp_tex = load(MenuUI.THUMB_PATH % 2)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var ink := Color(UIKit.INK_DARK, 0.8)
		# Shadow, torn page, faint rules.
		draw_colored_polygon(MenuUI.torn_rect(Rect2(r.position + Vector2(8, 12) * k, r.size), 5.0 * k, 7), Color(0.2, 0.1, 0.02, 0.28))
		draw_colored_polygon(MenuUI.torn_rect(r, 5.0 * k, 3), MenuUI.PAPER)
		var y := 70.0 * k
		while y < size.y - 12.0:
			draw_line(Vector2(54 * k, y), Vector2(size.x - 10, y), Color(UIKit.RULE, 0.35), 1.2)
			y += 34.0 * k
		draw_rect(Rect2(0, size.y - 40 * k, size.x, 40 * k), Color(0.85, 0.72, 0.5, 0.12))
		# Spiral binding down the left edge.
		var n := int(size.y / (34.0 * k))
		for i in n:
			var cy := 24.0 * k + i * 34.0 * k
			draw_circle(Vector2(26 * k, cy), 6.0 * k, Color(0.32, 0.27, 0.22, 0.85))
			draw_arc(Vector2(16 * k, cy), 11.0 * k, -1.2, 1.9, 10, Color("#8a8f94"), 3.0 * k, true)
		# Paper clip at the top.
		var cp := Vector2(34 * k, -22 * k)
		var clip := PackedVector2Array([Vector2(0, 70), Vector2(0, 8), Vector2(10, 0), Vector2(20, 8), Vector2(20, 80),
			Vector2(10, 90), Vector2(4, 82), Vector2(4, 20), Vector2(10, 14), Vector2(15, 20), Vector2(15, 66)])
		for i in clip.size():
			clip[i] = cp + clip[i] * k
		draw_polyline(clip, Color("#9aa3a8"), 3.0 * k, true)
		# Yellow highlighter strip behind the subtitle.
		if subtitle_rect.size.x > 0.0:
			draw_set_transform(subtitle_rect.position, deg_to_rad(-3.0))
			draw_colored_polygon(MenuUI.torn_rect(Rect2(Vector2.ZERO, subtitle_rect.size), 2.0, 11, 18.0), Color(MenuUI.HIGHLIGHT, 0.75))
			draw_set_transform(Vector2.ZERO)
		# Doodles around the title: clouds, a house, a dashed flight path and a paper plane.
		_cloud(Vector2(size.x * 0.64, 152 * k), 10.0 * k, ink)
		_cloud(Vector2(size.x * 0.88, 150 * k), 9.0 * k, ink)
		if subtitle_rect.size.x > 0.0:
			var a := subtitle_rect.end + Vector2(10 * k, -subtitle_rect.size.y * 0.9)
			var trail := MenuUI.bezier(a, a + Vector2(30 * k, 20 * k), Vector2(size.x * 0.7, 150 * k), Vector2(size.x * 0.75, 110 * k), 16)
			MenuUI.draw_dashes(self, trail, ink, 2.4 * k)
		MenuUI.draw_paper_plane(self, Vector2(size.x * 0.78, 98 * k), 30.0 * k, UIKit.INK_DARK)
		for p in [Vector2(size.x * 0.82, 140 * k), Vector2(size.x * 0.66, 30 * k)]:
			_sparkle(p, 7.0 * k, ink)
		# Postage stamp in the top-right corner.
		_stamp(Vector2(size.x - 150 * k, 26 * k), Vector2(120, 96) * k)
		# Doodles in the empty card slot: houses, trees and a dashed path.
		if doodle_rect.size.x > 0.0:
			var d := doodle_rect
			_house(d.position + Vector2(d.size.x * 0.62, d.size.y * 0.3), 16.0 * k, ink)
			_house(d.position + Vector2(d.size.x * 0.8, d.size.y * 0.27), 12.0 * k, ink)
			for t in [Vector2(0.22, 0.62), Vector2(0.55, 0.85), Vector2(0.85, 0.62)]:
				_tree(d.position + d.size * t, 13.0 * k, ink)
			var path := MenuUI.bezier(d.position + d.size * Vector2(0.15, 0.35), d.position + d.size * Vector2(0.0, 0.8),
				d.position + d.size * Vector2(0.6, 0.55), d.position + d.size * Vector2(0.75, 0.95))
			MenuUI.draw_dashes(self, path, ink, 2.0 * k, 7.0)

	func _cloud(c: Vector2, s: float, col: Color) -> void:
		draw_arc(c + Vector2(-s, 0), s * 0.7, PI, TAU, 10, col, 2.0 * k, true)
		draw_arc(c + Vector2(0, -s * 0.35), s, PI * 1.05, TAU * 0.98, 12, col, 2.0 * k, true)
		draw_arc(c + Vector2(s * 1.05, 0), s * 0.65, PI, TAU, 10, col, 2.0 * k, true)
		draw_line(c + Vector2(-s * 1.7, 0), c + Vector2(s * 1.7, 0), col, 2.0 * k, true)

	func _house(c: Vector2, s: float, col: Color) -> void:
		var w := 2.0 * k
		draw_polyline(PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s, -s), c + Vector2(0, -s * 1.8), c + Vector2(s, -s), c + Vector2(s, 0), c + Vector2(-s, 0)]), col, w, true)
		draw_rect(Rect2(c + Vector2(-s * 0.25, -s * 0.6), Vector2(s * 0.5, s * 0.6)), col, false, w)
		draw_rect(Rect2(c + Vector2(s * 0.45, -s * 0.8), Vector2(s * 0.3, s * 0.3)), col, false, w * 0.8)

	func _tree(c: Vector2, s: float, col: Color) -> void:
		var w := 2.0 * k
		draw_polyline(PackedVector2Array([c + Vector2(0, -s * 1.6), c + Vector2(-s * 0.7, -s * 0.3), c + Vector2(s * 0.7, -s * 0.3), c + Vector2(0, -s * 1.6)]), col, w, true)
		draw_line(c + Vector2(0, -s * 0.3), c, col, w, true)

	func _sparkle(c: Vector2, s: float, col: Color) -> void:
		draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, 1.8 * k, true)
		draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, 1.8 * k, true)

	func _stamp(at: Vector2, sz: Vector2) -> void:
		draw_set_transform(at + sz * 0.5, deg_to_rad(4.0))
		var r := Rect2(-sz * 0.5, sz)
		draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0.2, 0.1, 0.02, 0.2))
		draw_rect(r, Color("#fffdf6"))
		var perf := 8.0 * k
		var x := r.position.x
		while x <= r.end.x:
			draw_circle(Vector2(x, r.position.y), 2.6 * k, MenuUI.PAPER)
			draw_circle(Vector2(x, r.end.y), 2.6 * k, MenuUI.PAPER)
			x += perf
		var y := r.position.y
		while y <= r.end.y:
			draw_circle(Vector2(r.position.x, y), 2.6 * k, MenuUI.PAPER)
			draw_circle(Vector2(r.end.x, y), 2.6 * k, MenuUI.PAPER)
			y += perf
		var inner := r.grow(-9.0 * k)
		if _stamp_tex:
			draw_texture_rect(_stamp_tex, inner, false)
		else:
			draw_rect(inner, Color("#a9c9db"))
		# Postmark with a little plane, over the stamp's corner.
		var pm := Vector2(r.end.x - 4 * k, r.end.y - 6 * k)
		draw_arc(pm, 30 * k, 0, TAU, 28, Color(UIKit.INK_DARK, 0.55), 2.0 * k, true)
		draw_arc(pm, 22 * k, 0, TAU, 24, Color(UIKit.INK_DARK, 0.45), 1.5 * k, true)
		MenuUI.draw_paper_plane(self, pm, 11.0 * k, Color(UIKit.INK_DARK, 0.6), -0.2)
		for i in 3:
			var wy := pm.y - 12 * k + i * 12 * k
			draw_line(Vector2(pm.x - 70 * k, wy), Vector2(pm.x - 34 * k, wy), Color(UIKit.INK_DARK, 0.45), 1.5 * k, true)
		draw_set_transform(Vector2.ZERO)


# --- A photo card for one flight ---------------------------------------------------------------

class PhotoCard extends Button:
	var index := 0
	var thumb: Texture2D
	var title := ""
	var tilt := 0.0
	var k := 1.0
	var unlocked := true
	var selected := false
	var best := -1
	var ribbons := 0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var lift := 1.0 if (is_hovered() or has_focus()) and unlocked else 0.0
		var off := Vector2(0, -3.0 * k) * lift
		# Shadow and card.
		draw_rect(Rect2(r.position + Vector2(4, 6) * k, r.size), Color(0.2, 0.1, 0.02, 0.22 + 0.08 * lift))
		var card := Rect2(r.position + off, r.size)
		draw_rect(card, Color("#fffdf7"))
		draw_rect(card, Color(0.55, 0.48, 0.38, 0.35), false, 1.0)
		# Photo (a snapshot of the flight's key moment).
		var pad := 8.0 * k
		var pw := card.size.x - pad * 2.0
		var ph := minf(pw / 1.5, card.size.y * 0.56)
		var photo := Rect2(card.position + Vector2(pad, pad), Vector2(pw, ph))
		var dim := Color.WHITE if unlocked else Color(0.55, 0.55, 0.55)
		if thumb:
			draw_texture_rect(thumb, photo, false, dim)
		else:
			draw_rect(photo, Color("#a9c9db") * dim)
		draw_rect(photo, Color(0, 0, 0, 0.12), false, 1.0)
		# Pink tape label: FLIGHT N.
		var font := UIKit.ui_font()
		var fs := int(16 * k)
		var label := "FLIGHT %d" % (index + 1)
		var lw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var tape := Rect2(Vector2(-6 * k, -fs * 0.95), Vector2(lw + 20 * k, fs * 1.55))
		draw_set_transform(photo.position + Vector2(10 * k, photo.size.y + 2 * k), deg_to_rad(-5.0))
		draw_colored_polygon(MenuUI.torn_rect(tape, 1.5, index + 5, 10.0), Color(MenuUI.TAPE, 0.95))
		draw_string(font, Vector2(4 * k, fs * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#8a1f3a"))
		draw_set_transform(Vector2.ZERO)
		# Name (up to two lines), best score and ribbons.
		var df := UIKit.display_font()
		var bs := int(15 * k)
		var by := card.end.y - pad * 1.1
		var name_top := photo.end.y + fs * 0.75
		var avail := by - bs * 1.15 - name_top
		var ns := int(24 * k)
		var lines := _wrap(title, df, ns, card.size.x - pad * 2.5)
		while ns > 11 and lines.size() * ns * 1.0 > avail:
			ns -= 1
			lines = _wrap(title, df, ns, card.size.x - pad * 2.5)
		for i in lines.size():
			draw_string(df, Vector2(card.position.x + pad * 1.3, name_top + ns * 0.88 + i * ns * 0.98), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, ns, UIKit.INK_DARK)
		var best_text := ("Best %d" % best) if best >= 0 else ("Not flown yet" if unlocked else "Locked")
		draw_string(UIKit.ui_font(), Vector2(card.position.x + pad * 1.3, by), best_text, HORIZONTAL_ALIGNMENT_LEFT, -1, bs, UIKit.INK_DARK)
		var sr := 8.0 * k
		for i in 3:
			var c := Vector2(card.end.x - pad - sr - i * sr * 2.3, by - sr * 0.7)
			var lit := (2 - i) < ribbons
			UIKit.draw_star(self, c, sr, UIKit.GOLD if lit else Color(1, 1, 1, 0.6), UIKit.GOLD_DEEP if lit else Color(0.5, 0.45, 0.4, 0.7))
		# The picked card: a thick yellow frame and little marks.
		if selected:
			draw_rect(card.grow(3.0 * k), MenuUI.HIGHLIGHT, false, 5.0 * k)
			var tr := card.position + Vector2(card.size.x + 8 * k, -6 * k)
			for a in [-0.9, -0.4, 0.1]:
				draw_line(tr + Vector2(cos(a), sin(a)) * 8 * k, tr + Vector2(cos(a), sin(a)) * 20 * k, MenuUI.HIGHLIGHT.darkened(0.1), 3.0 * k, true)
		elif has_focus():
			draw_rect(card.grow(2.0 * k), Color(MenuUI.HIGHLIGHT, 0.6), false, 3.0 * k)

	static func _wrap(text: String, font: Font, fs: int, width: float) -> Array:
		var words := text.split(" ")
		var lines := []
		var cur := ""
		for w in words:
			var test := w if cur == "" else cur + " " + w
			if font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width and cur != "":
				lines.append(cur)
				cur = w
			else:
				cur = test
		if cur != "":
			lines.append(cur)
		if lines.size() > 2:
			lines = [lines[0], " ".join(lines.slice(1))]
		return lines


# --- Paper buttons: Play and the chips -----------------------------------------------------------

class PaperChip extends Button:
	var text_label := ""
	var kind := "play"
	var k := 1.0

	func _init() -> void:
		focus_mode = Control.FOCUS_ALL
		flat = true
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		button_down.connect(queue_redraw)
		button_up.connect(queue_redraw)

	func _draw() -> void:
		var play := kind == "play"
		var r := Rect2(Vector2.ZERO, size)
		var hot := is_hovered() or has_focus()
		var off := Vector2(0, 2.0 * k) if button_pressed else (Vector2(0, -2.0 * k) if hot else Vector2.ZERO)
		var body := Rect2(r.position + off, r.size)
		var seed_value := 21 if play else text_label.length() * 7
		draw_colored_polygon(MenuUI.torn_rect(Rect2(body.position + Vector2(4, 7) * k, body.size), 3.0 * k, seed_value + 1, 16.0), Color(0.2, 0.1, 0.02, 0.3))
		var col := MenuUI.HIGHLIGHT if play else MenuUI.PAPER
		if hot:
			col = col.lightened(0.08)
		var outline := MenuUI.torn_rect(body, 3.0 * k, seed_value, 16.0)
		draw_colored_polygon(outline, col)
		if has_focus():
			var ring := MenuUI.torn_rect(body.grow(3 * k), 2.0 * k, seed_value, 16.0)
			ring.append(ring[0])
			draw_polyline(ring, UIKit.INK_DARK if play else UIKit.INK, 2.5 * k, true)
		var df := UIKit.display_font()
		if play:
			var fs := int(body.size.y * 0.62)
			var tw := df.get_string_size(text_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var tx := body.position.x + (body.size.x - tw) * 0.5 - 16 * k
			draw_string(df, Vector2(tx, body.position.y + body.size.y * 0.7), text_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DARK)
			MenuUI.draw_paper_plane(self, Vector2(tx + tw + 30 * k, body.position.y + body.size.y * 0.32), 18.0 * k, UIKit.INK_DARK)
			MenuUI.draw_dashes(self, MenuUI.bezier(Vector2(tx - 30 * k, body.position.y + body.size.y * 0.78), Vector2(tx - 10 * k, body.end.y),
				Vector2(tx + tw * 0.4, body.end.y - 4 * k), Vector2(tx + tw * 0.9, body.end.y - 10 * k), 12), UIKit.INK_DARK, 2.2 * k, 6.0)
			# Two leaves tucked behind the ends.
			for side in [-1.0, 1.0]:
				_leaf(Vector2(body.get_center().x + side * body.size.x * 0.52, body.position.y + body.size.y * 0.15), 16.0 * k, side * 0.6)
		else:
			var fs := int(body.size.y * 0.42)
			var icon_c := Vector2(body.position.x + body.size.y * 0.55, body.get_center().y)
			_icon(icon_c, body.size.y * 0.28)
			draw_string(df, Vector2(icon_c.x + body.size.y * 0.5, body.position.y + body.size.y * 0.64), text_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DARK)

	func _leaf(c: Vector2, s: float, angle: float) -> void:
		var pts := PackedVector2Array()
		for i in 13:
			var t := float(i) / 12.0 * TAU
			pts.append(c + Vector2(cos(t) * s, sin(t) * s * 0.45).rotated(angle))
		draw_colored_polygon(pts, Color("#5f9a45"))
		draw_line(c - Vector2(s, 0).rotated(angle), c + Vector2(s, 0).rotated(angle), Color("#3f7032"), 1.5 * k, true)

	func _icon(c: Vector2, s: float) -> void:
		var col := UIKit.INK_DARK
		var w := 2.2 * k
		match kind:
			"hanger":
				draw_arc(c + Vector2(0, -s * 0.85), s * 0.28, PI, TAU * 1.12, 10, col, w, true)
				draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.45), c + Vector2(-s * 1.1, s * 0.55), c + Vector2(s * 1.1, s * 0.55), c + Vector2(0, -s * 0.45)]), col, w, true)
			"gear":
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(c + Vector2(cos(a), sin(a)) * s * 0.7, c + Vector2(cos(a), sin(a)) * s * 1.05, col, w * 1.6, true)
				draw_arc(c, s * 0.72, 0, TAU, 20, col, w, true)
				draw_arc(c, s * 0.3, 0, TAU, 14, col, w, true)
			"book":
				draw_polyline(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(-s * 1.1, -s * 0.8), c + Vector2(-s * 1.1, s * 0.7), c + Vector2(0, s * 0.85),
					c + Vector2(s * 1.1, s * 0.7), c + Vector2(s * 1.1, -s * 0.8), c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.85)]), col, w, true)


# --- Controls hint ------------------------------------------------------------------------------

class KeyHint extends Control:
	var k := 1.0

	func _items() -> Array:
		return [["Drag", "steer"], ["Gust", "lift"]] if Settings.touch_ui else [["A", "D", "Turn"], ["W", "S", "Climb / Dive"], ["SPACE", "Gust"]]

	## Width needed for all the key caps and labels at height h.
	func content_width(h: float) -> float:
		var font := UIKit.ui_font()
		var fs := int(h * 0.34)
		var x := 14.0 * k
		for it in _items():
			for j in it.size() - 1:
				x += maxf(font.get_string_size(it[j], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 12 * k, h * 0.5) + 5 * k
			x += font.get_string_size(it[it.size() - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18 * k
		return x + 4 * k

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_colored_polygon(MenuUI.torn_rect(Rect2(r.position + Vector2(3, 5) * k, r.size), 2.0 * k, 41, 16.0), Color(0.2, 0.1, 0.02, 0.25))
		draw_colored_polygon(MenuUI.torn_rect(r, 2.0 * k, 40, 16.0), Color(MenuUI.PAPER, 0.95))
		var font := UIKit.ui_font()
		var fs := int(size.y * 0.34)
		var x := 14.0 * k
		var cy := size.y * 0.5
		for it in _items():
			for j in it.size() - 1:
				var key: String = it[j]
				var key_w := font.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				var kw := maxf(key_w + 12 * k, size.y * 0.5)
				var kr := Rect2(x, cy - size.y * 0.27, kw, size.y * 0.54)
				draw_rect(kr, Color.WHITE)
				draw_rect(kr, UIKit.INK_DARK, false, 1.5 * k)
				draw_string(font, Vector2(kr.position.x + (kw - key_w) * 0.5, cy + fs * 0.36), key, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DARK)
				x += kw + 5 * k
			var lab: String = it[it.size() - 1]
			draw_string(font, Vector2(x + 2 * k, cy + fs * 0.36), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UIKit.INK_DARK)
			x += font.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 18 * k
