// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap,
	float transition
){
	float zoomLevel = 1.0-(transition*transition*transition*transition*0.5+0.5);
	if(SkyLightmap < 0.1 && isEyeInWater != 1) WorldPos = WorldPos - (	fract(WorldPos+cameraPosition - WorldPos*0.0001)*zoomLevel - zoomLevel*0.5);
}

void applyShadowBias(inout vec3 projectedShadowPosition, in vec3 playerPos, in vec3 geoNormals){

	// Calculate the bias size according to the 1:1 ratio of one shadow texel to one full block
	const float biasSize = (shadowDistance / shadowMapResolution*2.0) * 2.0;

	float biasDistanceFactor = length(projectedShadowPosition.xy);

	biasDistanceFactor = 1.0 + biasDistanceFactor * ((16.0*8.0) / shadowDistance) * 0.1;

	projectedShadowPosition += (mat3(shadowModelView) * geoNormals) * biasSize * 0.15 * biasDistanceFactor;
}