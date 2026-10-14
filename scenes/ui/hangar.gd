extends CanvasLayer
## The Hangar: pick the plane's paper, trail and wing sticker. Shows a rotating 3D preview.
## Items unlock with ribbons earned across all flights.

signal closed

const KINDS := [["paper", "Paper"], ["trail", "Trail"], ["sticker", "Sticker"]]

var _sheet: NotebookSheet
var _ribbons_label: Label
var _preview_box: SubViewportContainer
var _viewport: SubViewport
var _preview_plane: MeshInstance3D
var _trail_mesh: ImmediateMesh
var _trail_mat: StandardMaterial3D
var _body: BoxContainer
var _options: VBoxContainer
var _buttons := {}  # kind -> {id: Button}
var _t := 0.0


func _ready() -> void:
	layer = 12
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.02, 0.3)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	_sheet = NotebookSheet.new()
	_sheet.tilt_degrees = -0.8
	root.add_child(_sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_sheet.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title := UIKit.label("Hangar", UIKit.display_font(), 54, UIKit.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	_ribbons_label = UIKit.label("", UIKit.ui_font(), 22, UIKit.INK_DARK)
	head.add_child(_ribbons_label)
	_body = HBoxContainer.new()
	_body.add_theme_constant_override("separation", 18)
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(_body)
	_build_preview()
	_body.add_child(_preview_box)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(scroll)
	_options = VBoxContainer.new()
	_options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_options.add_theme_constant_override("separation", 4)
	scroll.add_child(_options)
	for k in KINDS:
		_options.add_child(UIKit.label(k[1], UIKit.display_font(), 30, UIKit.INK_DARK))
		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 6)
		flow.add_theme_constant_override("v_separation", 6)
		_options.add_child(flow)
		var group := ButtonGroup.new()
		_buttons[k[0]] = {}
		for it in Cosmetics.items(k[0]):
			var b := _chip(it.name, group)
			var kind: String = k[0]
			var id: String = it.id
			b.pressed.connect(func(): _select(kind, id))
			flow.add_child(b)
			_buttons[k[0]][it.id] = b
	var row := HBoxContainer.new()
	v.add_child(row)
	var hint := UIKit.label("Earn ribbons to unlock more. Looks only, the flight stays the same.", UIKit.body_font(), 16, UIKit.PENCIL)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(hint)
	var done := UIKit.paper_button("Done", true, 28)
	done.pressed.connect(func():
		close()
		closed.emit())
	row.add_child(done)
	get_viewport().size_changed.connect(_layout)
	visible = false


func _chip(text: String, group: ButtonGroup) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_group = group
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", UIKit.ui_font())
	b.add_theme_font_size_override("font_size", 19)
	for st in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(16)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 4
		sb.content_margin_bottom = 4
		sb.set_border_width_all(2)
		sb.border_color = Color(UIKit.INK, 0.6)
		sb.bg_color = Color(1, 1, 1, 0.5)
		match st:
			"hover": sb.bg_color = Color(UIKit.INK, 0.12)
			"pressed", "hover_pressed":
				sb.bg_color = UIKit.INK
				sb.border_color = UIKit.INK
			"disabled":
				sb.bg_color = Color(0.85, 0.83, 0.8, 0.4)
				sb.border_color = Color(UIKit.PENCIL, 0.25)
			"focus":
				sb.draw_center = false
				sb.border_color = UIKit.GOLD_DEEP
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_color_override("font_color", UIKit.INK_DARK)
	b.add_theme_color_override("font_pressed_color", UIKit.PAPER)
	b.add_theme_color_override("font_hover_pressed_color", UIKit.PAPER)
	b.add_theme_color_override("font_disabled_color", Color(UIKit.PENCIL, 0.6))
	return b


func _build_preview() -> void:
	_preview_box = SubViewportContainer.new()
	_preview_box.stretch = true
	_preview_box.custom_minimum_size = Vector2(380, 250)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_preview_box.add_child(_viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#f5d9bd")
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	var we := WorldEnvironment.new()
	we.environment = env
	_viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("#ffd3a1")
	sun.light_energy = 1.6
	sun.rotation = Vector3(-0.9, 0.6, 0)
	_viewport.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 34.0
	var cam_pos := Vector3(0, 0.95, 2.4)
	cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.0, 0.15) - cam_pos, Vector3.UP), cam_pos)
	_viewport.add_child(cam)
	_preview_plane = MeshInstance3D.new()
	_preview_plane.mesh = PaperPlaneMesh.get_mesh()
	_viewport.add_child(_preview_plane)
	_trail_mesh = ImmediateMesh.new()
	var trail := MeshInstance3D.new()
	trail.mesh = _trail_mesh
	_trail_mat = StandardMaterial3D.new()
	_trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_trail_mat.vertex_color_use_as_albedo = true
	_trail_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = _trail_mat
	_preview_plane.add_child(trail)


func open() -> void:
	visible = true
	_refresh()
	_layout()
	if not get_tree().process_frame.is_connected(_layout):
		get_tree().process_frame.connect(_layout, CONNECT_ONE_SHOT)


func close() -> void:
	visible = false


func _refresh() -> void:
	var ribbons := Game.total_ribbons()
	_ribbons_label.text = "Ribbons earned: %d" % ribbons
	for kind in _buttons:
		for id in _buttons[kind]:
			var b: Button = _buttons[kind][id]
			var req := Cosmetics.requirement(kind, id)
			var unlocked := req <= ribbons
			b.disabled = not unlocked
			var nm := ""
			for it in Cosmetics.items(kind):
				if it.id == id:
					nm = it.name
			b.text = nm if unlocked else "%s  (%d ribbons)" % [nm, req]
			b.set_pressed_no_signal(Game.cosmetics.get(kind, "") == id)
	Cosmetics.apply(_preview_plane, Game.cosmetics.paper, Game.cosmetics.sticker)
	_trail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if Game.cosmetics.trail == "comet" else BaseMaterial3D.BLEND_MODE_MIX


func _select(kind: String, id: String) -> void:
	Game.set_cosmetic(kind, id)
	_refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_preview_plane.rotation = Vector3(0.12 * sin(_t * 0.9), _t * 0.6, 0.25 * sin(_t * 1.3))
	_draw_trail_preview()


func _draw_trail_preview() -> void:
	_trail_mesh.clear_surfaces()
	var style: String = Game.cosmetics.trail
	var n := 30
	var w := 0.03 * Cosmetics.trail_width(style)
	for tip in [PaperPlaneMesh.TIP_LEFT, PaperPlaneMesh.TIP_RIGHT]:
		_trail_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
		for i in n:
			var t := float(i) / (n - 1)
			var p: Vector3 = tip + Vector3(0.1 * sin((1.0 - t) * 3.0 + _t * 2.0) * (1.0 - t), 0, (1.0 - t) * 1.6)
			var c := Cosmetics.trail_color(style, t, i, _t)
			_trail_mesh.surface_set_color(c)
			_trail_mesh.surface_add_vertex(p + Vector3(0, w * (0.4 + t), 0))
			_trail_mesh.surface_set_color(c)
			_trail_mesh.surface_add_vertex(p - Vector3(0, w * (0.4 + t), 0))
		_trail_mesh.surface_end()


func _layout() -> void:
	var s := Settings.viewport_size()
	var portrait := s.y > s.x
	var want_vertical := portrait
	if (_body is HBoxContainer and want_vertical) or (_body is VBoxContainer and not want_vertical):
		var parent := _body.get_parent()
		var idx := _body.get_index()
		var nb: BoxContainer = VBoxContainer.new() if want_vertical else HBoxContainer.new()
		nb.add_theme_constant_override("separation", 18)
		nb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		for c in _body.get_children():
			_body.remove_child(c)
			nb.add_child(c)
		parent.remove_child(_body)
		_body.queue_free()
		parent.add_child(nb)
		parent.move_child(nb, idx)
		_body = nb
	_preview_box.custom_minimum_size = Vector2(0, 260) if portrait else Vector2(380, 250)
	var w := minf(s.x - 24.0, 1080.0)
	var h := minf(s.y - 24.0, 660.0 if not portrait else 1180.0)
	_sheet.size = Vector2(w, h)
	_sheet.position = (s - _sheet.size) * 0.5
