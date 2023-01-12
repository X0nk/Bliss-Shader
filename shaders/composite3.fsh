#version 120
//Render sky, volumetric clouds, direct lighting
#extension GL_EXT_gpu_shader4 : enable
#include "lib/settings.glsl"

uniform vec2 texelSize;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex3;
uniform sampler2D colortex13;
uniform sampler2D colortex4;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform vec3 cameraPosition;

uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
flat varying vec2 TAA_Offset;
#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

uniform float far;
uniform float near;

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform float blindness;
uniform float darknessFactor;

#include "lib/sky_gradient.glsl"

void main() {
	/* DRAWBUFFERS:3 */

	vec2 texcoord = gl_FragCoord.xy*texelSize;
 	gl_FragData[0].rgb = texture2D(colortex3, texcoord).rgb;

	///////////////// border fog

#ifdef BorderFog
	vec2 tempOffset = TAA_Offset;
	float z = texture2D(depthtex0,texcoord).x;

	vec3 fragpos = toScreenSpace(vec3(texcoord -vec2(tempOffset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	vec3 worldpos = p3 + (gbufferModelViewInverse[3].xyz+cameraPosition) ;


	vec3 sky = skyFromTex(np3,colortex4) / 150. * 5.;

	float fog = 1.0 - clamp( exp(-pow(length(fragpos / far),10.)*4.0)  ,0.0,1.0);
	

	float lightleakfix = clamp(eyeBrightnessSmooth.y/240.0,0.0,1.0);
	float heightFalloff = clamp( pow(abs(np3.y-1.01),10) ,0,1)	;
	// 	if(z < 1.0 && isEyeInWater == 0)

 	if(z < 1.0 && isEyeInWater == 0) gl_FragData[0].rgb = mix(gl_FragData[0].rgb, sky, fog*lightleakfix*heightFalloff  ) ;


#endif



}