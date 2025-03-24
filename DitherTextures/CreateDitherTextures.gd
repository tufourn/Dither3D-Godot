# https://github.com/runevision/Dither3D/blob/main/Assets/Dither3D/Editor/Dither3DTextureMaker.cs

@tool
extends EditorScript

static func repeat(t, length):  
	return t - floor(t / length) * length

static func create_dither_texture(recursion):
	var bayer_points = [Vector2(0.0, 0.0), Vector2(0.5, 0.5), Vector2(0.5, 0.0), Vector2(0.0, 0.5)]

	for r in range(recursion - 1):
		var count = bayer_points.size()
		var offset = 0.5 ** (r + 1)
		for i in range(1, 4):
			for j in range(count):
				bayer_points.append(bayer_points[j] + bayer_points[i] * offset)

	var dots_per_side = roundi(2 ** recursion)
	var layers = dots_per_side * dots_per_side
	var size = 16 * dots_per_side

	var texture = ImageTexture3D.new()
	var images : Array[Image]
	images.resize(layers)

	var bucket_count = 256
	var brightness_buckets: Array[int]
	brightness_buckets.resize(bucket_count)

	var inv_res = 1.0 / size
	for z in range(layers):
		var dot_count = z + 1
		var dot_area = 0.5 / dot_count
		var dot_radius = sqrt(dot_area / PI)

		var image = Image.create_empty(size, size, false, Image.FORMAT_L8)

		for y in range(size):
			for x in range(size):
				var point = Vector2((x + 0.5) * inv_res, (y + 0.5) * inv_res)
				var dist: float = INF
				for i in range(dot_count):
					var vec = point - bayer_points[i]
					vec.x = repeat(vec.x + 0.5, 1.0) - 0.5
					vec.y = repeat(vec.y + 0.5, 1.0) - 0.5
					var cur_dist: float = vec.length()
					dist = min(dist, cur_dist)
				dist = dist / (dot_radius * 2.4)
				var val = clamp(1 - dist, 0, 1.0)
				
				image.set_pixel(x, y, Color(val, val, val, 1.0))
				
				var bucket = clamp(int(val * bucket_count), 0, bucket_count - 1)
				brightness_buckets[bucket] += 1

		images[z] = image

	texture.create(Image.FORMAT_L8, size, size, layers, false, images)
	var dither_file_path = "res://DitherTextures/Dither3D_" + str(dots_per_side) + "x" + str(dots_per_side) + ".tres"
	ResourceSaver.save(texture, dither_file_path)

	var brightness_ramp: Array[float]
	brightness_ramp.resize(brightness_buckets.size() + 1)
	var sum = 0.0
	var pixel_count = size * size * layers
	for i in range(brightness_buckets.size()):
		sum += brightness_buckets[brightness_buckets.size() - 1 - i]
		brightness_ramp[i + 1] = sum / float(pixel_count)

	var lookup_ramp: Array[float]
	lookup_ramp.resize(size)
	var lower_index_brightness = 0
	var higher_index = 1
	var higher_index_brightness = brightness_ramp[1]
	for i in range(size):
		var desired_brightness = float(i) / float(size - 1)
		while (higher_index_brightness < desired_brightness):
			higher_index += 1
			higher_index_brightness = brightness_ramp[higher_index]
		var l = inverse_lerp(lower_index_brightness, higher_index_brightness, desired_brightness)
		lookup_ramp[i] = float(higher_index - 1 + l) / float(brightness_ramp.size() - 1)

	var ramp_image = Image.create_empty(lookup_ramp.size(), 1, false, Image.FORMAT_L8)
	for x in range(lookup_ramp.size()):
		ramp_image.set_pixel(x, 0, Color(lookup_ramp[x], lookup_ramp[x], lookup_ramp[x], 1.0))

	var ramp_texture = ImageTexture.create_from_image(ramp_image)
	var ramp_file_path = "res://DitherTextures/Dither3D_" + str(dots_per_side) + "x" + str(dots_per_side) + "_Ramp.tres"
	ResourceSaver.save(ramp_texture, ramp_file_path)

func _run():
	create_dither_texture(0)
	create_dither_texture(1)
	create_dither_texture(2)
	create_dither_texture(3)
