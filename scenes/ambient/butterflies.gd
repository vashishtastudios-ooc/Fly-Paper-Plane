extends Node3D
## A few butterflies fluttering over flower beds.

@export var count := 6
@export var area := 12.0

var _items: Array = []


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(absf(position.z)) + 77
	var cols := ["#f2c14e", "#ffffff", "#e8873a", "#a9c9db", "#e6a3c3"]
	for i in count:
		var m := Mats.get_mat("cloth")
		var c := Color(cols[i % cols.size()])
		var pivot := Node3D.new()
		add_child(pivot)
		var wings: Array = []
		for side in [-1.0, 1.0]:
			var w := MeshBuilder.new()
			# Cloth is double sided, so one winding works for both wings.
			w.poly(m, PackedVector3Array([Vector3(0, 0, -0.03), Vector3(side * 0.09, 0, -0.07), Vector3(side * 0.11, 0, 0.02), Vector3(side * 0.05, 0, 0.07), Vector3(0, 0, 0.03)]), c)
			var mi := w.build_instance("Wing", false)
			pivot.add_child(mi)
			wings.append(mi)
		_items.append({"pivot": pivot, "wings": wings, "seed": rng.randf() * 100.0, "speed": rng.randf_range(0.4, 0.8)})


func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	for it in _items:
		var s: float = it.seed
		var sp: float = it.speed
		var p := Vector3(sin(t * sp + s) * area * 0.5 + sin(t * 1.7 + s * 2.0), 0.6 + 0.5 * sin(t * 1.3 + s) + 0.3 * sin(t * 4.1 + s), cos(t * sp * 0.8 + s) * area * 0.5)
		var p2 := Vector3(sin((t + 0.1) * sp + s) * area * 0.5 + sin((t + 0.1) * 1.7 + s * 2.0), p.y, cos((t + 0.1) * sp * 0.8 + s) * area * 0.5)
		var pivot: Node3D = it.pivot
		pivot.position = p
		var dir := p2 - p
		dir.y = 0.0
		if dir.length() > 0.001:
			pivot.basis = Basis.looking_at(dir.normalized(), Vector3.UP)
		var flap := sin(t * 22.0 + s) * 1.1
		var wings: Array = it.wings
		(wings[0] as Node3D).rotation.z = flap
		(wings[1] as Node3D).rotation.z = -flap
