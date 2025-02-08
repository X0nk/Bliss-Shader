#include "/lib/cube/cubeData.glsl"

void emitCubemap(mat4 directionMatrix, vec2 offset, vec3 lightPosition) {
	vec4[] positions = vec4[3](
		cubeProjection*directionMatrix*vec4(worldPos[0] - lightPosition, 1.0),
		cubeProjection*directionMatrix*vec4(worldPos[1] - lightPosition, 1.0),
		cubeProjection*directionMatrix*vec4(worldPos[2] - lightPosition, 1.0));

	if ((positions[0].x < positions[0].w || (positions[1].x) < positions[1].w || (positions[2].x) < positions[2].w) && (positions[0].x > -positions[0].w || (positions[1].x) > -positions[1].w || (positions[2].x) > -positions[2].w)) {
		for (int i = 0; i < 3; i++) {
			#if defined OVERWORLD_SHADER && defined TRANSLUCENT_COLORED_SHADOWS
				Fcolor = color[i].rgb;
			#endif
			// move vertex to cube face
			positions[i].xy = positions[i].xy*cubeTileRelativeResolution + (cornerOffset + offset) *positions[i].w;
			gl_Position = positions[i];
			Ftexcoord = texcoord[i];
			EmitVertex();
		}
		EndPrimitive();
	}
}