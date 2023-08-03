// #version 120
varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;

uniform sampler2D noisetex;

uniform sampler2D colortex4;


uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform vec3 cameraPosition;

uniform float frameTimeCounter;

uniform vec2 texelSize;

uniform ivec2 eyeBrightnessSmooth;
uniform float rainStrength;

#include "/lib/settings.glsl"
#include "/lib/diffuse_lighting.glsl"
#include "/lib/sky_gradient.glsl"

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

uniform int framemod8;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:2 */
void main() {

	gl_FragData[0] = texture2D(texture, lmtexcoord.xy)*color;

	vec3 Albedo = toLinear(gl_FragData[0].rgb);

	vec2 tempOffset = offsets[framemod8];
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	vec3 Indirect_lighting = vec3(1.0);
	float lightmap = lmtexcoord.z;
	vec3 nothing = vec3(0.0);

	#ifdef END_SHADER
   		float TorchLM = 10.0 - ( 1.0 / (pow(exp(-0.5*inversesqrt(lightmap)),5.0)+0.1));
   		TorchLM = pow(TorchLM/4,10) + pow(lightmap,1.5)*0.5;
		vec3 TorchLight = (vec3(TORCH_R,TORCH_G,TORCH_B) * TorchLM * 0.75) * TORCH_AMOUNT;

		Indirect_lighting = max(vec3(0.5,0.75,1.0) * 0.1, (MIN_LIGHT_AMOUNT*0.01 + nightVision*0.5) ) + TorchLight;
	#endif

	#ifdef NETHER_SHADER
		vec3 AmbientLightColor = skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb / 10;

		Indirect_lighting = DoAmbientLighting_Nether(AmbientLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmap, nothing, nothing, nothing);
	#endif
		
	gl_FragData[0].rgb = Indirect_lighting * Albedo;
}