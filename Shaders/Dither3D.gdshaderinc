uniform sampler3D dither_tex: repeat_enable;
uniform sampler2D dither_ramp_tex;
uniform float scale : hint_range (2.0, 10.0) = 1.0;
uniform float size_variability : hint_range(0.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;
uniform float stretch_smoothness : hint_range(0.0, 2.0) = 1.0;

vec4 get_dither_3d(vec2 uv_dither, vec4 screen_pos, vec2 dx, vec2 dy, float brightness) {
	ivec3 dither_tex_size = textureSize(dither_tex, 0);
	
	float x_res = float(dither_tex_size.x);
	float inv_x_res = 1.0 / x_res;
	
	float z_res = float(dither_tex_size.z);
	float dots_per_side = log2(z_res);
	float inv_z_res = 1.0 / z_res;
	
	vec2 lookup = vec2(0.5 * inv_x_res + (1.0 - inv_x_res) * brightness, 0.5);
	float brightness_curve = texture(dither_ramp_tex, lookup).r;
	
	mat2 matr = mat2(dx, dy);
	vec4 vectorized = vec4(dx, dy);
	float Q = dot(vectorized, vectorized);
	float R = determinant(matr);
	float discriminant_squared = max(0.0, Q * Q - 4.0 * R * R);
	float discriminant = sqrt(discriminant_squared);
	
	vec2 freq = sqrt(vec2(Q + discriminant, Q - discriminant) / 2.0);
	
	float spacing = freq.y;
	
	float scale_exp = exp2(scale);
	spacing *= scale_exp;
	
	spacing *= dots_per_side * 0.125;
	
	float brightness_spacing_multiplier =
			pow(brightness_curve * 2.0 + 0.001, -(1.0 - size_variability));
	spacing *= brightness_spacing_multiplier;
	
	float spacing_log = log2(spacing);
	int pattern_scale_level = int(floor(spacing_log));
	float f = spacing_log - float(pattern_scale_level);
	
	vec2 uv = uv_dither / exp2(float(pattern_scale_level));
	
	float sub_layer = mix(0.25 * z_res, z_res, 1.0 - f);
	
	sub_layer = (sub_layer - 0.5) * inv_z_res;
	
	float pattern = texture(dither_tex, vec3(uv, sub_layer)).r;
	
	float dot_contrast = contrast * scale_exp * brightness_spacing_multiplier * 0.1;
	
	dot_contrast *= pow(freq.y / freq.x, stretch_smoothness);
	
	float base_val = mix(0.5, brightness, clamp(1.05 / (1.0 + dot_contrast), 0.0, 1.0));
	
	float threshold = 1.0 - brightness_curve;
	
	float bw = clamp((pattern - threshold) * dot_contrast + base_val, 0.0, 1.0);
	
	return vec4(bw, fract(uv.x), fract(uv.y), sub_layer);
}

float get_grayscale(vec4 color) {
	return clamp(0.299 * color.r + 0.587 * color.g + 0.114 * color.b, 0.0, 1.0);
}

vec4 get_dither_3d_color(vec2 uv_dither, vec4 screen_pos, vec2 dx, vec2 dy, vec4 color) {
	vec4 dither = get_dither_3d(uv_dither, screen_pos, dx, dy, get_grayscale(color));
	color.r = dither.r;
	color.g = dither.r;
	color.b = dither.r;
	
	return color;
}