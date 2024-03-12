#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

#ifdef END_SHADER
	flat varying float Flashing;
#endif

flat varying vec3 WsunVec;
// flat varying vec3 unsigned_WsunVec;
flat varying vec3 averageSkyCol_Clouds;
flat varying vec4 lightCol;

flat varying vec2 TAA_Offset;
flat varying vec3 zMults;
uniform sampler2D colortex4;

// uniform float far;
uniform float near;

uniform mat4 gbufferModelViewInverse;
uniform vec3 sunPosition;
uniform float rainStrength;
uniform float sunElevation;
uniform int frameCounter;
uniform float frameTimeCounter;

uniform int framemod8;
const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);


#include "/lib/util.glsl"
#include "/lib/Shadow_Params.glsl"

void main() {
	gl_Position = ftransform();

	#ifdef END_SHADER
		Flashing = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
	#endif

	zMults = vec3(1.0/(far * near),far+near,far-near);

	lightCol.rgb = texelFetch2D(colortex4,ivec2(6,37),0).rgb;
	lightCol.a = float(sunElevation > 1e-5)*2.0 - 1.0;

	averageSkyCol_Clouds = texelFetch2D(colortex4,ivec2(0,37),0).rgb;

	WsunVec = lightCol.a*normalize(mat3(gbufferModelViewInverse) * sunPosition);
	// unsigned_WsunVec = normalize(mat3(gbufferModelViewInverse) * sunPosition);


	#ifdef TAA
		TAA_Offset = offsets[framemod8];
	#else
		TAA_Offset = vec2(0.0);
	#endif

	#ifdef TAA_UPSCALING
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
}
