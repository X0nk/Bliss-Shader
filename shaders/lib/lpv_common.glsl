// How far light propagates (block, sky)
const vec2 LpvBlockSkyRange = vec2(15.0, 24.0);

const uint LpvSize = uint(exp2(LPV_SIZE));
const uvec3 LpvSize3 = uvec3(LpvSize);

vec3 GetLpvPosition(const in vec3 playerPos) {
	vec3 cameraOffset = fract(cameraPosition);
	return playerPos + cameraOffset + LpvSize3/2u;
}
