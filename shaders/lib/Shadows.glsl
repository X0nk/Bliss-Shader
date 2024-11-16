// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap
){

	float MinimumValue = 0.05;

	// give a tiny boost to the distance mulitplier when shadowmap resolution is below 2048.0
	float ResMultiplier = 1.0 + (shadowDistance/8.0)*(1.0 - min(shadowMapResolution,2048)/2048.0)*0.3;

	float DistanceMultiplier = max(1.0 - max(1.0 - length(WorldPos) / shadowDistance, 0.0), MinimumValue) * ResMultiplier;

	vec3 Bias = FlatNormal * DistanceMultiplier;

	// stop lightleaking by zooming up, centered on blocks
	vec2 scale = vec2(0.5); scale.y *= 0.5;
	vec3 zoomShadow =  scale.y - scale.x * fract(WorldPos + cameraPosition + Bias*scale.y);
	if(SkyLightmap < 0.1) Bias = zoomShadow;

	WorldPos += Bias;
}