#version 120
#extension GL_EXT_gpu_shader4 : enable

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
uniform sampler2D normals;
varying vec3 tangent;
varying vec4 tangent_other;
varying vec3 viewVector;
varying float dist;
#include "/lib/res_params.glsl"

#define CLOUDS_SHADOWS
#define VL_CLOUDS_SHADOWS // Casts shadows from clouds on VL (slow)
#define SCREENSPACE_REFLECTIONS	//can be really expensive at high resolutions/render quality, especially on ice
#define SSR_STEPS 30 //[10 15 20 25 30 35 40 50 100 200 400]
#define SUN_MICROFACET_SPECULAR // If enabled will use realistic rough microfacet model, else will just reflect the sun. No performance impact.
#define USE_QUARTER_RES_DEPTH // Uses a quarter resolution depth buffer to raymarch screen space reflections, improves performance but may introduce artifacts
#define saturate(x) clamp(x,0.0,1.0)
#define Dirt_Amount 0.14  //How much dirt there is in water [0.0 0.04 0.08 0.12 0.16 0.2 0.24 0.28 0.32 0.36 0.4 0.44 0.48 0.52 0.56 0.6 0.64 0.68 0.72 0.76 0.8 0.84 0.88 0.92 0.96 1.0 1.04 1.08 1.12 1.16 1.2 1.24 1.28 1.32 1.36 1.4 1.44 1.48 1.52 1.56 1.6 1.64 1.68 1.72 1.76 1.8 1.84 1.88 1.92 1.96 2.0 ]

#define Dirt_Scatter_R 0.6  //How much dirt diffuses red [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define Dirt_Scatter_G 0.6  //How much dirt diffuses green [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define Dirt_Scatter_B 0.6  //How much dirt diffuses blue [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]

#define Dirt_Absorb_R 1.65  //How much dirt absorbs red [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.02 1.04 1.06 1.08 1.1 1.12 1.14 1.16 1.18 1.2 1.22 1.24 1.26 1.28 1.3 1.32 1.34 1.36 1.38 1.4 1.42 1.44 1.46 1.48 1.5 1.52 1.54 1.56 1.58 1.6 1.62 1.64 1.66 1.68 1.7 1.72 1.74 1.76 1.78 1.8 1.82 1.84 1.86 1.88 1.9 1.92 1.94 1.96 1.98 2.0 ]
#define Dirt_Absorb_G 1.85  //How much dirt absorbs green [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.02 1.04 1.06 1.08 1.1 1.12 1.14 1.16 1.18 1.2 1.22 1.24 1.26 1.28 1.3 1.32 1.34 1.36 1.38 1.4 1.42 1.44 1.46 1.48 1.5 1.52 1.54 1.56 1.58 1.6 1.62 1.64 1.66 1.68 1.7 1.72 1.74 1.76 1.78 1.8 1.82 1.84 1.86 1.88 1.9 1.92 1.94 1.96 1.98 2.0 ]
#define Dirt_Absorb_B 2.05  //How much dirt absorbs blue [0.0 0.02 0.04 0.06 0.08 0.1 0.12 0.14 0.16 0.18 0.2 0.22 0.24 0.26 0.28 0.3 0.32 0.34 0.36 0.38 0.4 0.42 0.44 0.46 0.48 0.5 0.52 0.54 0.56 0.58 0.6 0.62 0.64 0.66 0.68 0.7 0.72 0.74 0.76 0.78 0.8 0.82 0.84 0.86 0.88 0.9 0.92 0.94 0.96 0.98 1.0 1.02 1.04 1.06 1.08 1.1 1.12 1.14 1.16 1.18 1.2 1.22 1.24 1.26 1.28 1.3 1.32 1.34 1.36 1.38 1.4 1.42 1.44 1.46 1.48 1.5 1.52 1.54 1.56 1.58 1.6 1.62 1.64 1.66 1.68 1.7 1.72 1.74 1.76 1.78 1.8 1.82 1.84 1.86 1.88 1.9 1.92 1.94 1.96 1.98 2.0 ]

#define Water_Absorb_R 0.2629  //How much water absorbs red [0.0 0.0025 0.005 0.0075 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03 0.0325 0.035 0.0375 0.04 0.0425 0.045 0.0475 0.05 0.0525 0.055 0.0575 0.06 0.0625 0.065 0.0675 0.07 0.0725 0.075 0.0775 0.08 0.0825 0.085 0.0875 0.09 0.0925 0.095 0.0975 0.1 0.1025 0.105 0.1075 0.11 0.1125 0.115 0.1175 0.12 0.1225 0.125 0.1275 0.13 0.1325 0.135 0.1375 0.14 0.1425 0.145 0.1475 0.15 0.1525 0.155 0.1575 0.16 0.1625 0.165 0.1675 0.17 0.1725 0.175 0.1775 0.18 0.1825 0.185 0.1875 0.19 0.1925 0.195 0.1975 0.2 0.2025 0.205 0.2075 0.21 0.2125 0.215 0.2175 0.22 0.2225 0.225 0.2275 0.23 0.2325 0.235 0.2375 0.24 0.2425 0.245 0.2475 0.25 ]
#define Water_Absorb_G 0.0565  //How much water absorbs green [0.0 0.0025 0.005 0.0075 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03 0.0325 0.035 0.0375 0.04 0.0425 0.045 0.0475 0.05 0.0525 0.055 0.0575 0.06 0.0625 0.065 0.0675 0.07 0.0725 0.075 0.0775 0.08 0.0825 0.085 0.0875 0.09 0.0925 0.095 0.0975 0.1 0.1025 0.105 0.1075 0.11 0.1125 0.115 0.1175 0.12 0.1225 0.125 0.1275 0.13 0.1325 0.135 0.1375 0.14 0.1425 0.145 0.1475 0.15 0.1525 0.155 0.1575 0.16 0.1625 0.165 0.1675 0.17 0.1725 0.175 0.1775 0.18 0.1825 0.185 0.1875 0.19 0.1925 0.195 0.1975 0.2 0.2025 0.205 0.2075 0.21 0.2125 0.215 0.2175 0.22 0.2225 0.225 0.2275 0.23 0.2325 0.235 0.2375 0.24 0.2425 0.245 0.2475 0.25 ]
#define Water_Absorb_B 0.01011  //How much water absorbs blue [0.0 0.0025 0.005 0.0075 0.01 0.0125 0.015 0.0175 0.02 0.0225 0.025 0.0275 0.03 0.0325 0.035 0.0375 0.04 0.0425 0.045 0.0475 0.05 0.0525 0.055 0.0575 0.06 0.0625 0.065 0.0675 0.07 0.0725 0.075 0.0775 0.08 0.0825 0.085 0.0875 0.09 0.0925 0.095 0.0975 0.1 0.1025 0.105 0.1075 0.11 0.1125 0.115 0.1175 0.12 0.1225 0.125 0.1275 0.13 0.1325 0.135 0.1375 0.14 0.1425 0.145 0.1475 0.15 0.1525 0.155 0.1575 0.16 0.1625 0.165 0.1675 0.17 0.1725 0.175 0.1775 0.18 0.1825 0.185 0.1875 0.19 0.1925 0.195 0.1975 0.2 0.2025 0.205 0.2075 0.21 0.2125 0.215 0.2175 0.22 0.2225 0.225 0.2275 0.23 0.2325 0.235 0.2375 0.24 0.2425 0.245 0.2475 0.25 ]
#define Texture_MipMap_Bias -1.00 // Uses a another mip level for textures. When reduced will increase texture detail but may induce a lot of shimmering. [-5.00 -4.75 -4.50 -4.25 -4.00 -3.75 -3.50 -3.25 -3.00 -2.75 -2.50 -2.25 -2.00 -1.75 -1.50 -1.25 -1.00 -0.75 -0.50 -0.25 0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]

#define ambient_colortype 0 // Toggle which method you want to change the color of ambient light with. [0 1]
#define ambient_temp 9000 // [1000 2000 3000 4000 5000 6000 7000 8000 9000 10000 15000 50000]

#define AmbientLight_R  0.91 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define AmbientLight_G 0.86 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]
#define AmbientLight_B 1.0 // [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]



#define MIN_LIGHT_AMOUNT 1.0 //[0.0 0.5 1.0 1.5 2.0 3.0 4.0 5.0]
//#define Vanilla_like_water // vanilla water texture along with shader water stuff
uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform vec4 lightCol;
uniform float nightVision;

uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform float lightSign;
uniform float near;
uniform float far;
uniform float moonIntensity;
uniform float sunIntensity;
uniform vec3 sunColor;
uniform vec3 nsunColor;
uniform vec3 upVec;
uniform float sunElevation;
uniform float fogAmount;
uniform vec2 texelSize;
uniform float rainStrength;
uniform float skyIntensityNight;
uniform float skyIntensity;
flat varying vec3 WsunVec;
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform int framemod8;
uniform sampler2D specular;
uniform int frameCounter;
uniform int isEyeInWater;





#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/waterBump.glsl"
#include "lib/clouds.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"

		const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise;
}
vec3 srgbToLinear2(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}
vec3 blackbody2(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp(col,0.0,1.0);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear2(col);
}

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
vec3 nvec3(vec4 pos){
    return pos.xyz/pos.w;
}

vec4 nvec4(vec3 pos){
    return vec4(pos.xyz, 1.0);
}
vec3 rayTrace(vec3 dir,vec3 position,float dither, float fresnel, bool inwater){

    float quality = mix(15,SSR_STEPS,fresnel);
    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality*vec3(RENDER_SCALE,1.0);




	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	
	spos.xy += offsets[framemod8]*texelSize*0.5/RENDER_SCALE;

    for (int i = 0; i <= int(quality); i++) {
			#ifdef USE_QUARTER_RES_DEPTH
			// decode depth buffer
			float sp = sqrt(texelFetch2D(gaux1,ivec2(spos.xy/texelSize/4),0).w/65000.0);
			sp = invLinZ(sp);
          if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)){
						return vec3(spos.xy/RENDER_SCALE,sp);
	        }
        spos += stepv;
			#else
			float sp = texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).r;
          if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)){
						return vec3(spos.xy/RENDER_SCALE,sp);
	        }
        spos += stepv;
			#endif
		//small bias
		minZ = maxZ-0.00004/ld(spos.z);
		if(inwater) minZ = maxZ-0.0004/ld(spos.z);
		maxZ += stepv.z;
    }

    return vec3(1.1);
}


float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    float a = sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
    return sx > 0. ? a : pi - a;
}




	float bayer2(vec2 a){
	a = floor(a);
    return fract(dot(a,vec2(0.5,a.y*0.75)));
}

float cdist(vec2 coord) {
	return max(abs(coord.s-0.5),abs(coord.t-0.5))*2.0;
}

	#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
	#define PW_POINTS 1 //[2 4 6 8 16 32]
	#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) fract(bayer64(.5*(a))*.25+bayer2(a))
vec3 getParallaxDisplacement(vec3 posxz, float iswater,float bumpmult,vec3 viewVec) {
	float waveZ = mix(20.0,0.25,iswater);
	float waveM = mix(0.0,4.0,iswater);

	vec3 parallaxPos = posxz;
	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0 * PW_DEPTH;
	float waterHeight = getWaterHeightmap(posxz.xz, waveM, waveZ, iswater) ;
	
	parallaxPos.xz += waterHeight * vec;

	return parallaxPos;

}
vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
{
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * nbRot * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
}
//Low discrepancy 2D sequence, integration error is as low as sobol but easier to compute : http://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/
vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}
vec4 hash44(vec4 p4)
{
	p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
    p4 += dot(p4, p4.wzxy+33.33);
    return fract((p4.xxyz+p4.yzzw)*p4.zywx);
}
vec3 TangentToWorld(vec3 N, vec3 H)
{
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}
float GGX (vec3 n, vec3 v, vec3 l, float r, float F0) {
  r*=r;r*=r;

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);
  float F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}
float square(float x){
  return x*x;
}

float gSimple(float dp, float roughness){
  float k = roughness + 1;
  k *= k/8.0;
  return dp / (dp * (1.0-k) + k);
}
vec3 GGX2(vec3 n, vec3 v, vec3 l, float r, vec3 F0) {
  float alpha = square(r);

  vec3 h = normalize(l + v);

  float dotLH = clamp(dot(h,l),0.,1.);
  float dotNH = clamp(dot(h,n),0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNV = clamp(dot(n,v),0.,1.);
  float dotVH = clamp(dot(h,v),0.,1.);


  float D = alpha / (3.141592653589793*square(square(dotNH) * (alpha - 1.0) + 1.0));
  float G = gSimple(dotNV, r) * gSimple(dotNL, r);
  vec3 F = F0 + (1. - F0) * exp2((-5.55473*dotVH-6.98316)*dotVH);

  return dotNL * F * (G * D / (4 * dotNV * dotNL + 1e-7));
}

	vec3 applyBump(mat3 tbnMatrix, vec3 bump){	
		float bumpmult = 1.0;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
	}

#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:271 */
void main() {
if (gl_FragCoord.x * texelSize.x < RENDER_SCALE.x  && gl_FragCoord.y * texelSize.y < RENDER_SCALE.y )	{
    
	vec2 specularstuff = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rg;

	// color
	vec2 tempOffset = offsets[framemod8];
	float iswater = normalMat.w;
	
	vec3 fragC = gl_FragCoord.xyz*vec3(texelSize,1.0);
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	
  	vec3 np3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition;

	gl_FragData[0] = texture2D(texture, lmtexcoord.xy)*color;
	float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);
	gl_FragData[0].rgb = clamp((gl_FragData[0].rgb)*pow(avgBlockLum,-0.33)*0.85,0.0,1.0);
	vec3 albedo = toLinear(gl_FragData[0].rgb);

	#ifndef Vanilla_like_water
		if (iswater > 0.4) {
			albedo = vec3(0.42,0.6,0.7);
			gl_FragData[0] = vec4(0.42,0.6,0.7,0.7);
		}
		if (iswater > 0.9) {
			gl_FragData[0] = vec4(0.0);
		}
	#endif


	// normals
	vec3 normal = normalMat.xyz;

	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
						  tangent.y, binormal.y, normal.y,
						  tangent.z, binormal.z, normal.z);
	if (iswater > 0.4){
		float bumpmult = 1.;
		if (iswater > 0.9) bumpmult = 1.;
		float parallaxMult = bumpmult;

		vec3 posxz = p3+cameraPosition;
		posxz.xz-=posxz.y;

		if (iswater < 0.9) posxz.xz *= 3.0;
		
		vec3 bump;
		posxz.xyz = getParallaxDisplacement(posxz,iswater,bumpmult,normalize(tbnMatrix*fragpos));
		bump = normalize(getWaveHeight(posxz.xz,iswater));
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		normal = normalize(bump * tbnMatrix);
	}else {
		vec3 normalTex = texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).rgb;
	
		normalTex.xy = normalTex.xy*2.0-1.0;
		normalTex.z = clamp(sqrt(1.0 - dot(normalTex.xy, normalTex.xy)),0.0,1.0);
		normal = applyBump(tbnMatrix,normalTex);
	}

	/// Direct light
	
	float NdotL = lightSign*dot(normal,sunVec);
	float NdotU = dot(upVec,normal);
	float diffuseSun = clamp(NdotL,0.0f,1.0f);

	vec3 direct = texelFetch2D(gaux1,ivec2(6,37),0).rgb/3.1415;
	vec3 directlightcol = direct;
	float shading = 1.0;
	float cloudShadow = 1.0;
	//compute shadows only if not backface
	if(diffuseSun > 0.001) {
		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
			const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
			float distortThresh = (sqrt(1.0-diffuseSun*diffuseSun)/diffuseSun+0.7)/distortFactor;
			float diffthresh = distortThresh/6000.0*threshMul;

			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

			shading = 0.0;
			float noise = blueNoise();
			float rdMul = 4.0/shadowMapResolution;
			for(int i = 0; i < 9; i++){
				vec2 offsetS = tapLocation(i,9, 1.618,noise,0.0);

				float weight = 1.0+(i+noise)*rdMul/9.0*shadowMapResolution;
				shading += shadow2D(shadow,vec3(projectedShadowPosition + vec3(rdMul*offsetS,-diffthresh*weight))).x/9.0;
				}
			direct *= shading;
		}


		vec3 campos = (p3 + cameraPosition)-319 ;
		#ifdef VOLUMETRIC_CLOUDS
		#ifdef CLOUDS_SHADOWS
			// get cloud position
			vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
			// get the cloud density and apply it
			cloudShadow = getCloudDensity(cloudPos, 1);
			cloudShadow = exp(-cloudShadow*sqrt(cloudDensity)*25);
		
			// make these turn to zero when occluded by the cloud shadow
			direct *= cloudShadow;
		#endif
		#endif
	}
	#if ambient_colortype == 0
		vec3 colortype =  blackbody2(ambient_temp);
	#else
		vec3 colortype = vec3(AmbientLight_R,AmbientLight_G,AmbientLight_B)	;
	#endif

	vec3 ambientLight = texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb * colortype;

	directlightcol *= (iswater > 0.9 ? 0.2: 1.0)*diffuseSun*lmtexcoord.w;


	vec3 diffuseLight = (directlightcol + ambientLight)/5;
	vec3 color = diffuseLight * albedo * 8./150./3.0 ;

	if (iswater > 0.0){
				
		float roughness = iswater > 0.4 ?  0.0 :  specularstuff.r > 0.0 ? pow(1.0-specularstuff.r,2.0) :  0.05*(1.0-gl_FragData[0].a );
		float f0 = iswater > 0.4 || specularstuff.g > 0.9 ? 0.02 : specularstuff.g;
		float F0 = f0;

			// float f0 = iswater > 0.1 ?  0.02 : 0.05*(1.0-gl_FragData[0].a);
			// float roughness = 0.02;
			// float F0 = f0;
			//  roughness = 1.;
		vec3 reflectedVector = reflect(normalize(fragpos), normal);


		float normalDotEye = dot(normal, normalize(fragpos));
		float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 5.0);

		// snells window looking thing
		if(isEyeInWater == 1 && iswater > 0.99) fresnel = clamp(pow(1.66 + normalDotEye,25),0.02,1.0);
			
		fresnel = mix(F0,1.0,fresnel);
			
		// adjust the amount of sunlight based on f0. max f0 should
		// direct =  mix(direct,   (ambientLight*2.5) * albedo * 8./150./3.0 , mix(1.0-roughness, F0, 0.5));

		vec3 wrefl = mat3(gbufferModelViewInverse)*reflectedVector;
		vec3 sky_c = mix(skyCloudsFromTex(wrefl,gaux1).rgb,texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb*0.5,isEyeInWater);
		sky_c.rgb *= lmtexcoord.w*lmtexcoord.w*255*255/240./240./150.*8./3.;

		vec4 reflection = vec4(sky_c.rgb,0.);
		#ifdef SCREENSPACE_REFLECTIONS
			vec3 rtPos = rayTrace(reflectedVector,fragpos.xyz, blueNoise(), fresnel, isEyeInWater == 0);
			if (rtPos.z <1.){
				vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
				previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
				previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
				if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
					reflection.a = 1.0;
					reflection.rgb = texture2D(gaux2,previousPosition.xy).rgb;
				}
			}
		#endif


		if(isEyeInWater ==1 ) sky_c.rgb = color.rgb*lmtexcoord.y;
		
		reflection.rgb = mix(sky_c.rgb, reflection.rgb, reflection.a);

		#ifdef SUN_MICROFACET_SPECULAR
			// vec3 sunSpec = GGX(normal,-normalize(fragpos),  lightSign*sunVec, rainStrength*0.2+roughness+0.05+clamp(-lightSign*0.15,0.0,1.0), f0) * texelFetch2D(gaux1,ivec2(6,37),0).rgb*8./3./150.0/3.1415 * (1.0-rainStrength*0.9);
			vec3 sunSpec = GGX2(normal, -normalize(fragpos),  lightSign*sunVec, roughness+0.005, vec3(f0))   ;
		#else
			vec3 sunSpec = drawSun(dot(lightSign*sunVec,reflectedVector), 0.0,texelFetch2D(gaux1,ivec2(6,37),0).rgb,vec3(0.0))*8./3./150.0*fresnel/3.1415 * (1.0-rainStrength*0.9);
		#endif

		sunSpec *= max(cloudShadow-0.5,0.0);
		// direct = mix(direct, direct*sunSpec, sunSpec);
		vec3 reflected = reflection.rgb*fresnel + shading*sunSpec*directlightcol;
		float alpha0 = gl_FragData[0].a;

		vec4 nice_colors =  mix(gl_FragData[0], vec4(gl_FragData[0].rgb*2 - 0.5, 1.0-gl_FragData[0].a), 1.0-gl_FragData[0].a) ;
	
		nice_colors.rgb *=  (ambientLight +  shading*diffuseSun*directlightcol * max(sunSpec,0.15))/25.;
		gl_FragData[0].a = -gl_FragData[0].a*fresnel+gl_FragData[0].a+fresnel;	// correct alpha channel with fresnel
		gl_FragData[0].rgb = clamp(nice_colors.rgb/gl_FragData[0].a*alpha0*(1.0-fresnel)*0.1+reflected/gl_FragData[0].a*0.1,0.0,65100.0);
			
		// if(gl_FragData[0].a > 0) gl_FragData[0] = max(nice_colors, 0.0);

	}else
	gl_FragData[0].rgb = color*.1;

	gl_FragData[1] = vec4(albedo, iswater);
	// vec4 nice_colors = vec4(gl_FragData[0].rgb, gl_FragData[0].a*gl_FragData[0].a) + (vec4(gl_FragData[0].rgb -0.5 , 1 - gl_FragData[0].a)*(1.0-gl_FragData[0].a) ) ;
	// gl_FragData[0].rgb = color;

			
	


	
  	// float z = texture2D(depthtex0,texcoord).x;
    // vec3 fragpos = toScreenSpace(vec3(texcoord,z));
	// gl_FragData[0].rgb *= vec3(1- clamp( pow( length(fragpos)/far, 1), 0, 1)) ;
}
}