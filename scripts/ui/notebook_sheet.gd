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
	# Kept straight: thin lines on a tilted page come out as broken streaks on some phones.
	rotation = 0.0
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5
	queue_redraw()


## Drawn like the map page (MenuUI.ScrapPage): a torn scrapbook page with a spiral binding,
## faint rules and a soft shadow.
func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var seed_value := int(size.x) % 17 + 3
	draw_colored_polygon(MenuUI.torn_rect(Rect2(r.position + Vector2(8, 12), r.size), 5.0, seed_value + 4), Color(0.2, 0.1, 0.02, 0.28))
	draw_colored_polygon(MenuUI.torn_rect(r, 5.0, seed_value), UIKit.PAPER)
	var y := 70.0
	while y < size.y - 12.0:
		draw_rect(Rect2(54.0, y, size.x - 64.0, 1.0), Color(UIKit.RULE, 0.35))
		y += line_spacing + 4.0
	# Spiral binding down the left edge.
	if holes:
		var n := int(size.y / 34.0)
		for i in n:
			var cy := 24.0 + i * 34.0
			draw_circle(Vector2(26, cy), 6.0, Color(0.32, 0.27, 0.22, 0.85))
			draw_arc(Vector2(16, cy), 11.0, -1.2, 1.9, 10, Color("#8a8f94"), 3.0, true)
