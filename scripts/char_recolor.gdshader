shader_type canvas_item;
// Pewarna ulang karakter: tiap bagian (rambut, baju, celana, sepatu, kulit) punya topeng sendiri.
// Warna baru = warna target x (terang piksel / terang rata-rata bagian) -> bayangan & sorot tetap.
// Kalau target = warna asli, piksel dibiarkan apa adanya.
uniform sampler2D maskA : filter_linear;   // r rambut, g baju, b celana
uniform sampler2D maskB : filter_linear;   // r sepatu, g kulit
uniform vec4 c_hair; uniform vec4 c_shirt; uniform vec4 c_pants; uniform vec4 c_boots; uniform vec4 c_skin;
uniform vec4 ref_hair; uniform vec4 ref_shirt; uniform vec4 ref_pants; uniform vec4 ref_boots; uniform vec4 ref_skin;
uniform float mean_hair = 0.5; uniform float mean_shirt = 0.5; uniform float mean_pants = 0.5;
uniform float mean_boots = 0.5; uniform float mean_skin = 0.5;

vec3 recolor(vec3 orig, float lum, vec4 target, vec4 ref, float mean) {
	if (distance(target.rgb, ref.rgb) < 0.004) { return orig; }
	return clamp(target.rgb * (lum / max(mean, 0.05)), 0.0, 1.0);
}

void fragment() {
	vec4 col = texture(TEXTURE, UV);
	vec4 a = texture(maskA, UV);
	vec4 b = texture(maskB, UV);
	float lum = dot(col.rgb, vec3(0.299, 0.587, 0.114));
	vec3 acc = vec3(0.0);
	float w = a.r + a.g + a.b + b.r + b.g;
	acc += a.r * recolor(col.rgb, lum, c_hair, ref_hair, mean_hair);
	acc += a.g * recolor(col.rgb, lum, c_shirt, ref_shirt, mean_shirt);
	acc += a.b * recolor(col.rgb, lum, c_pants, ref_pants, mean_pants);
	acc += b.r * recolor(col.rgb, lum, c_boots, ref_boots, mean_boots);
	acc += b.g * recolor(col.rgb, lum, c_skin, ref_skin, mean_skin);
	vec3 o = w > 0.001 ? mix(col.rgb, acc / w, clamp(w, 0.0, 1.0)) : col.rgb;
	COLOR = vec4(o, col.a);
}
