#include "/lib/settings.glsl"

varying vec4 pos;
varying vec4 gcolor;

uniform vec2 texelSize;
uniform vec3 cameraPosition;
uniform sampler2D depthtex1;

uniform mat4 gbufferModelViewInverse;
uniform float far;
uniform int frameCounter;

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

float interleaved_gradientNoise_temporal(){
	#ifdef TAA
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}
/* RENDERTARGETS:2 */
void main() {
	if (gl_FragCoord.x * texelSize.x < 1.0  && gl_FragCoord.y * texelSize.y < 1.0 ) {
   
		vec3 viewPos = pos.xyz;
		vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

		float falloff = exp(-10.0 * (1.0-clamp(1.0 - playerPos.y/5000.0,0.0,1.0)));


		#ifdef DH_OVERDRAW_PREVENTION
			#if OVERDRAW_MAX_DISTANCE == 0
				float maxOverdrawDistance = far;
			#else
				float maxOverdrawDistance = OVERDRAW_MAX_DISTANCE;
			#endif

			if(length(playerPos) < clamp(far-16*4, 16, maxOverdrawDistance) || texture2D(depthtex1, gl_FragCoord.xy*texelSize).x < 1.0){ discard; return; }
		#endif

		vec3 Albedo = toLinear(gcolor.rgb);
		gl_FragData[0] = vec4(Albedo * Emissive_Brightness * 0.1, gcolor.a);
	}
}