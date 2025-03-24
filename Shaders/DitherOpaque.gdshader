shader_type spatial;

render_mode ambient_light_disabled;

uniform sampler2D albedo_texture : source_color;

#include "Dither3D.gdshaderinc"

void vertex() {

}

void fragment() {
	ALBEDO = texture(albedo_texture, UV).rgb;
}

void light() {
	float NoL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0);
	DIFFUSE_LIGHT += LIGHT_COLOR * ATTENUATION * NoL;

	vec2 dx = dFdx(UV);
	vec2 dy = dFdy(UV);
	SPECULAR_LIGHT = get_dither_3d_color(UV, FRAGCOORD, dx, dy, vec4(ALBEDO * DIFFUSE_LIGHT, 1.0)).rgb;

	SPECULAR_LIGHT -= DIFFUSE_LIGHT * ALBEDO;
}
