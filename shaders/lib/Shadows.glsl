// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap
){
	// #ifdef DISTANT_HORIZONS_SHADOWMAP
	// 	float minimumValue = 0.3;
	// #else
		float minimumValue = 0.05;
	// #endif

	float DistanceOffset = max(length(WorldPos) * 0.005, minimumValue);

	vec3 Bias = FlatNormal * DistanceOffset;

	// stop lightleaking by zooming up, centered on blocks
	vec2 scale = vec2(0.5); scale.y *= 0.5;
	vec3 zoomShadow =  scale.y - scale.x * fract(WorldPos + cameraPosition + Bias*scale.y);
	if(SkyLightmap < 0.1) Bias = zoomShadow;

	WorldPos += Bias;
}