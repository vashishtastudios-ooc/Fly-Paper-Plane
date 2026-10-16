class_name PaintTex
extends RefCounted
## Art style: Painterly. Hand-painted versions of TexGen's textures, at the same sizes and with the
## same base colors (so vertex-color tints still work), built from flat-brush dabs, soft uneven
## joint lines and broad warm/cool washes. Requested through TexGen.get_tex("paint_<kind>").


static func make(kind: String) -> Image:
	match kind:
		"paint_shingle": return _shingle()
		"paint_grass": return _grass()
		"paint_asphalt": return _asphalt()
		"paint_paving": return _paving()
		"paint_cobble": return _cobble()
		"paint_brick": return _brick()
		"paint_stone": return _stone()
		"paint_plaster": return _plaster()
		"paint_wood": return _wood()
		"paint_gravel": return _gravel()
	return null


## A float RGB canvas that wraps at the edges, so everything painted on it tiles seamlessly.
class Canvas:
	var s: int
	var r := PackedFloat32Array()
	var g := PackedFloat32Array()
	var b := PackedFloat32Array()

	func _init(size: int, base: Color) -> void:
		s = size
		r.resize(s * s)
		g.resize(s * s)
		b.resize(s * s)
		r.fill(base.r)
		g.fill(base.g)
		b.fill(base.b)

	## One flat-brush stroke: `hl` half length along the angle, `hh` half height across it. Crisp
	## sides, ragged ends that differ per bristle row, and a little paint variation per row.
	func dab(cx: float, cy: float, hl: float, hh: float, ang: float, col: Color, amt: float, sd: int) -> void:
		var ca := cos(ang)
		var sa := sin(ang)
		var ex := int(absf(ca) * hl + absf(sa) * hh) + 1
		var ey := int(absf(sa) * hl + absf(ca) * hh) + 1
		var icx := int(cx)
		var icy := int(cy)
		# Ragged ends: a few pixels at most, so big strokes keep their shape.
		var rag := minf(hl * 0.25, 2.5)
		var bristle := minf(0.07, 0.25 / hh)
		for dy in range(-ey, ey + 1):
			var yy := posmod(icy + dy, s)
			for dx in range(-ex, ex + 1):
				var v := -dx * sa + dy * ca
				var av := absf(v)
				if av > hh + 0.5:
					continue
				var row := int(v + hh + 0.5)
				var rl := hl - rag * TexGen._hash(sd, row, 9)
				var au := absf(dx * ca + dy * sa)
				if au >= rl:
					continue
				var a := amt * smoothstep(0.0, 0.12, 1.0 - av / (hh + 0.5)) * (1.0 - pow(au / rl, 16.0))
				var br := (TexGen._hash(sd, row + 40, 13) - 0.5) * bristle
				var i := yy * s + posmod(icx + dx, s)
				r[i] = lerpf(r[i], col.r + br, a)
				g[i] = lerpf(g[i], col.g + br, a)
				b[i] = lerpf(b[i], col.b + br, a)

	## A soft, uneven painted joint line (a cool shadow) along X (`horizontal`) or Y at `pos`, from
	## `a0` to `a1`. The pressure varies along it, so parts are strong and parts faint.
	func joint(horizontal: bool, pos: float, a0: int, a1: int, thick: float, dark: float, sd: int) -> void:
		for a in range(a0, a1):
			var t := float(a) / s * TAU
			var wob := sin(t * 2.0 + sd * 1.7) * 0.7 + sin(t * 5.0 + sd) * 0.3
			var press := 0.5 + 0.5 * (sin(t * 3.0 + sd * 2.9) * 0.5 + 0.5)
			var th := thick * (0.8 + 0.4 * (sin(t * 4.0 + sd * 2.3) * 0.5 + 0.5))
			for o in range(-2, int(th) + 4):
				var fd := float(o) - wob
				var k := smoothstep(-0.8, 0.0, fd) * (1.0 - smoothstep(th - 0.5, th + 2.0, fd)) * press * dark
				if k <= 0.0:
					continue
				var p := posmod(int(pos) + o, s)
				var i := (p * s + posmod(a, s)) if horizontal else (posmod(a, s) * s + p)
				r[i] *= 1.0 - k * 1.05
				g[i] *= 1.0 - k
				b[i] *= 1.0 - k * 0.85

	## Broad warm (+) and cool (-) patches over everything, like a thin wash.
	func wash(amount: float, hue: float, sd: int, freq := 0.012) -> void:
		var nz := TexGen._noise(s, freq, sd, 2)
		for i in s * s:
			var p := nz[i] / 255.0 - 0.5
			var m := 1.0 + p * amount
			r[i] *= m * (1.0 + p * hue)
			g[i] *= m * (1.0 + p * hue * 0.25)
			b[i] *= m * (1.0 - p * hue)

	func image() -> Image:
		var d := PackedByteArray()
		d.resize(s * s * 3)
		for i in s * s:
			TexGen._put(d, i * 3, r[i], g[i], b[i])
		return TexGen._img(s, d)


## A color near `c`, shifted a little lighter or darker and warmer or cooler.
static func _vary(rng: RandomNumberGenerator, c: Color, tone: float, warmth: float) -> Color:
	var t := 1.0 + rng.randf_range(-tone, tone)
	var w := rng.randf_range(-warmth, warmth)
	return Color(c.r * t + w, c.g * t + w * 0.3, c.b * t - w)


static func _shingle() -> Image:
	var s := 128
	var row_h := 16
	var w := 20
	var rng := RandomNumberGenerator.new()
	rng.seed = 5101
	var cv := Canvas.new(s, Color(0.72, 0.72, 0.72))
	for row in s / row_h:
		var off := (w / 2) if row % 2 == 1 else 0
		var y0 := row * row_h
		var x := -off
		var n := 0
		while x < s:
			var tone := 0.78 + (TexGen._hash(n, row, 3) - 0.5) * 0.24
			var c := Color(tone, tone, tone)
			cv.dab(x + w * 0.5, y0 + row_h * 0.5, row_h * 0.5 + 1.0, w * 0.5 + 0.5, PI * 0.5, _vary(rng, c, 0.03, 0.03), 0.95, row * 37 + n)
			# Lighter toward the lower edge, where the tile catches the light.
			cv.dab(x + w * 0.5 + rng.randf_range(-2, 2), y0 + row_h * 0.72, w * 0.36, 2.2, rng.randf_range(-0.15, 0.15), _vary(rng, c * 1.12, 0.03, 0.03), 0.6, row * 41 + n)
			cv.joint(false, x, y0 + 2, y0 + row_h - 1, 0.8, 0.32 * rng.randf_range(0.5, 1.0), row * 7 + n)
			x += w
			n += 1
		cv.joint(true, y0 + row_h - 2, 0, s, 1.6, 0.45, row * 3 + 1)
	cv.wash(0.26, 0.08, 5102)
	return cv.image()


static func _grass() -> Image:
	var s := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 5201
	var cv := Canvas.new(s, Color(0.33, 0.58, 0.2))
	var palette := [Color(0.45, 0.68, 0.22), Color(0.27, 0.49, 0.17), Color(0.54, 0.63, 0.21), Color(0.22, 0.45, 0.16), Color(0.36, 0.6, 0.2)]
	# Broad patches first, then short upward strokes in yellow-greens, olives and gold.
	for n in 40:
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(10, 22), rng.randf_range(5, 10), rng.randf() * PI, _vary(rng, palette[n % 5], 0.06, 0.02), 0.45, 600 + n)
	for n in 520:
		var c: Color = palette[rng.randi() % 5]
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(2.5, 5.5), rng.randf_range(0.7, 1.4), -PI * 0.5 + rng.randf_range(-0.6, 0.6), _vary(rng, c, 0.08, 0.02), rng.randf_range(0.5, 0.9), n)
	cv.wash(0.2, 0.12, 5202, 0.02)
	return cv.image()


static func _asphalt() -> Image:
	var s := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 5301
	var base := Color(0.353, 0.36, 0.374)
	var cv := Canvas.new(s, base)
	for n in 110:
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(10, 28), rng.randf_range(2, 5), rng.randf_range(-0.15, 0.15), _vary(rng, base, 0.1, 0.02), rng.randf_range(0.4, 0.75), n)
	for n in 70:
		var light := rng.randf() < 0.6
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(1.2, 2.4), rng.randf_range(0.8, 1.3), rng.randf() * PI, base * (1.25 if light else 0.82), 0.8, 300 + n)
	cv.wash(0.12, 0.05, 5302)
	return cv.image()


static func _paving() -> Image:
	var s := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 5401
	var cv := Canvas.new(s, Color(0.86, 0.843, 0.81))
	for sy in 2:
		for sx in 2:
			var tone := 0.86 + (TexGen._hash(sx, sy, 2) - 0.5) * 0.1
			var c := Color(tone, tone * 0.98, tone * 0.94)
			for n in 7:
				cv.dab(sx * 64 + rng.randf_range(10, 54), sy * 64 + rng.randf_range(10, 54), rng.randf_range(10, 22), rng.randf_range(4, 8), rng.randf() * PI, _vary(rng, c, 0.05, 0.025), rng.randf_range(0.4, 0.7), sy * 100 + sx * 10 + n)
	for k in 2:
		cv.joint(true, k * 64, 0, s, 1.4, 0.36, 11 + k)
		cv.joint(false, k * 64, 0, s, 1.4, 0.36, 21 + k)
	cv.wash(0.14, 0.06, 5402)
	return cv.image()


static func _cobble() -> Image:
	var s := 256
	var cell := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 5501
	var cv := Canvas.new(s, Color(0.44, 0.43, 0.41))
	for row in s / cell:
		var off := (cell / 2) if row % 2 == 1 else 0
		for cx in s / cell:
			var x := cx * cell + cell * 0.5 - off
			var y := row * cell + cell * 0.5
			var tone := 0.8 + (TexGen._hash(cx, row, 5) - 0.5) * 0.22
			var warm := TexGen._hash(cx, row, 9) * 0.06
			var c := Color(tone + warm, tone + warm * 0.5, tone * 0.95)
			var sd := row * 50 + cx
			cv.dab(x, y, 15.0, 13.0, rng.randf_range(-0.3, 0.3), _vary(rng, c * 0.92, 0.03, 0.02), 0.97, sd)
			cv.dab(x - 3, y - 4, 8, 4, rng.randf_range(-0.5, -0.2), _vary(rng, c * 1.08, 0.03, 0.03), 0.65, sd + 7000)
			cv.dab(x + 2, y + 6, 9, 2.5, rng.randf_range(-0.2, 0.2), Color(c.r * 0.78, c.g * 0.8, c.b * 0.86), 0.55, sd + 9000)
	cv.wash(0.18, 0.07, 5502, 0.008)
	return cv.image()


static func _brick() -> Image:
	var s := 128
	var bh := 16
	var bw := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 5601
	var cv := Canvas.new(s, Color(0.82, 0.79, 0.74))
	for row in s / bh:
		var off := (bw / 2) if row % 2 == 1 else 0
		for cx in s / bw + 1:
			var t := (TexGen._hash(cx, row, 8) - 0.5) * 0.16
			var c := Color(0.72 + t, 0.38 + t * 0.6, 0.3 + t * 0.4)
			var x := cx * bw - off + bw * 0.5 + 1
			var y := row * bh + bh * 0.5 + 1
			var sd := row * 20 + cx
			cv.dab(x, y, bw * 0.5 + 0.8, bh * 0.5 - 1.3, rng.randf_range(-0.03, 0.03), _vary(rng, c, 0.03, 0.02), 0.97, sd)
			cv.dab(x + rng.randf_range(-5, 5), y - 2, rng.randf_range(6, 11), 2.0, rng.randf_range(-0.1, 0.1), _vary(rng, c * 1.1, 0.04, 0.03), 0.55, sd + 500)
		cv.joint(true, row * bh + bh - 1, 0, s, 1.2, 0.18, row + 3)
	cv.wash(0.18, 0.06, 5602)
	return cv.image()


static func _stone() -> Image:
	var s := 128
	var bh := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 5701
	var cv := Canvas.new(s, Color(0.6, 0.58, 0.54))
	for row in s / bh:
		var bw := 48 if row % 2 == 0 else 40
		var off := (row * 17) % bw
		var x := -off
		var n := 0
		while x < s:
			var v := 0.8 + (TexGen._hash(n, row, 6) - 0.5) * 0.14
			var c := Color(v, v * 0.97, v * 0.9)
			var sd := row * 30 + n
			var cx := x + bw * 0.5 + 1
			var cy := row * bh + bh * 0.5 + 1
			cv.dab(cx, cy, bw * 0.5 + 0.8, bh * 0.5 - 1.3, rng.randf_range(-0.04, 0.04), _vary(rng, c, 0.03, 0.02), 0.97, sd)
			cv.dab(cx + rng.randf_range(-6, 6), cy - 5, rng.randf_range(8, 14), 3.5, rng.randf_range(-0.3, 0.3), _vary(rng, c * 1.07, 0.03, 0.03), 0.6, sd + 400)
			cv.dab(cx + rng.randf_range(-6, 6), cy + 7, rng.randf_range(8, 14), 3.0, rng.randf_range(-0.3, 0.3), Color(c.r * 0.84, c.g * 0.86, c.b * 0.92), 0.5, sd + 800)
			x += bw
			n += 1
	cv.wash(0.2, 0.06, 5702)
	return cv.image()


static func _plaster() -> Image:
	var s := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 5801
	var base := Color(0.94, 0.94, 0.94)
	var cv := Canvas.new(s, base)
	for n in 90:
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(8, 20), rng.randf_range(3, 7), rng.randf() * PI, _vary(rng, base, 0.05, 0.03), rng.randf_range(0.35, 0.7), n)
	cv.wash(0.16, 0.07, 5802)
	return cv.image()


static func _wood() -> Image:
	var s := 128
	var plank := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 5901
	var cv := Canvas.new(s, Color(0.72, 0.56, 0.39))
	for p in s / plank:
		var v := 0.78 + (TexGen._hash(p, 0, 12) - 0.5) * 0.12
		var c := Color(v * 0.92, v * 0.72, v * 0.5)
		cv.dab(s * 0.5, p * plank + plank * 0.5, s * 0.6, plank * 0.5 - 1.0, 0.0, c, 1.0, p)
		# Long streaky grain strokes.
		for n in 34:
			cv.dab(rng.randf() * s, p * plank + rng.randf_range(3, plank - 3), rng.randf_range(18, 56), rng.randf_range(0.7, 1.7), rng.randf_range(-0.03, 0.03), _vary(rng, c, 0.1, 0.02), rng.randf_range(0.4, 0.8), p * 100 + n + 10)
		cv.joint(true, p * plank, 0, s, 1.6, 0.45, p + 5)
	cv.wash(0.16, 0.05, 5902)
	return cv.image()


static func _gravel() -> Image:
	var s := 128
	var rng := RandomNumberGenerator.new()
	rng.seed = 6001
	var base := Color(0.78, 0.733, 0.64)
	var cv := Canvas.new(s, base)
	for n in 420:
		var t := rng.randf()
		var c := base * (1.14 if t > 0.7 else (0.8 if t < 0.3 else 1.0))
		cv.dab(rng.randf() * s, rng.randf() * s, rng.randf_range(1.5, 3.2), rng.randf_range(1.0, 2.0), rng.randf() * PI, _vary(rng, c, 0.04, 0.03), rng.randf_range(0.6, 0.95), n)
	cv.wash(0.16, 0.08, 6002)
	return cv.image()
