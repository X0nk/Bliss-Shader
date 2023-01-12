#version 120
#extension GL_EXT_gpu_shader4 : enable

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
varying vec3 tangent;
varying vec3 viewVector;
varying float dist;
#define SCREENSPACE_REFLECTIONS	//can be really expensive at high resolutions/render quality, especially on ice
#define SSR_STEPS 30 //[10 15 20 25 30 35 40 50 100 200 400]
#define SUN_MICROFACET_SPECULAR // If enabled will use realistic rough microfacet model, else will just reflect the sun. No performance impact.
#define saturate(x) clamp(x,0.0,1.0)

uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform vec4 lightCol;
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
uniform mat4 gbufferPreviousModelView;
uniform vec3 previousCameraPosition;
uniform int framemod8;
uniform int frameCounter;
uniform int isEyeInWater;
#include "lib/color_transforms.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/waterBump.glsl"
#include "lib/clouds.glsl"
#include "lib/stars.glsl"
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
vec3 rayTrace(vec3 dir,vec3 position,float dither, float fresnel){

    float quality = mix(15,SSR_STEPS,fresnel);
    vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
       (-near -position.z) / dir.z : far*sqrt(3.);
    vec3 direction = normalize(toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality;




	vec3 spos = clipPosition + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	spos.xy+=offsets[framemod8]*texelSize*0.5;
	//raymarch on a quarter res depth buffer for improved cache coherency


    for (int i = 0; i < int(quality+1); i++) {

			float sp=texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).x;

            if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)){
							return vec3(spos.xy,sp);

	        }
        spos += stepv;
		//small bias
		minZ = maxZ-0.00004/ld(spos.z);
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
	float waterHeight = getWaterHeightmap(posxz.xz, waveM, waveZ, iswater) * 0.5;
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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* DRAWBUFFERS:27 */
void main() {

	vec2 tempOffset=offsets[framemod8];
	float iswater = normalMat.w;
	vec3 fragC = gl_FragCoord.xyz*vec3(texelSize,1.0);
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	gl_FragData[0] = texture2D(texture, lmtexcoord.xy)*color;
	vec3 albedo = toLinear(gl_FragData[0].rgb);
	if (iswater > 0.4) {
		albedo = vec3(0.42,0.6,0.7);
		gl_FragData[0] = vec4(0.42,0.6,0.7,0.7);
	}
	if (iswater > 0.9) {
		gl_FragData[0] = vec4(0.0);
	}




		vec3 normal = normalMat.xyz;

		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
													tangent.y, binormal.y, normal.y,
													tangent.z, binormal.z, normal.z);
		if (iswater > 0.4){
			float bumpmult = 1.;
			if (iswater > 0.9)
				bumpmult = 1.;
			float parallaxMult = bumpmult;
			vec3 posxz = p3+cameraPosition;
			posxz.xz-=posxz.y;
			if (iswater < 0.9)
				posxz.xz *= 3.0;
			vec3 bump;


			posxz.xyz = getParallaxDisplacement(posxz,iswater,bumpmult,normalize(tbnMatrix*fragpos));

			bump = normalize(getWaveHeight(posxz.xz,iswater));



			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

			normal = normalize(bump * tbnMatrix);
		}


		vec3 diffuseLight = texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb;
		vec3 color = diffuseLight*albedo*8./150./3.;


		if (iswater > 0.0){
		float f0 = iswater > 0.1?  0.02 : 0.05*(1.0-gl_FragData[0].a);

		float roughness = 0.02;

		float emissive = 0.0;
		float F0 = f0;

		vec3 reflectedVector = reflect(normalize(fragpos), normal);
		float normalDotEye = dot(normal, normalize(fragpos));
		float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 5.0);
		fresnel = mix(F0,1.0,fresnel);
		if (iswater > 0.4){
			fresnel = fresnel*0.87+0.04;	//faking additionnal roughness to the water
			roughness = 0.1;
		}



		vec3 wrefl = mat3(gbufferModelViewInverse)*reflectedVector;
		vec4 sky_c = skyCloudsFromTex(wrefl,gaux1)*(1.0-isEyeInWater);
		sky_c.rgb *= lmtexcoord.w*lmtexcoord.w*255*255/240./240./150.*8./3.;





		vec4 reflection = vec4(sky_c.rgb,0.);
		#ifdef SCREENSPACE_REFLECTIONS
		vec3 rtPos = rayTrace(reflectedVector,fragpos.xyz,blueNoise(), fresnel);
		if (rtPos.z <1.){

		vec4 fragpositionPrev = gbufferProjectionInverse * vec4(rtPos*2.-1.,1.);
		fragpositionPrev /= fragpositionPrev.w;

		vec3 sampleP = fragpositionPrev.xyz;
		fragpositionPrev = gbufferModelViewInverse * fragpositionPrev;



		vec4 previousPosition = fragpositionPrev + vec4(cameraPosition-previousCameraPosition,0.);
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition.xy = previousPosition.xy/previousPosition.w*0.5+0.5;
		reflection.a = 1.0;
		reflection.rgb = texture2D(gaux2,previousPosition.xy).rgb;
		}
		#endif
		reflection.rgb = mix(sky_c.rgb, reflection.rgb, reflection.a);
		vec3 reflected= reflection.rgb*fresnel;


		float alpha0 = gl_FragData[0].a;

		//correct alpha channel with fresnel
		gl_FragData[0].a = -gl_FragData[0].a*fresnel+gl_FragData[0].a+fresnel;
		gl_FragData[0].rgb =clamp(color/gl_FragData[0].a*alpha0*(1.0-fresnel)*0.1+reflected/gl_FragData[0].a*0.1,0.0,65100.0);
		if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.);
		}
		else
		gl_FragData[0].rgb = color*0.1;

		gl_FragData[1] = vec4(albedo,iswater);

}
