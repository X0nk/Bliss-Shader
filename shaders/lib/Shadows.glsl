// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float transition
){
	transition = 1.0-transition; 
	transition *= transition*transition*transition*transition*transition*transition;
	float zoomLevel = mix(0.0, 0.5, transition);

	if(zoomLevel > 0.001 && isEyeInWater != 1) WorldPos = WorldPos - (	fract(WorldPos+cameraPosition - WorldPos*0.0001)*zoomLevel - zoomLevel*0.5);
}

void applyShadowBias(inout vec3 projectedShadowPosition, in vec3 playerPos, in vec3 geoNormals){

	// Calculate the bias size according to the 1:1 ratio of one shadow texel to one full block
	float biasSize = (shadowDistance / shadowMapResolution*2.0) * 2.0;

	float biasDistanceFactor = length(projectedShadowPosition.xy);

	biasDistanceFactor = 1.0 + biasDistanceFactor * ((16.0*8.0) / shadowDistance) * 0.1;

	projectedShadowPosition += (mat3(shadowModelView) * geoNormals) * biasSize * 0.15 * biasDistanceFactor;
}

float shadowMapBounds(in vec3 playerPos){
	
	// make sure it sets the border to the render distance if the shadowmap is set higher.
	float range = min(shadowDistance,far);
	float fadeLength = 5.0;

	vec2 pos = playerPos.xz/range;
	vec2 shadowBounds = clamp(pos + 1.0,0.0,1.0);
	shadowBounds = min(shadowBounds, clamp(1.0 - pos,0.0,1.0)) * range;

	float final = clamp(min(shadowBounds.x,shadowBounds.y)/fadeLength,0.0,1.0);

	final = final*final;
	final = 1.0-final;
	final = final*final;
	final = 1.0-final;

	// vec2 pos_2 = shadowClipPos.xy/range;
	// vec2 shadowBounds_2 = clamp(pos_2 + 1.0,0.0,1.0);
	// shadowBounds_2 = min(shadowBounds_2, clamp(1.0 - pos_2,0.0,1.0)) * range;
	// final = max(final, min(shadowBounds_2.x,shadowBounds_2.y));
	
	return final;
}