#version 120
//Render sky, volumetric clouds, direct lighting
#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"

const bool colortex5MipmapEnabled = true;
const bool colortex12MipmapEnabled = true;
// const bool colortex4MipmapEnabled = true;

const bool shadowHardwareFiltering = true;
flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 avgAmbient;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
flat varying float tempOffsets;


uniform float eyeAltitude;

/*
const int colortex12Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
const int colortex15Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
*/


flat varying vec3 zMults;
uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
// uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7; // normal
uniform sampler2D colortex6; // Noise
uniform sampler2D colortex8; // specular
// uniform sampler2D colortex9; // specular
uniform sampler2D colortex11; // specular
uniform sampler2D colortex10; // specular
uniform sampler2D colortex12; // specular
uniform sampler2D colortex13; // specular
// uniform sampler2D colortex14; // specular
uniform sampler2D colortex15; // specular
uniform sampler2D colortex16; // specular
uniform sampler2D depthtex1;//depth
uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth
uniform sampler2DShadow shadow;
varying vec4 normalMat;
uniform int heldBlockLightValue;
uniform int frameCounter;
uniform int isEyeInWater;
uniform float far;
uniform float near;
uniform float nightVision;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;
// uniform float viewWidth;
// uniform float viewHeight;
uniform float aspectRatio;
uniform vec2 texelSize;
uniform vec3 cameraPosition;
uniform vec3 sunVec;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

// uniform int worldTime;                    

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)

#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)


vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

vec3 toScreenSpacePrev(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 worldToView(vec3 p3) {
    vec4 pos = vec4(p3, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}


float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}
vec3 ld(vec3 dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
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

vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
#include "lib/res_params.glsl"
#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"
#include "lib/waterBump.glsl"
#include "lib/specular.glsl"

#include "lib/diffuse_lighting.glsl"

float lengthVec (vec3 vec){
	return sqrt(dot(vec,vec));
}
#define fsign(a)  (clamp((a)*1e35,0.,1.)*2.-1.)
float triangularize(float dither)
{
    float center = dither*2.0-1.0;
    dither = center*inversesqrt(abs(center));
    return clamp(dither-fsign(center),0.0,1.0);
}


float interleaved_gradientNoise(){
	// vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	vec2 coord = gl_FragCoord.xy + frameTimeCounter;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
}

vec2 R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return vec2(fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter), fract((1.0-alpha.x) * gl_FragCoord.x + (1.0-alpha.y) * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter));
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * (frameCounter*0.5+0.5)	);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512, 0) ;
}
vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}


vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort){
	float alpha0 = sampleNumber/nb;
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * 84.0 * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
}
vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;
    return p3;
}

vec2 R2_samples(int n){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha * n);
}

vec2 tapLocation(int sampleNumber, float spinAngle,int nb, float nbRot,float r0){
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 3.14) + spinAngle*3.14;

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
}


void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient, vec3 lightSource, float VdotL){
		inColor *= exp(-rayLength * waterCoefs);	//No need to take the integrated value
		int spCount = rayMarchSampleCount;
		vec3 start = toShadowSpaceProjected(rayStart);
		vec3 end = toShadowSpaceProjected(rayEnd);
		vec3 dV = (end-start);
		//limit ray length at 32 blocks for performance and reducing integration error
		//you can't see above this anyway
		float maxZ = min(rayLength,12.0)/(1e-8+rayLength);
		dV *= maxZ;

		rayLength *= maxZ;
		
		float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
		estEndDepth *= maxZ;
		estSunDepth *= maxZ;

		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);

		float phase = phaseg(VdotL,0.7) * 1.5 + 0.1;

		vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
		vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);
		// vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;

		float expFactor = 11.0;
		for (int i=0;i<spCount;i++) {
			float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
			float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
			vec3 spPos = start.xyz + dV*d;

			vec3 progressW = start.xyz+cameraPosition+dVWorld;

			//project into biased shadowmap space
			float distortFactor = calcDistort(spPos.xy);
			vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
			float sh = 1.0;
			if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
				pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
				sh =  shadow2D( shadow, pos).x;
			}

			#ifdef VL_CLOUDS_SHADOWS
				sh *= GetCloudShadow_VLFOG(progressW);
			#endif


			vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs );
			vec3 sunMul = exp(-max(estSunDepth * d,0.0) * waterCoefs);

			vec3 light = (sh * lightSource * phase * sunMul + (ambientMul*ambient) )*scatterCoef;
			// vec3 light = sh * vec3(1);

			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
			absorbance *= exp(-dd * rayLength * waterCoefs);
		}
		inColor += vL;
}

float waterCaustics(vec3 wPos, vec3 lightSource) { // water waves

	vec2 pos = wPos.xz + (lightSource.xz/lightSource.y*wPos.y);
	if(isEyeInWater==1) pos = wPos.xz - (lightSource.xz/lightSource.y*wPos.y); // fix the fucky
	vec2 movement = vec2(-0.035*frameTimeCounter);
	float caustic = 0.0;
	float weightSum = 0.0;
	float radiance =  2.39996;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

	const vec2 wave_size[4] = vec2[](
		vec2(64.),
		vec2(32.,16.),
		vec2(16.,32.),
		vec2(48.)
	);

	for (int i = 0; i < 4; i++){
		pos = rotationMatrix * pos;

		vec2 speed = movement;
		float waveStrength = 1.0;

		if( i == 0) {
			speed *= 0.15;
			waveStrength = 2.0;
		}

		float small_wave = texture2D(noisetex, pos / wave_size[i] + speed ).b * waveStrength;

		caustic +=  max( 1.0-sin( 1.0-pow(	0.5+sin( small_wave*3.0	)*0.5,	25.0)	),	0);

		weightSum -= exp2(caustic*0.1);
	}
	return caustic / weightSum;
}


// float waterCaustics(vec3 wPos, vec3 lightSource) {
// 	vec2 movement = vec2(frameTimeCounter*0.05);
// 	vec2 pos = (wPos + WsunVec/WsunVec.y*max(SEA_LEVEL - wPos.y,0.0)).xz ;
// 	float caustic = 1.0;
// 	float weightSum = 0.0;

// 	float radiance = 2.39996;
// 	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

// 	const vec2 wave_size[3] = vec2[](
// 		vec2(48.,12.),
// 		vec2(12.,48.),
// 		vec2(32.)
// 	);

// 	float WavesLarge = clamp(	pow(1.0-pow(1.0-texture2D(noisetex, pos / 600.0 ).b, 5.0),5.0),0.1,1.0);

// 	for (int i = 0; i < 3; i++){
// 		pos = rotationMatrix * pos ;

// 		float Waves = texture2D(noisetex, pos / (wave_size[i] +  (1-WavesLarge)*0.1) + movement).b;

		
// 		caustic += Waves/3;
// 		// weightSum += exp2(caustic);
// 	}
// 	return exp(1.0-(1.0-pow(1.0-abs((caustic - 1.5)*2.0)*0.5,0.5)) * 30) + 0.5 ;
// }



float rayTraceShadow(vec3 dir,vec3 position,float dither){
    const float quality = 16.;
    vec3 clipPosition = toClipSpace3(position);
	//prevents the ray from going behind the camera
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
      					 (-near -position.z) / dir.z : far*sqrt(3.) ;
    vec3 direction = toClipSpace3(position+dir*rayLength)-clipPosition;  //convert to clip space
    direction.xyz = direction.xyz/max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y);	//fixed step size
    vec3 stepv = direction * 3.0 * clamp(MC_RENDER_QUALITY,1.,2.0)*vec3(RENDER_SCALE,1.0);
	
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0);
	// spos.xy += (TAA_Offset*(texelSize/4))*RENDER_SCALE ;
	spos += stepv*dither ;

	for (int i = 0; i < int(quality); i++) {
		spos += stepv;
		
		float sp = texture2D(depthtex1,spos.xy).x;
	
        if( sp < spos.z) {
			float dist = abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);
			if (dist < 0.015 ) return i / quality;
		}
	}
    return 1.0;
}

vec2 tapLocation_alternate(
	int sampleNumber, 
	float spinAngle,
	int nb, 
	float nbRot,
	float r0
){
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 3.14) ;

    float ssR = alpha + spinAngle*3.14;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
}


void ssAO(inout vec3 lighting,	vec3 fragpos,float mulfov, vec2 noise, vec3 normal, vec2 texcoord, vec3 ambientCoefs, vec2 lightmap){

	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/180.);

	float dist = 1.0 + clamp(fragpos.z*fragpos.z/50.0,0,2); // shrink sample size as distance increases

	float mulfov2 = gbufferProjection[1][1]/(tan70  * dist);
	float maxR2 = fragpos.z*fragpos.z*mulfov2*2.*5/50.0;


	float rd = mulfov2 * 0.1 ;
	//pre-rotate direction
	float n = 0.0;

	float occlusion = 0.0;

	vec2 acc = -(TAA_Offset*(texelSize/2))*RENDER_SCALE ;

	int seed = (frameCounter%40000)*2 + (1+frameCounter);
	float randomDir = fract(R2_samples(seed).y + noise.x ) * 1.61803398874 ;
	vec3 NormalSpecific = viewToWorld(normal);
	for (int j = 0; j < 7 ;j++) {
		
		vec2 sp = tapLocation_alternate(j, 0.0, 7, 20, randomDir);
		// vec2 sp = vogel_disk_7[j];
		float thing = sp.y < 0.0 && clamp(floor(abs(NormalSpecific.y)*2.0),0.0,1.0) < 1.0 ? rd * 10: rd;


		vec2 sampleOffset = sp*thing;
		vec2 sampleOffset2 =  sp*rd ;
		sampleOffset = min(sampleOffset, sampleOffset2);
		// vec2 sampleOffset = sp*rd;

		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio)*RENDER_SCALE);

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE.x && offset.y < viewHeight*RENDER_SCALE.y ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x) * vec3(1.0/RENDER_SCALE, 1.0) );
			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec,vec);

			if (dsquared > 1e-5){
				if (dsquared < maxR2){
					float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
					occlusion += NdotV * clamp(1.0-dsquared/maxR2,0.0,1.0);

					// float NdotV2 = clamp(dot(vec*inversesqrt(dsquared), normalize(RPnormal)),0.,1.);
					// occlusion.y += NdotV2 * clamp(1.0-dsquared/maxR2,0.0,1.0);
				}
				n += 1;
			}
		}
	}

	occlusion *= mix(2.5, 2.0 ,  clamp(floor(abs(NormalSpecific.y)*2.0),0.0,1.0));
	occlusion = max(1.0 - occlusion/n, 0.0);

	lighting = lighting*max(occlusion,pow(lightmap.x,4));
}
vec3 DoContrast(vec3 Color, float strength){

	float Contrast =  log(strength);

	return clamp(mix(vec3(0.5), Color, Contrast) ,0,255);
}


void ssDO(inout vec3 lighting,	vec3 fragpos,float mulfov, vec2 noise, vec3 normal, vec3 RPnormal, vec2 texcoord, vec3 ambientCoefs, vec2 lightmap, float sunlight){
	const int Samples = 7;
	vec3 Radiance = vec3(0);
	float occlusion = 0.0;

	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/180.);

	// float dist = 1.0 + clamp(fragpos.z*fragpos.z/50.0,0,2); // shrink sample size as distance increases

	float mulfov2 = gbufferProjection[1][1]/(tan70   );
	float maxR2 = fragpos.z*fragpos.z*mulfov2*2.*5/50.0;


	float rd = mulfov2 * 0.1 ;


	vec2 acc = -(TAA_Offset*(texelSize/2))*RENDER_SCALE ;

	vec3 NormalSpecific = viewToWorld(normal);

	
	for (int j = 0; j < Samples ;j++) {
		
		vec2 sp = tapLocation_alternate(j, 0.0, 7, 20, blueNoise());
		float thing = sp.y < 0.0 && clamp(floor(abs(NormalSpecific.y)*2.0),0.0,1.0) < 1.0 ? rd * 10: rd;


		vec2 sampleOffset = sp*thing;
		vec2 sampleOffset2 =  sp*rd ;
		sampleOffset = sampleOffset2;

		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio)*RENDER_SCALE);

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth*RENDER_SCALE.x && offset.y < viewHeight*RENDER_SCALE.y ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x) * vec3(1.0/RENDER_SCALE, 1.0) );
			

			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec,vec);

				float NdotV2 = clamp(dot(vec*inversesqrt(dsquared), normalize(RPnormal)),0.,1.);

				if (dsquared < maxR2){
					// float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
					// occlusion += NdotV * clamp(1.0-dsquared/maxR2,0.0,1.0);
					

					vec3 previousPosition = mat3(gbufferModelViewInverse) * t0 + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
					previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
					previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

					if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0){
						Radiance +=  NdotV2*texture2D(colortex5,previousPosition.xy).rgb ;
					}

				}
		}
	}
	
	lighting =  vec3(1) + Radiance/Samples;
}

vec3 RT(vec3 dir, vec3 position, float noise, float stepsizes){
	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases

	float stepSize = stepsizes / dist;
	int maxSteps = STEPS;
	vec3 clipPosition = toClipSpace3(position);
	float rayLength = ((position.z + dir.z * sqrt(3.0)*far) > -sqrt(3.0)*near) ?
	   								(-sqrt(3.0)*near -position.z) / dir.z : sqrt(3.0)*far;
	vec3 end = toClipSpace3(position+dir*rayLength) ;
	vec3 direction = end-clipPosition ;  //convert to clip space

	float len = max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y)/stepSize;
	//get at which length the ray intersects with the edge of the screen
	vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
	
	float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z)*2000.0;

	vec3 stepv = direction/len;

	int iterations = min(int(min(len, mult*len)-2), maxSteps);
	
	//Do one iteration for closest texel (good contact shadows)
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) ;
	spos.xy += TAA_Offset*texelSize*0.5*RENDER_SCALE;
	spos += stepv/(stepSize/2);
	
	float distancered = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases

  	for(int i = 0; i < iterations; i++){
		if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) return vec3(1.1);
		spos += stepv*noise;

		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/ texelSize/4),0).w/65000.0);
		float currZ = linZ(spos.z);
		
		if( sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (dist <= 0.1) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
		}
	}
	return vec3(1.1);
}

vec3 cosineHemisphereSample(vec2 Xi, float roughness){
    float r = sqrt(Xi.x);
    float theta = 2.0 * 3.14159265359 * Xi.y;

    float x = r * cos(theta);
    float y = r * sin(theta);

    return vec3(x, y, sqrt(clamp(1.0 - Xi.x,0.,1.)));
}
vec3 TangentToWorld(vec3 N, vec3 H, float roughness){
    vec3 UpVector = abs(N.z) < 0.999 ? vec3(0.0, 0.0, 1.0) : vec3(1.0, 0.0, 0.0);
    vec3 T = normalize(cross(UpVector, N));
    vec3 B = cross(N, T);

    return vec3((T * H.x) + (B * H.y) + (N * H.z));
}

void rtAO(inout vec3 lighting, vec3 normal, vec2 noise, vec3 fragpos, float lightmap, float inShadow){
	int nrays = 4;
	float occlude = 0.0;

	float indoor = clamp(pow(lightmap,2)*2,0.0,AO_Strength);
	
	for (int i = 0; i < nrays; i++){
		int seed = (frameCounter%40000)*nrays+i;
		vec2 ij = fract(R2_samples(seed) + noise.rg);


		vec3 rayDir = TangentToWorld(  normal, normalize(cosineHemisphereSample(ij,1.0)) ,1.0) ;
		
		#ifdef HQ_SSGI
			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, fragpos,  blueNoise(), 30.); // ssr rt
		#else
			vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, fragpos, blueNoise(), 24.);  // choc sspt 
		#endif

		// vec3 lightDir = normalize(vec3(0.2,0.8,0.2));
		// float skyLightDir = dot(rayDir,lightDir); // the positons where the occlusion happens

		float skyLightDir = rayDir.y > 0.0 ? 1.0 : max(rayDir.y,1.0-indoor); // the positons where the occlusion happens
		if (rayHit.z > 1.0) occlude += max(rayDir.y,1-AO_Strength);


	}
	// occlude = mix( occlude,1, inShadow);
	// occlude = occlude*0.5 + 0.5;
	lighting *= 2.5;
	lighting *= mix(occlude/nrays,1.0,0) ;
}

void rtGI(inout vec3 lighting, vec3 normal,vec2 noise,vec3 fragpos, float lightmap, vec3 albedo){
	int nrays = RAY_COUNT;
	vec3 intRadiance = vec3(0.0);
	vec3 occlude = vec3(0.0);

	lighting *= 1.50;
	float indoor = clamp(pow(lightmap,2)*2,0.0,AO_Strength);
	
	for (int i = 0; i < nrays; i++){
		int seed = (frameCounter%40000)*nrays+i;
		vec2 ij = fract(R2_samples(seed) + noise );

		vec3 rayDir = TangentToWorld(normal, normalize(cosineHemisphereSample(ij,1.0)) ,1.0);

		#ifdef HQ_SSGI
			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, fragpos,  blueNoise(), 50.); // ssr rt
		#else
			vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, fragpos, blueNoise(), 30.);  // choc sspt 
		#endif
		
		float skyLightDir = rayDir.y > 0.0 ? 1.0 : max(rayDir.y,1.0-indoor); // the positons where the occlusion happens
	
		if (rayHit.z < 1.){
			vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
			previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
			previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
			if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0)
				intRadiance = 0 + texture2D(colortex5,previousPosition.xy).rgb * GI_Strength ;
			else
				intRadiance += lighting*skyLightDir; // make sure ambient light exists but at screen edges when you turn
				
		}else{
			intRadiance += lighting*skyLightDir; 
		}
	}
	lighting = intRadiance/nrays; 
}


void SubsurfaceScattering(inout float SSS, float Scattering, float Density, float LabDenisty){
	#ifdef LabPBR_subsurface_scattering
		float labcurve = pow(LabDenisty,LabSSS_Curve);
		// beers law
		SSS = clamp(exp( Scattering * -(10 - LabDenisty*7)), 0.0, labcurve);
		if (abs(Scattering-0.1) < 0.0004 ) SSS = labcurve;
	#else
		// beers law
		SSS = clamp(exp(Scattering * -Density), 0.0, 1.0);
		if (abs(Scattering-0.1) < 0.0004 ) SSS = 1.0;
	#endif
}




vec3 SubsurfaceScattering_2(vec3 albedo, float Scattering, float Density, float LabDenisty, float lightPos, bool yeSSS){
	if(!yeSSS) return vec3(0.0);

	float density = Density;

	#ifdef LabPBR_subsurface_scattering
		float labcurve = pow(LabDenisty,LabSSS_Curve);
		density = sqrt(30 - labcurve*15);
	#endif

	vec3 absorbed = max(1.0 - albedo,0.0) * density;
	// absorbed = vec3(1.);

	vec3 scatter = exp(-sqrt(Scattering * absorbed)) * exp(Scattering * -density);
	// float gloop = (1.0-exp(sqrt(Scattering) * -density));
	// vec3 scatter = mix(vec3(1.0), max(albedo - gloop * (1-labcurve),0.0), gloop) * exp(Scattering * -density);
	
	#ifdef LabPBR_subsurface_scattering
		scatter *= labcurve;
	#endif

	scatter *= 0.5 + CustomPhase(lightPos, 1.0,30.0)*20;

	return scatter;
}

float densityAtPosSNOW(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}

// Emin's and Gri's combined ideas to stop peter panning and light leaking, also has little shadowacne so thats nice
// https://www.complementary.dev/reimagined
// https://github.com/gri573
void GriAndEminShadowFix(
	inout vec3 WorldPos,
	vec3 FlatNormal,
	float VanillaAO,
	float SkyLightmap,
	bool Entities
){
	float DistanceOffset = clamp(0.1 + length(WorldPos) / (shadowMapResolution*0.20), 0.0,1.0) ;
	vec3 Bias = FlatNormal * DistanceOffset; // adjust the bias thingy's strength as it gets farther away.
	
	// stop lightleaking
	if(SkyLightmap < 0.1 && !Entities) {
		WorldPos += mix(Bias, 0.5 * (0.5 - fract(WorldPos + cameraPosition + FlatNormal*0.01 )	), VanillaAO) ;
	}else{
		WorldPos += Bias;
	}
}

void LabEmission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	// if( Emission < 255.0/255.0 ) Lighting = mix(Lighting, Albedo * Emissive_Brightness, pow(Emission, Emissive_Curve)); // old method.... idk why
	if( Emission < 255.0/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}





#include "lib/PhotonGTAO.glsl"

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
void main() {

	vec2 texcoord = gl_FragCoord.xy*texelSize;




	float z0 = texture2D(depthtex0,texcoord).x;
	float z = texture2D(depthtex1,texcoord).x;
    float TranslucentDepth = clamp( ld(z0)-ld(z0) 	 ,0.0,1.0);

	vec2 tempOffset=TAA_Offset;
	vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
	vec3 fragpos_rtshadow = toScreenSpace(vec3(texcoord/RENDER_SCALE,z));
	vec3 fragpos_handfix = fragpos;

	if ( z < 0.56) fragpos_handfix.z /= MC_HAND_DEPTH; // fix lighting on hand
	
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

	p3 += gbufferModelViewInverse[3].xyz;


	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);

	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / pi;


	#ifdef AEROCHROME_MODE
		totEpsilon *= 10.0;
		scatterCoef *= 0.1;
	#endif

	float noise = blueNoise();


	float iswaterstuff = texture2D(colortex7,texcoord).a ;
	bool iswater = iswaterstuff > 0.99;

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	vec4 data = texture2D(colortex1,texcoord);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
	// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	
	vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
	vec2 lightmap = dataUnpacked1.yz;
	vec3 normal = decode(dataUnpacked0.yw);

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	// vec4 dataTranslucent = texture2D(colortex11,texcoord); 
	// vec4 dataT_Unpacked0 = vec4(decodeVec2(dataTranslucent.x),decodeVec2(dataTranslucent.y));
	// vec4 dataT_Unpacked1 = vec4(decodeVec2(dataTranslucent.z),decodeVec2(dataTranslucent.w));
	// vec4 dataT_Unpacked2 = vec4(decodeVec2(dataTranslucent.z),decodeVec2(dataTranslucent.w));

	////// --------------- UNPACK MISC --------------- //////
	vec4 SpecularTex = texture2D(colortex8,texcoord);

	vec4 normalAndAO = texture2D(colortex15,texcoord);
	vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;
	vec3 slopednormal = normal;

	#ifdef POM
		#ifdef Horrible_slope_normals
    		vec3 ApproximatedFlatNormal = normalize(cross(dFdx(p3), dFdy(p3))); // it uses depth that has POM written to it.
			slopednormal = normalize(clamp(normal, ApproximatedFlatNormal*2.0 - 1.0, ApproximatedFlatNormal*2.0 + 1.0) );
		#endif
	#endif

	float vanilla_AO = normalAndAO.a;
	normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);



	bool translucent = abs(dataUnpacked1.w-0.5) <0.01;	// Strong translucency
	bool translucent2 = abs(dataUnpacked1.w-0.6) <0.01;	// Weak translucency
	bool translucent3 = abs(dataUnpacked1.w-0.55) <0.01;	// all blocks
	bool translucent4 = abs(dataUnpacked1.w-0.65) <0.01;	// Weak translucency
	bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
	
	bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
	bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;
	
	vec3 filtered = vec3(1.412,1.0,0.0);
	if (!hand) filtered = texture2D(colortex3,texcoord).rgb;
	vec3 ambientCoefs = normal/dot(abs(normal),vec3(1.));

	float lightleakfix = clamp(eyeBrightness.y/240.0 + lightmap.y,0.0,1.0);

	vec3 DirectLightColor = (lightCol.rgb/80.0);
	DirectLightColor *= clamp(abs(WsunVec.y)*2,0.,1.);

	float cloudShadow = 1.0;

	if ( z >= 1.) { //sky
		vec3 background = vec3(0.0);
		background += stars(vec3(np3.x,abs(np3.y),np3.z)) * 5.0;

		#ifndef ambientLight_only
			background += drawSun(dot(lightCol.a * WsunVec, np3),0, DirectLightColor,vec3(0.0)) ; // sun 
			background += drawSun(dot(lightCol.a * -WsunVec, np3),0, blackbody2(Moon_temp)/500.,vec3(0.0)); // moon
		#endif
		
		background *= clamp( (np3.y+ 0.02)*5.0 + (eyeAltitude - 319)/800000  ,0.0,1.0);

		vec3 skyTEX = skyFromTex(np3,colortex4)/150.0 * 5.0;
		background += skyTEX;
		// eclipse
		// color *=max(1.0 - drawSun(dot(lightCol.a * WsunVec, (np3-0.0002)*1.001),0, vec3(1),vec3(0.0)),0.0);


		vec4 cloud = texture2D_bicubic(colortex0,texcoord*CLOUDS_QUALITY);
		background = background*cloud.a + cloud.rgb;

		gl_FragData[0].rgb = clamp(fp10Dither(background ,triangularize(noise)),0.0,65000.);

	}else{//land

   	////// ----- direct ----- //////

		vec3 Direct_lighting = vec3(1.0);

		float NdotL = dot(slopednormal,WsunVec);
		NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);
		float Shadows = clamp(1.0 - filtered.b,0.0,1.0);
		
		if (abs(filtered.y-0.1) < 0.0004 && !iswater) Shadows = clamp((lightmap.y-0.85)*25,0,1);
	
		vec3 SSS;
		float SSS_strength;
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

		if (NdotL > 0.001) {
			
			vec3 p3_shadow = mat3(gbufferModelViewInverse) * fragpos_handfix + gbufferModelViewInverse[3].xyz;

			GriAndEminShadowFix(p3_shadow, viewToWorld(FlatNormals), normalAndAO.a, lightmap.y, entities);
			

			vec3 projectedShadowPosition = mat3(shadowModelView) * p3_shadow  + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
		
				float diffthresh = 0.0;
				// if(hand && eyeBrightness.y/240. > 0.0) diffthresh = 0.0003;

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);
				Shadows = 0.0;

				float rdMul = filtered.x*distortFactor*d0*k/shadowMapResolution;

				for(int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++){
					// if(hand) noise = 0.0;
					vec2 offsetS = tapLocation(i,SHADOW_FILTER_SAMPLE_COUNT,1.618,noise,0.0);
					float weight = 1.0+(i+noise)*rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution;
					float isShadow = shadow2D(shadow,vec3(projectedShadowPosition + vec3(rdMul*offsetS,-diffthresh*weight))).x;

					Shadows += isShadow/SHADOW_FILTER_SAMPLE_COUNT;
				}
			}
		}

		#ifdef Sub_surface_scattering
			#ifdef Variable_Penumbra_Shadows
				SSS_strength = 1000;
				if (translucent)  SSS_strength = 2; // low Density
				else if (translucent2) SSS_strength = 5; /// medium Density
				else if (translucent3) SSS_strength = 10; // misc Desnity
				else if (translucent4) SSS_strength = 10; // mob Debsity

				bool hasSSS = SSS_strength < 1000 || LabSSS > 0.0;

				// if(hasSSS) SubsurfaceScattering(SSS, filtered.y, SSS_strength, LabSSS) ;
				
				SSS = SubsurfaceScattering_2(albedo, filtered.y, SSS_strength, LabSSS, clamp(dot(np3, WsunVec),0.0,1.0), hasSSS) ;
					

				// if (isEyeInWater == 0) SSS *= lightleakfix; // light leak fix
			#endif



			if (!hand){

					if (abs(filtered.y-0.1) < 0.0004 && ( !translucent || !translucent2 || !translucent3 ||  !translucent4  ) ) SSS = vec3(0.0);

				#ifndef SCREENSPACE_CONTACT_SHADOWS

					if (abs(filtered.y-0.1) < 0.0004 && ( translucent || translucent2  ||  translucent4 )	) SSS = clamp((lightmap.y-0.87)*25,0,1) * clamp(pow(1+dot(WsunVec,normal),25),0,1) * vec3(1);

				#else
						vec3 vec = lightCol.a*sunVec;
						float screenShadow = rayTraceShadow(vec, fragpos_rtshadow, interleaved_gradientNoise());
						screenShadow *= screenShadow ;

						#ifdef Variable_Penumbra_Shadows
							Shadows = min(screenShadow, Shadows);
							if (abs(filtered.y-0.1) < 0.0004 && ( translucent || translucent2   )	) SSS = vec3(Shadows);
						// #else

						#endif


				#endif
			}

			#ifdef Variable_Penumbra_Shadows
				SSS *= 1.0-NdotL*Shadows;
			#endif
		#else
			 SSS = 0.0;
		#endif

		#ifdef VOLUMETRIC_CLOUDS
		#ifdef CLOUDS_SHADOWS
			cloudShadow = GetCloudShadow(p3);
			Shadows *= cloudShadow;
			SSS *= cloudShadow;
		#endif
		#endif
			 
   	////// ----- indirect ----- //////

		vec3 Indirect_lighting = vec3(1.0);

		// float skylight = clamp(abs(normal.y+1),0.0,1.0);
		float skylight = clamp(abs(ambientCoefs.y+1.0),0.35,2.0);
		

		#if indirect_effect == 2 || indirect_effect == 3 || indirect_effect == 4
			if (!hand)  skylight = 1.0;
		#endif

		// do this to make underwater shading easier.
		vec2 newLightmap = lightmap.xy;
		if((isEyeInWater == 0 && iswater) || (isEyeInWater == 1 && !iswater)) newLightmap.y = min(newLightmap.y+0.1,1.0);
 		
	
		// vec3 LavaGlow = vec3(TORCH_R,TORCH_G,TORCH_B);
		// float thething = pow(clamp(2.0 + dot(viewToWorld(FlatNormals),np3),0.0,2.0),3.0);
		// // LavaGlow *= thething*0.25+0.75;
		// LavaGlow *= mix((2.0-thething)*0.5+0.5, thething*0.25+0.75, sqrt(lightmap.x));

		Indirect_lighting = DoAmbientLighting(avgAmbient, vec3(TORCH_R,TORCH_G,TORCH_B), newLightmap.xy, skylight);

		
		

		vec3 AO = vec3(1.0);
		vec3 debug = vec3(0.0);

		// vanilla AO
		#if indirect_effect == 0
			// AO = vec3(mix(1.0 - exp2(-5 * pow(1-vanilla_AO,3)), 1.0, pow(newLightmap.x,4))) ;
			AO = vec3( exp( (vanilla_AO*vanilla_AO) * -5) ) ;
		#endif

		// SSAO + vanilla AO
		#if indirect_effect == 1
			// AO *= mix(1.0 - exp2(-5 * pow(1-vanilla_AO,3)),1.0, pow(newLightmap.x,4));
			
			AO = vec3( exp( (vanilla_AO*vanilla_AO) * -3) )  ;
			if (!hand) ssAO(AO, fragpos, 1.0, blueNoise(gl_FragCoord.xy).rg,   FlatNormals , texcoord, ambientCoefs, newLightmap.xy);
		#endif

		// GTAO
		#if indirect_effect == 2
			int seed = (frameCounter%40000);
			vec2 r2 = fract(R2_samples(seed) + blueNoise(gl_FragCoord.xy).rg);
			if (!hand) AO = ambient_occlusion(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z), fragpos, worldToView(slopednormal), r2, debug) * vec3(1.0);
		#endif

		// RTAO
		#if indirect_effect == 3
			if (!hand) rtAO(AO, normal, blueNoise(gl_FragCoord.xy).rg, fragpos, newLightmap.y, NdotL*Shadows);
		#endif

		// SSGI
		#if indirect_effect == 4
			if (!hand) rtGI(Indirect_lighting, normal, blueNoise(gl_FragCoord.xy).rg, fragpos, newLightmap.y, albedo);
		#endif

		#ifndef AO_in_sunlight
			AO = mix(AO,vec3(1.0),  min(NdotL*Shadows,1.0));
		#endif

		Indirect_lighting *= AO;

   	////// ----- Under Water Shading ----- //////

		vec3 waterabsorb_speculars = vec3(1);
 		if ((isEyeInWater == 0 && iswater) || (isEyeInWater == 1 && !iswater)){

			vec3 fragpos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z0));
			float Vdiff = distance(fragpos,fragpos0);
			float VdotU = np3.y;
			float estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane
			estimatedDepth = estimatedDepth;
			// make it such that the estimated depth flips to be correct when entering water.

			if (isEyeInWater == 1) estimatedDepth = (1.0-lightmap.y)*16.0;
			
			float estimatedSunDepth = Vdiff; //assuming water plane
			vec3 Absorbtion = exp2(-totEpsilon*estimatedDepth);

			// caustics...
			float Direct_caustics  = waterCaustics(mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition, WsunVec);
			float Ambient_Caustics = waterCaustics(mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition, vec3(0.5, 1.0, 0.5));

			// apply caustics to the lightting
			DirectLightColor 	  *= 0.5 + max(pow(Direct_caustics*2,2),0.0); 
			Indirect_lighting *= 0.5 + max(pow(Ambient_Caustics,2),0.0); 

			// directLightCol 	  *= Direct_caustics; 
			// Indirect_lighting *= Ambient_Caustics*0.5+0.5; 

			// apply water absorbtion to the lighting
			// waterabsorb_speculars.rgb *= Absorbtion;

			DirectLightColor *= Absorbtion;
			// Indirect_lighting *= Absorbtion;

		}



   	////// ----- Finalize ----- //////

		#ifdef Seasons
		#ifdef Snowy_Winter
			vec3 snow_p3 = p3 + cameraPosition;
			float SnowPatches = densityAtPosSNOW(vec3(snow_p3.x,snow_p3.y/48.,snow_p3.z) *250);
			SnowPatches = 1.0 - clamp( exp(pow(SnowPatches,3.5) * -100.0) ,0,1);
			SnowPatches *= clamp(sqrt(normal.y),0,1) * clamp(pow(lightmap.y,25)*25,0,1);

			if(!hand && !iswater){
				albedo = mix(albedo, vec3(0.8,0.9,1.0), SnowPatches);
				SpecularTex.rg = mix(SpecularTex.rg, vec2(1,0.05), SnowPatches);
			}
		#endif
		#endif

		Direct_lighting = DoDirectLighting(DirectLightColor, Shadows, NdotL, 0.0);
		

		#ifdef ambientLight_only
			Direct_lighting = vec3(0.0);
		#endif


		//combine all light sources 
		vec3 FINAL_COLOR = Indirect_lighting + Direct_lighting;
		
		#ifdef Variable_Penumbra_Shadows
			FINAL_COLOR += SSS*DirectLightColor;
		#endif

		FINAL_COLOR *= albedo;

		#ifdef Specular_Reflections	
			MaterialReflections(FINAL_COLOR, SpecularTex.r, SpecularTex.ggg, albedo, WsunVec, (Shadows*NdotL)*DirectLightColor, lightmap.y, slopednormal, np3, fragpos, vec3(blueNoise(gl_FragCoord.xy).rg, interleaved_gradientNoise()), hand, entities);
		#endif

		// #ifdef LabPBR_Emissives
			LabEmission(FINAL_COLOR, albedo, SpecularTex.a);
		// #endif

		gl_FragData[0].rgb =  FINAL_COLOR;
	}
	
   	////// ----- Apply Clouds ----- //////
		// gl_FragData[0].rgb  = gl_FragData[0].rgb *cloud.a + cloud.rgb;

   	////// ----- Under Water Fog ----- //////

	if (iswater){	
		vec3 fragpos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z0));
		float Vdiff = distance(fragpos,fragpos0);
		float VdotU = np3.y;
		float estimatedDepth = Vdiff * abs(VdotU) ;	//assuming water plane
		float estimatedSunDepth = estimatedDepth/abs(WsunVec.y); //assuming water plane
	
		// float custom_lightmap_T = texture2D(colortex14, texcoord).x;  * max(custom_lightmap_T,0.005)// y = torch
	
		vec3 ambientColVol = (avgAmbient * 8./150./1.5);
		vec3 lightColVol = (lightCol.rgb / 80.) ;
	
		if (isEyeInWater == 0) waterVolumetrics(gl_FragData[0].rgb, fragpos0, fragpos, estimatedDepth , estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, WsunVec));		
	}

	// phasefunc =  phaseg(clamp(dot(np3, WsunVec),0.0,1.0), 0.5)*10;

 	//  gl_FragData[0].rgb = vec3(1.0);
	//  if(z < 1)  gl_FragData[0].rgb = Custom_GGX(normal, -np3, WsunVec, SpecularTex.r, SpecularTex.g) * vec3(1.0);


	/* DRAWBUFFERS:3 */
}