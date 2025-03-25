uniform sampler3D dither_tex: repeat_enable;
uniform sampler2D dither_ramp_tex;
uniform float scale : hint_range (2.0, 10.0) = 1.0;
uniform float size_variability : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float stretch_smoothness : hint_range(0.0, 2.0) = 1.0;

vec4 get_dither_3d(vec2 uv, vec2 dx, vec2 dy, float brightness) {
	ivec3 dither_tex_size = textureSize(dither_tex, 0);
	
	float x_res = float(dither_tex_size.x);
	float inv_x_res = 1.0 / x_res;
	
	float z_res = float(dither_tex_size.z); // total dots
	float dots_per_side = sqrt(z_res);
	float inv_z_res = 1.0 / z_res;
	
	// look up brightness from ramp texture for proper dither output
	vec2 lookup = vec2(0.5 * inv_x_res + (1.0 - inv_x_res) * brightness, 0.5);
	float brightness_curve = texture(dither_ramp_tex, lookup).r;
	
	// get frequency based on singular value decomposition
	mat2 matr = mat2(dx, dy);
	vec4 vectorized = vec4(dx, dy);
	float Q = dot(vectorized, vectorized);
	float R = determinant(matr);
	float discriminant_squared = max(0.0, Q * Q - 4.0 * R * R);
	float discriminant = sqrt(discriminant_squared);
	
	// freq is vec2(max_freq, min_freq)
	vec2 freq = sqrt(vec2(Q + discriminant, Q - discriminant) / 2.0);
	
	// spacing variable which correlates with average distance between dots
	float spacing = freq.y;
	
	// scale by specified input scale
	float scale_exp = exp2(scale);
	spacing *= scale_exp;
	
	// keep the spacing the same regardless of pattern
	spacing *= dots_per_side * 0.125;
	
	// when size_variability is 0, control brightness by changing spacing
	// when size_variability is 1, control brightness by changing dot size
	float brightness_spacing_multiplier =
			pow(brightness_curve * 2.0 + 0.001, -(1.0 - size_variability));
	spacing *= brightness_spacing_multiplier;
	
	// divide uv by nearest lower power of two level corresponding to spacing
	float spacing_log = log2(spacing);
	float pattern_scale_level = floor(spacing_log);
	vec2 uv_dither = uv / exp2(pattern_scale_level);
	
	// get the third coordinate for the 3d texture lookup
	// first layer is the one that has 1/4 of the dots
	// last layer is the one with all the dots
	float frac = spacing_log - pattern_scale_level;
	float sub_layer = mix(0.25 * z_res, z_res, 1.0 - frac);
	
	// texels are half a texel off from texture border
	// subtract half a texel and normalize to 0-1 range
	sub_layer = (sub_layer - 0.5) * inv_z_res;
	
	// sample the 3d texture
	float pattern = texture(dither_tex, vec3(uv_dither, sub_layer)).r;
	
	// create sharp dots from radial gradient textures by increasing contrast
	float dot_contrast = contrast * scale_exp * brightness_spacing_multiplier * 0.1;
	
	// contrast is based on the highest frequency to avoid aliasing
	// scale contrast by ratio of smallest frequency and highest frequency
	// adjust compensation with stretch_smoothness factor
	dot_contrast *= pow(freq.y / freq.x, stretch_smoothness);
	
	// lerp towards the base value of the original brightness as the contrast decreases
	// this specific formula is taken from the original implementation
	float base_val = mix(0.5, brightness, clamp(1.05 / (1.0 + dot_contrast), 0.0, 1.0));
	
	// the brighter we want the output, the lower the threshold we need to use
	float threshold = 1.0 - brightness_curve;
	
	// get pattern value relative to threshold, scale by contrast and add base value
	float bw = clamp((pattern - threshold) * dot_contrast + base_val, 0.0, 1.0);
	
	return vec4(bw, fract(uv_dither.x), fract(uv_dither.y), sub_layer);
}

float get_grayscale(vec4 color) {
	return clamp(0.299 * color.r + 0.587 * color.g + 0.114 * color.b, 0.0, 1.0);
}

vec4 get_dither_3d_color(vec2 uv_dither, vec2 dx, vec2 dy, vec4 color) {
	vec4 dither = get_dither_3d(uv_dither, dx, dy, get_grayscale(color));
	color.r = dither.r;
	color.g = dither.r;
	color.b = dither.r;
	
	return color;
}