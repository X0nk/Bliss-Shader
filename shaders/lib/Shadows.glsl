// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap
){

	// float DistanceOffset = clamp(0.17 + length(WorldPos) / (shadowMapResolution*0.20), 0.0,1.0) ;
	float DistanceOffset = clamp(0.17 + length(WorldPos) / (shadowMapResolution*0.20), 0.0,1.0) ;
	vec3 Bias = FlatNormal * DistanceOffset; // adjust the bias thingy's strength as it gets farther away.
	
	vec3 finalBias = Bias;

	// stop lightleaking by zooming up, centered on blocks
	vec2 scale = vec2(0.5); scale.y *= 0.5;
	vec3 zoomShadow =  scale.y - scale.x * fract(WorldPos + cameraPosition + Bias*scale.y);
	if(SkyLightmap < 0.1) finalBias = mix(Bias, zoomShadow, clamp(VanillaAO*5,0,1));

	WorldPos += finalBias;
}