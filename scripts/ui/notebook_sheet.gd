class_name NotebookSheet
extends MarginContainer
## A sheet of ruled notebook paper with a red margin line and binder holes, slightly rotated.
## Children are laid out inside the writing area (right of the margin line).

@export var tilt_degrees := -1.2
@export var line_spacing := 30.0
@export var holes := true

const MARGIN_X := 62.0


func _ready() -> void:
	add_theme_constant_override("margin_left", int(MARGIN_X + 22))
	add_theme_constant_override("margin_right", 30)
	add_theme_constant_override("margin_top", 26)
	add_theme_constant_override("margin_bottom", 26)
	rotation = deg_to_rad(tilt_degrees)
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	# Soft drop shadow.
	for i in 4:
		var o := 3.0 + i * 3.0
		draw_rect(Rect2(r.position + Vector2(o * 0.6, o), r.size), Color(0.25, 0.15, 0.05, 0.05))
	draw_rect(r, UIKit.PAPER)
	# Ruled lines.
	var y := 46.0
	while y < size.y - 6.0:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(UIKit.RULE, 0.8), 1.5)
		y += line_spacing
	# Red margin line.
	draw_line(Vector2(MARGIN_X, 0), Vector2(MARGIN_X, size.y), Color(UIKit.MARGIN, 0.85), 2.0)
	# Binder holes.
	if holes:
		var n := 3 if size.y > 360 else 2
		for i in n:
			var hy := size.y * (0.18 + 0.64 * float(i) / float(n - 1))
			draw_circle(Vector2(26, hy), 11.0, Color(0.86, 0.8, 0.72))
			draw_circle(Vector2(26, hy + 1.5), 9.5, Color(0.42, 0.36, 0.3, 0.55))
			draw_circle(Vector2(26, hy), 8.0, Color(0.32, 0.28, 0.24, 0.35))
	# Slightly darker edge.
	draw_rect(r, Color(0.6, 0.55, 0.45, 0.35), false, 1.5)
