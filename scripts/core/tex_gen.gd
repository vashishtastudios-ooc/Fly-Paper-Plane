class_name TexGen
extends RefCounted
## Procedurally generated, cached textures. Most are near-white so vertex colors can tint them.

static var _cache := {}


static func get_tex(kind: String) -> Texture2D:
	if _cache.has(kind):
		return _cache[kind]
	var img: Image
	match kind:
		"asphalt": img = _asphalt()
		"cobble": img = _cobble()
		"paving": img = _paving()
		"grass": img = _grass()
		"gravel": img = _gravel()
		"siding": img = _siding()
		"shingle": img = _shingle()
		"brick": img = _brick()
		"stone": img = _stone()
		"wood": img = _wood()
		"paper": img = _paper()
		"cloud": img = _cloud()
		"soft_dot": img = _soft_dot()
		"leaf": img = _leaf()
		"blanket": img = _blanket()
		"awning": img = _awning()
		"star_glint": img = _star_glint()
		"plaster": img = _plaster()
		"paper_graph": img = _paper_graph()
		"paper_origami": img = _paper_tint(Color("#d9473d"), 131, true)
		"paper_construction": img = _paper_tint(Color("#7fb3e0"), 133, false)
		"paper_news": img = _paper_news()
		"paper_map": img = _paper_map()
		"paper_polka": img = _paper_polka()
		"sticker_star": img = _sticker("star")
		"sticker_heart": img = _sticker("heart")
		"sticker_smile": img = _sticker("smile")
		"sticker_bolt": img = _sticker("bolt")
		"sticker_seven": img = _sticker("seven")
		_:
			img = Image.create(4, 4, false, Image.FORMAT_RGB8)
			img.fill(Color.MAGENTA)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache[kind] = tex
	return tex


static func _noise(size: int, freq: float, seed_v: int, octaves := 3) -> PackedByteArray:
	var n := FastNoiseLite.new()
	n.seed = seed_v
	n.frequency = freq
	n.fractal_octaves = octaves
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var img := n.get_seamless_image(size, size, false, false, 0.1, true)
	img.convert(Image.FORMAT_L8)
	return img.get_data()


static func _hash(x: int, y: int, s: int) -> float:
	var h := (x * 374761393 + y * 668265263 + s * 2147483647) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float(h & 0xffff) / 65535.0


static func _img(size: int, data: PackedByteArray, alpha := false) -> Image:
	return Image.create_from_data(size, size, false, Image.FORMAT_RGBA8 if alpha else Image.FORMAT_RGB8, data)


static func _put(d: PackedByteArray, i: int, r: float, g: float, b: float) -> void:
	d[i] = clampi(int(r * 255.0), 0, 255)
	d[i + 1] = clampi(int(g * 255.0), 0, 255)
	d[i + 2] = clampi(int(b * 255.0), 0, 255)


static func _asphalt() -> Image:
	var s := 128
	var nz := _noise(s, 0.05, 11)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var v := 0.36 + (nz[i] / 255.0 - 0.5) * 0.08
			var speck := _hash(x, y, 3)
			if speck > 0.93:
				v += 0.1
			elif speck < 0.05:
				v -= 0.07
			_put(d, i * 3, v * 0.98, v, v * 1.04)
	return _img(s, d)


static func _cobble() -> Image:
	var s := 256
	var nz := _noise(s, 0.04, 21)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var cell := 32
	for y in s:
		var row := y / cell
		var off := (cell / 2) if row % 2 == 1 else 0
		for x in s:
			var i := y * s + x
			var cx := ((x + off) % s) / cell
			var lx := float((x + off) % cell) / cell - 0.5
			var ly := float(y % cell) / cell - 0.5
			var dist := pow(pow(absf(lx), 3.0) + pow(absf(ly), 3.0), 1.0 / 3.0)
			var tone := 0.8 + (_hash(cx, row, 5) - 0.5) * 0.22
			var n := nz[i] / 255.0
			var v: float
			if dist > 0.43:
				v = 0.42 + n * 0.08
			else:
				var dome := 1.0 - dist * 0.55
				v = tone * dome + (n - 0.5) * 0.1
			var warm := _hash(cx, row, 9) * 0.06
			_put(d, i * 3, v + warm, v + warm * 0.5, v * 0.95)
	return _img(s, d)


static func _paving() -> Image:
	var s := 128
	var nz := _noise(s, 0.06, 31)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var cx := x / 64
			var cy := y / 64
			var edge := (x % 64) < 2 or (y % 64) < 2
			var tone := 0.86 + (_hash(cx, cy, 2) - 0.5) * 0.08
			var v := tone + (nz[i] / 255.0 - 0.5) * 0.06
			if edge:
				v = 0.6
			_put(d, i * 3, v, v * 0.98, v * 0.94)
	return _img(s, d)


static func _grass() -> Image:
	var s := 128
	var nz := _noise(s, 0.035, 41)
	var nz2 := _noise(s, 0.2, 42, 1)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var n := nz[i] / 255.0
			var f := nz2[i] / 255.0
			var blade := _hash(x, y, 7)
			var g := 0.62 + n * 0.25 + (f - 0.5) * 0.1
			if blade > 0.9:
				g += 0.12
			_put(d, i * 3, 0.36 * g + 0.06, 0.62 * g + 0.12, 0.26 * g)
	return _img(s, d)


static func _gravel() -> Image:
	var s := 128
	var nz := _noise(s, 0.08, 51)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var v := 0.78 + (nz[i] / 255.0 - 0.5) * 0.1
			var p := _hash(x / 2, y / 2, 4)
			if p > 0.82:
				v += 0.1
			elif p < 0.15:
				v -= 0.12
			_put(d, i * 3, v, v * 0.94, v * 0.82)
	return _img(s, d)


static func _siding() -> Image:
	# Clapboard: 8 boards per tile, each with a shadow line under the lap.
	var s := 128
	var nz := _noise(s, 0.12, 61, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var board := s / 8
	for y in s:
		var ly := y % board
		var shade := 1.0 - 0.18 * (1.0 - float(ly) / board)
		if ly < 2:
			shade = 0.62
		for x in s:
			var i := y * s + x
			var grain := (nz[i] / 255.0 - 0.5) * 0.05
			var v := shade + grain
			_put(d, i * 3, v, v, v)
	return _img(s, d)


static func _shingle() -> Image:
	var s := 128
	var nz := _noise(s, 0.1, 71, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var row_h := 16
	var w := 20
	for y in s:
		var row := y / row_h
		var off := (w / 2) if row % 2 == 1 else 0
		var ly := y % row_h
		for x in s:
			var i := y * s + x
			var cx := (x + off) / w
			var lx := (x + off) % w
			var tone := 0.78 + (_hash(cx, row, 3) - 0.5) * 0.2
			var v := tone * (0.75 + 0.25 * float(ly) / row_h)
			if lx < 1 or ly > row_h - 2:
				v *= 0.55
			v += (nz[i] / 255.0 - 0.5) * 0.06
			_put(d, i * 3, v, v, v)
	return _img(s, d)


static func _brick() -> Image:
	var s := 128
	var nz := _noise(s, 0.09, 81, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var bh := 16
	var bw := 32
	for y in s:
		var row := y / bh
		var off := (bw / 2) if row % 2 == 1 else 0
		for x in s:
			var i := y * s + x
			var cx := (x + off) / bw
			var mortar := ((x + off) % bw) < 2 or (y % bh) < 2
			var n := nz[i] / 255.0 - 0.5
			if mortar:
				_put(d, i * 3, 0.82 + n * 0.05, 0.79 + n * 0.05, 0.74 + n * 0.05)
			else:
				var t := (_hash(cx, row, 8) - 0.5) * 0.16
				_put(d, i * 3, 0.72 + t + n * 0.06, 0.38 + t * 0.6 + n * 0.05, 0.3 + t * 0.4 + n * 0.04)
	return _img(s, d)


static func _stone() -> Image:
	var s := 128
	var nz := _noise(s, 0.07, 91, 3)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var bh := 32
	for y in s:
		var row := y / bh
		var bw := 48 if row % 2 == 0 else 40
		var off := (row * 17) % bw
		for x in s:
			var i := y * s + x
			var cx := (x + off) / bw
			var joint := ((x + off) % bw) < 2 or (y % bh) < 2
			var n := nz[i] / 255.0 - 0.5
			var v := 0.8 + (_hash(cx, row, 6) - 0.5) * 0.12 + n * 0.1
			if joint:
				v = 0.58
			_put(d, i * 3, v * 1.0, v * 0.97, v * 0.9)
	return _img(s, d)


static func _plaster() -> Image:
	var s := 128
	var nz := _noise(s, 0.05, 95, 3)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var v := 0.94 + (nz[i] / 255.0 - 0.5) * 0.07
			_put(d, i * 3, v, v, v)
	return _img(s, d)


static func _wood() -> Image:
	var s := 128
	var nz := _noise(s, 0.03, 101, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var plank := 32
	for y in s:
		var p := y / plank
		for x in s:
			var i := y * s + x
			var n := nz[i] / 255.0
			var grain := sin((float(y) * 0.9 + n * 14.0) * 1.3) * 0.05
			var tone := 0.78 + (_hash(p, 0, 12) - 0.5) * 0.12
			var v := tone + grain
			if y % plank < 2:
				v *= 0.6
			_put(d, i * 3, v * 0.92, v * 0.72, v * 0.5)
	return _img(s, d)


static func _paper() -> Image:
	# Notebook paper: off-white, blue ruled lines, a red margin and some handwriting.
	var s := 256
	var nz := _noise(s, 0.08, 111, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var paper := Color("#fbf9f2")
	var rule := Color("#a9c8e8")
	var margin := Color("#e27a72")
	for y in s:
		for x in s:
			var i := y * s + x
			var n := (nz[i] / 255.0 - 0.5) * 0.025
			var c := paper
			if y % 22 == 0 or y % 22 == 1:
				c = c.lerp(rule, 0.85)
			if x >= 46 and x <= 48:
				c = c.lerp(margin, 0.85)
			_put(d, i * 3, c.r + n, c.g + n, c.b + n)
	var img := _img(s, d)
	# Handwriting: pencil-blue squiggles sitting on a few ruled lines.
	var ink := Color(0.2, 0.27, 0.5)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for line_i in [2, 3, 5, 6, 8]:
		var base_y: float = line_i * 22 - 5
		var x := 56.0 + rng.randf_range(0, 10)
		var end_x := rng.randf_range(170, 240)
		while x < end_x:
			var word_len := rng.randf_range(14, 34)
			var start := x
			while x < start + word_len:
				var yy: float = base_y - 4.0 * absf(sin(x * 0.55)) - (3.0 if fmod(x, 11.0) < 2.0 else 0.0)
				img.set_pixel(int(x), int(yy), ink)
				img.set_pixel(int(x), int(yy) + 1, ink.lerp(paper, 0.5))
				x += 0.5
			x += rng.randf_range(5, 9)
	return img


static func _cloud() -> Image:
	var s := 128
	var nz := _noise(s, 0.03, 121, 4)
	var d := PackedByteArray()
	d.resize(s * s * 4)
	for y in s:
		for x in s:
			var i := y * s + x
			var dx := (x - s * 0.5) / (s * 0.5)
			var dy := (y - s * 0.55) / (s * 0.38)
			var r := sqrt(dx * dx + dy * dy)
			var a := clampf(1.0 - r, 0.0, 1.0)
			a = smoothstep(0.0, 0.6, a) * (0.55 + nz[i] / 255.0 * 0.7)
			a = clampf(a, 0.0, 1.0)
			var shade := 1.0 - clampf(dy, 0.0, 1.0) * 0.12
			d[i * 4] = int(255 * shade)
			d[i * 4 + 1] = int(250 * shade)
			d[i * 4 + 2] = int(246 * shade)
			d[i * 4 + 3] = int(a * 255)
	return _img(s, d, true)


static func _soft_dot() -> Image:
	var s := 64
	var d := PackedByteArray()
	d.resize(s * s * 4)
	for y in s:
		for x in s:
			var i := y * s + x
			var dx := (x - s * 0.5 + 0.5) / (s * 0.5)
			var dy := (y - s * 0.5 + 0.5) / (s * 0.5)
			var a := clampf(1.0 - sqrt(dx * dx + dy * dy), 0.0, 1.0)
			a = a * a
			d[i * 4] = 255
			d[i * 4 + 1] = 255
			d[i * 4 + 2] = 255
			d[i * 4 + 3] = int(a * 255)
	return _img(s, d, true)


static func _star_glint() -> Image:
	var s := 64
	var d := PackedByteArray()
	d.resize(s * s * 4)
	for y in s:
		for x in s:
			var i := y * s + x
			var dx := absf((x - s * 0.5 + 0.5) / (s * 0.5))
			var dy := absf((y - s * 0.5 + 0.5) / (s * 0.5))
			var core := clampf(1.0 - sqrt(dx * dx + dy * dy) * 2.2, 0.0, 1.0)
			var ray := clampf(1.0 - dx * 9.0, 0.0, 1.0) * clampf(1.0 - dy, 0.0, 1.0) \
				+ clampf(1.0 - dy * 9.0, 0.0, 1.0) * clampf(1.0 - dx, 0.0, 1.0)
			var a := clampf(core + ray * 0.8, 0.0, 1.0)
			d[i * 4] = 255
			d[i * 4 + 1] = 255
			d[i * 4 + 2] = 255
			d[i * 4 + 3] = int(a * 255)
	return _img(s, d, true)


static func _leaf() -> Image:
	var s := 32
	var d := PackedByteArray()
	d.resize(s * s * 4)
	for y in s:
		for x in s:
			var i := y * s + x
			var u := (x - s * 0.5 + 0.5) / (s * 0.5)
			var v := (y - s * 0.5 + 0.5) / (s * 0.5)
			var width := 0.62 * (1.0 - v * v)
			var inside := absf(u) < width
			var vein := absf(u) < 0.06
			d[i * 4] = 255 if not vein else 210
			d[i * 4 + 1] = 255 if not vein else 210
			d[i * 4 + 2] = 255 if not vein else 210
			d[i * 4 + 3] = 255 if inside else 0
	return _img(s, d, true)


static func _blanket() -> Image:
	# Red and cream gingham-like stripes.
	var s := 128
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var red := Color("#c8423b")
	var cream := Color("#f7eedd")
	for y in s:
		for x in s:
			var i := y * s + x
			var sx := (x / 16) % 2 == 0
			var sy := (y / 16) % 2 == 0
			var c := cream
			if sx and sy:
				c = red
			elif sx or sy:
				c = red.lerp(cream, 0.45)
			_put(d, i * 3, c.r, c.g, c.b)
	return _img(s, d)


static func _awning() -> Image:
	var s := 64
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var v := 1.0 if (x / 16) % 2 == 0 else 0.93
			_put(d, i * 3, v, v, v)
	return _img(s, d)


# --- Plane papers (customization) -------------------------------------------------------------

static func _paper_graph() -> Image:
	var s := 256
	var nz := _noise(s, 0.08, 141, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var base := Color("#f7f9f6")
	var minor := Color("#b9d8d2")
	var major := Color("#7fb8ad")
	for y in s:
		for x in s:
			var i := y * s + x
			var c := base
			if x % 16 == 0 or y % 16 == 0:
				c = c.lerp(minor, 0.8)
			if x % 64 == 0 or y % 64 == 0:
				c = c.lerp(major, 0.85)
			var n := (nz[i] / 255.0 - 0.5) * 0.02
			_put(d, i * 3, c.r + n, c.g + n, c.b + n)
	return _img(s, d)


static func _paper_tint(col: Color, seed_v: int, creases: bool) -> Image:
	var s := 256
	var nz := _noise(s, 0.06, seed_v, 3)
	var fib := _noise(s, 0.35, seed_v + 1, 1)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	for y in s:
		for x in s:
			var i := y * s + x
			var n := (nz[i] / 255.0 - 0.5) * 0.06 + (fib[i] / 255.0 - 0.5) * 0.05
			var c := col
			if creases and (absi(x - y) < 2 or absi(x + y - s) < 2):
				c = c.darkened(0.12)
			_put(d, i * 3, c.r + n, c.g + n, c.b + n)
	return _img(s, d)


static func _paper_news() -> Image:
	var s := 256
	var nz := _noise(s, 0.1, 151, 2)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 152
	var ink := PackedByteArray()
	ink.resize(s * s)
	# Headline, then three columns of text lines with a photo box.
	for y in range(12, 34):
		for x in range(14, 242):
			if (y - 12) % 11 < 8 and rng.randf() < 0.85:
				ink[y * s + x] = 1
	for col in 3:
		var x0 := 14 + col * 78
		var y := 44
		while y < 244:
			if col == 1 and y > 60 and y < 120:
				for yy in range(60, 120):
					for xx in range(x0, x0 + 70):
						ink[yy * s + xx] = 2
				y = 124
				continue
			var line_len := 70 if rng.randf() > 0.15 else int(rng.randf_range(20, 60))
			var x := x0
			while x < x0 + line_len:
				var word := int(rng.randf_range(3, 11))
				for k in word:
					if x + k < x0 + 70:
						ink[y * s + x + k] = 1
						ink[(y + 1) * s + x + k] = 1
				x += word + 2
			y += 6
	for y in s:
		for x in s:
			var i := y * s + x
			var n := (nz[i] / 255.0 - 0.5) * 0.04
			var v := 0.9 + n
			if ink[i] == 1:
				v = 0.35
			elif ink[i] == 2:
				v = 0.55 + (nz[i] / 255.0) * 0.3
			_put(d, i * 3, v, v * 0.99, v * 0.95)
	return _img(s, d)


static func _paper_map() -> Image:
	var s := 256
	var nz := _noise(s, 0.03, 161, 4)
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var paper := Color("#ecdcb4")
	var land := Color("#cfd9a0")
	var water := Color("#9cc3d6")
	for y in s:
		for x in s:
			var i := y * s + x
			var n := nz[i] / 255.0
			var c := paper.lerp(land, smoothstep(0.55, 0.62, n))
			var river := absf(y - (128.0 + 40.0 * sin(x * 0.03) + 10.0 * sin(x * 0.11)))
			if river < 5.0:
				c = water
			if x % 64 == 0 or y % 64 == 0:
				c = c.darkened(0.12)
			var stain := (n - 0.5) * 0.06
			_put(d, i * 3, c.r + stain, c.g + stain, c.b + stain)
	var img := _img(s, d)
	# Dashed red route ending in an X.
	var red := Color("#c8423b")
	for k in 60:
		if k % 2 == 0:
			continue
		var t := float(k) / 60.0
		var px := 20.0 + t * 210.0
		var py := 210.0 - t * 160.0 + 25.0 * sin(t * 7.0)
		for o in 3:
			img.set_pixel(clampi(int(px) + o, 0, s - 1), clampi(int(py), 0, s - 1), red)
			img.set_pixel(clampi(int(px) + o, 0, s - 1), clampi(int(py) + 1, 0, s - 1), red)
	for k in range(-6, 7):
		img.set_pixel(230 + k, 50 + k, red)
		img.set_pixel(230 + k, 50 - k, red)
		img.set_pixel(231 + k, 50 + k, red)
		img.set_pixel(231 + k, 50 - k, red)
	return img


static func _paper_polka() -> Image:
	var s := 128
	var d := PackedByteArray()
	d.resize(s * s * 3)
	var base := Color("#f4b6c8")
	var dots := [Vector2(16, 16), Vector2(48, 48), Vector2(80, 16), Vector2(112, 48), Vector2(16, 80), Vector2(48, 112), Vector2(80, 80), Vector2(112, 112)]
	for y in s:
		for x in s:
			var i := y * s + x
			var c := base
			for o: Vector2 in dots:
				var dx := x - o.x
				var dy := y - o.y
				if dx * dx + dy * dy < 49.0:
					c = Color("#fff8fb")
			_put(d, i * 3, c.r, c.g, c.b)
	return _img(s, d)


# --- Stickers ----------------------------------------------------------------------------

static func _fill_poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var s := img.get_width()
	for y in s:
		var fy := y + 0.5
		var xs: Array[float] = []
		for i in pts.size():
			var a := pts[i]
			var b := pts[(i + 1) % pts.size()]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			for x in range(maxi(0, int(xs[k])), mini(s, int(xs[k + 1]) + 1)):
				img.set_pixel(x, y, col)


static func _fill_circle(img: Image, c: Vector2, r: float, col: Color) -> void:
	var s := img.get_width()
	for y in range(maxi(0, int(c.y - r)), mini(s, int(c.y + r) + 1)):
		for x in range(maxi(0, int(c.x - r)), mini(s, int(c.x + r) + 1)):
			if Vector2(x + 0.5, y + 0.5).distance_to(c) <= r:
				img.set_pixel(x, y, col)


static func _star_pts(c: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	return pts


static func _sticker(kind: String) -> Image:
	var s := 64
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Vector2(32, 32)
	var outline := Color("#2a2522")
	var white := Color("#fffdf6")
	match kind:
		"star":
			_fill_poly(img, _star_pts(c, 31), white)
			_fill_poly(img, _star_pts(c, 27), outline)
			_fill_poly(img, _star_pts(c, 24), Color("#f6c445"))
		"heart":
			var pts := PackedVector2Array()
			for i in 64:
				var t := TAU * i / 64.0
				var x := 16.0 * pow(sin(t), 3)
				var y := 13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t)
				pts.append(c + Vector2(x, -y) * 1.6 + Vector2(0, 2))
			var big := PackedVector2Array()
			for p in pts:
				big.append(c + (p - c) * 1.15)
			_fill_poly(img, big, white)
			_fill_poly(img, pts, Color("#e04a5a"))
		"smile":
			_fill_circle(img, c, 31, white)
			_fill_circle(img, c, 28, outline)
			_fill_circle(img, c, 25.5, Color("#f6c445"))
			_fill_circle(img, c + Vector2(-9, -7), 3.5, outline)
			_fill_circle(img, c + Vector2(9, -7), 3.5, outline)
			for i in 24:
				var a := lerpf(0.35, PI - 0.35, i / 23.0)
				_fill_circle(img, c + Vector2(cos(a) * 14.0, sin(a) * 12.0 + 3.0), 2.0, outline)
		"bolt":
			_fill_circle(img, c, 31, white)
			_fill_circle(img, c, 28, Color("#2f6fb0"))
			_fill_poly(img, PackedVector2Array([Vector2(36, 8), Vector2(18, 36), Vector2(30, 36), Vector2(25, 57), Vector2(46, 26), Vector2(33, 26)]), Color("#f6c445"))
		"seven":
			_fill_circle(img, c, 31, Color("#c8423b"))
			_fill_circle(img, c, 27, white)
			_fill_poly(img, PackedVector2Array([Vector2(18, 16), Vector2(46, 16), Vector2(46, 22), Vector2(31, 50), Vector2(23, 50), Vector2(38, 23), Vector2(18, 23)]), Color("#c8423b"))
	return img
