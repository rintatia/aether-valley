shader_type canvas_item;
// Ganti warna isi bingkai (warna dasar #FADCBD) dengan warna tema, tekstur halus tetap terbawa.
uniform vec4 base_color : source_color = vec4(0.980, 0.863, 0.741, 1.0);
uniform vec4 target_color : source_color = vec4(0.980, 0.863, 0.741, 1.0);

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float d = distance(c.rgb, base_color.rgb);
	float w = 1.0 - smoothstep(0.035, 0.075, d);
	c.rgb = mix(c.rgb, clamp(c.rgb - base_color.rgb + target_color.rgb, 0.0, 1.0), w);
	COLOR = c * COLOR;
}
