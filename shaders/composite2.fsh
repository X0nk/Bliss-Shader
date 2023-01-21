#version 120
//Render sky, volumetric clouds, direct lighting
#extension GL_EXT_gpu_shader4 : enable

#include "lib/settings.glsl"

const bool colortex5MipmapEnabled = true;
// const bool colortex4MipmapEnabled = true;

const bool shadowHardwareFiltering = true;
flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 ambientUp;
flat varying vec3 ambientLeft;
flat varying vec3 ambientRight;
flat varying vec3 ambientB;
flat varying vec3 ambientF;
flat varying vec3 ambientDown;
flat varying vec3 avgAmbient;
flat varying vec3 WsunVec;
flat varying vec2 TAA_Offset;
flat varying float tempOffsets;

uniform int hideGUI;   
uniform float screenBrightness;
/*
const int colortex12Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
const int colortex11Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
const int colortex15Format = RGBA16F;			//Final output, transparencies id (gbuffer->composite4)
*/


uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
// uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex7; // normal
uniform sampler2D colortex6; // Noise
uniform sampler2D colortex8; // specular
// uniform sampler2D colortex9; // specular
uniform sampler2D colortex10; // specular
uniform sampler2D colortex11; // specular
uniform sampler2D colortex12; // specular
uniform sampler2D colortex13; // specular
uniform sampler2D colortex14; // specular
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
uniform float nightVision;
uniform float near;
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
// #include "lib/settings.glsl"
// #include "lib/biome_specifics.glsl"
#include "lib/res_params.glsl"
#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"
#include "lib/waterBump.glsl"
#include "lib/specular.glsl"
#include "lib/bokeh.glsl"
// #include "/lib/climate_settings.glsl"


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

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
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
		float maxZ = min(rayLength,32.0)/(1e-8+rayLength);
		dV *= maxZ;
		vec3 dVWorld = -mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
		rayLength *= maxZ;
		float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
		estEndDepth *= maxZ;
		estSunDepth *= maxZ;
		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);
		float phase =  2*mix(phaseg(VdotL, 0.4),phaseg(VdotL, 0.8),0.5);
		float expFactor = 11.0;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
		for (int i=0;i<spCount;i++) {
			float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
			float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
			vec3 spPos = start.xyz + dV*d;
			progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
			//project into biased shadowmap space
			float distortFactor = calcDistort(spPos.xy);
			vec3 pos = vec3(spPos.xy*distortFactor, spPos.z);
			float sh = 1.0;
			if (abs(pos.x) < 1.0-0.5/2048. && abs(pos.y) < 1.0-0.5/2048){
				pos = pos*vec3(0.5,0.5,0.5/6.0)+0.5;
				sh =  shadow2D( shadow, pos).x;
			}
			#ifdef VOLUMETRIC_CLOUDS
			#ifdef CLOUDS_SHADOWS
				vec3 campos = (progressW)-319;
				// get cloud position
				vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
				// get the cloud density and apply it
				float cloudShadow = getCloudDensity(cloudPos, 1);
				// cloudShadow = exp(-cloudShadow*sqrt(cloudDensity)*50);
				cloudShadow = clamp(exp(-cloudShadow*6),0.0,1.0);
				sh *= cloudShadow;
			#endif
			#endif

			vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs );
			vec3 sunMul = exp(-max(estSunDepth * d,0.0) * waterCoefs);
			// vec3 light = (sh * lightSource*8./150./3.0 * phase * sunMul + ambientMul * ambient)*scatterCoef;

			// vec3 ambientMul = exp(-max(estEyeDepth - dVWorld * d,0.0) * waterCoefs);
			// vec3 sunMul = exp(-max((estEyeDepth - dVWorld * d) ,0.0)/abs(refractedSunVec.y) * waterCoefs)*cloudShadow;
			

			vec3 light = (sh * lightSource * phase * sunMul + (ambientMul*ambient) )*scatterCoef;


			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
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

float rayTraceShadow(vec3 dir,vec3 position,float dither){
    const float quality = 16.;
    vec3 clipPosition = toClipSpace3(position);
	//prevents the ray from going behind the camera
	float rayLength = ((position.z + dir.z * far*sqrt(3.)) > -near) ?
      					 (-near -position.z) / dir.z : far*sqrt(3.) ;
    vec3 direction = toClipSpace3(position+dir*rayLength)-clipPosition;  //convert to clip space
    direction.xyz = direction.xyz/max(abs(direction.x)/texelSize.x,abs(direction.y)/texelSize.y);	//fixed step size
    vec3 stepv = direction *3. * clamp(MC_RENDER_QUALITY,1.,2.0)*vec3(RENDER_SCALE,1.0);
	
	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0);
	spos.xy += (TAA_Offset*(texelSize/4))*RENDER_SCALE ;
	spos += stepv;

	for (int i = 0; i < int(quality); i++) {
		spos += stepv*(dither*0.2 +0.8) *0.5;
		// spos += stepv;
		
		float sp = texture2D(depthtex1,spos.xy).x;
	
        if( sp < spos.z) {
			float dist = abs(linZ(sp)-linZ(spos.z))/linZ(spos.z);
			if (dist < 0.015 ) return 0.0;
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
vec2 hash21(float p)
{
	vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
	p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx+p3.yz)*p3.zy);

}

vec2 vogel_disk_7[7] = vec2[](
   vec2(0.2506005557551467	, -0.08481388042204699) ,
   vec2(-0.3579961502930998	, 0.22787736539225004)	,
   vec2(0.035586177529474045, -0.6801399443380787)	,
   vec2(0.4135705583782951	, 0.4763465923710499)	,
   vec2(-0.8061879331972175	, -0.2244701335533563)	,
   vec2(0.7312484456783402	, -0.560572449689252)	,
   vec2(-0.26682165385093876, 0.8457724502394341)	
);

void ssAO(inout vec3 lighting,	vec3 fragpos,float mulfov, vec2 noise, vec3 normal, vec2 texcoord, vec3 ambientCoefs, vec2 lightmap, float sunlight){

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
		// float thing = sp.y < 0.0 && clamp(floor(abs(NormalSpecific.y)*2.0),0.0,1.0) < 1.0 ? rd * 10: rd;


		// vec2 sampleOffset = sp*thing;
		// vec2 sampleOffset2 =  sp*rd ;
		// sampleOffset = min(sampleOffset, sampleOffset2);
		vec2 sampleOffset = sp*rd;

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

	// occlusion *= mix(2.5, 2.0 ,  clamp(floor(abs(NormalSpecific.y)*2.0),0.0,1.0));
	occlusion = max(1.0 - (occlusion*2.0)/n, 0.0);
	// float skylight = clamp(abs(ambientCoefs.y+1),0.5,1.25) * clamp(abs(ambientCoefs.y+0.5),1.0,1.25);
	float skylight = clamp(abs(ambientCoefs.y+1),0.5,2.0) ;
	// lighting *= 0.5;
	lighting *= mix(1.0,skylight,1);

	lighting = lighting*max(occlusion,pow(lightmap.x,4));
}
vec3 DoContrast(vec3 Color){

	float Contrast =  log(50.0);

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
	
  	for(int i = 0; i < iterations; i++){
		if (spos.x < 0.0 || spos.y < 0.0 || spos.z < 0.0 || spos.x > 1.0 || spos.y > 1.0 || spos.z > 1.0) return vec3(1.1);
		spos += stepv*noise;

		float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/ texelSize/4),0).w/65000.0);
		float currZ = linZ(spos.z);
		
		if( sp < currZ) {
			float dist = abs(sp-currZ)/currZ;
			if (dist <= 0.075) return vec3(spos.xy, invLinZ(sp))/vec3(RENDER_SCALE,1.0);
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
		// if (rayHit.z > 1.0) occlude += skyLightDir;

		occlude += normalize(rayHit.z - 1.0) / (1.1-rayDir.y);


	}
	// occlude = mix( occlude,1, inShadow);
	// occlude = occlude*0.5 + 0.5;
	// lighting *= 2.5;
	lighting *= occlude/nrays;
}



// void rtGI(inout vec3 lighting, vec3 normal,vec2 noise,vec3 fragpos, float lightmap, vec3 albedo, float inShadow){
// 	int nrays = RAY_COUNT;
// 	vec3 intRadiance = vec3(0.0);
// 	vec3 occlude = vec3(0.0);

// 	lighting *= 1.50;
// 	float indoor = clamp(pow(lightmap,2)*2,0.0,AO_Strength);
	
// 	for (int i = 0; i < nrays; i++){
// 		int seed = (frameCounter%40000)*nrays+i;
// 		vec2 ij = fract(R2_samples(seed) + noise );

// 		vec3 rayDir = TangentToWorld(normal, normalize(cosineHemisphereSample(ij,1.0)) ,1.0);

// 		#ifdef HQ_SSGI
// 			vec3 rayHit = rayTrace_GI( mat3(gbufferModelView) * rayDir, fragpos,  blueNoise(), 50.); // ssr rt
// 		#else
// 			vec3 rayHit = RT(mat3(gbufferModelView)*rayDir, fragpos, blueNoise(), 30.);  // choc sspt 
// 		#endif
		
// 		float skyLightDir = rayDir.y > 0.0 ? 1.0 : max(rayDir.y,1.0-indoor); // the positons where the occlusion happens
	
// 		if (rayHit.z < 1.){
// 			vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
// 			previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
// 			previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
// 			if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0)

// 				intRadiance = DoContrast(texture2D(colortex5,previousPosition.xy).rgb) ;
// 			else
// 				intRadiance += lighting*skyLightDir; // make sure ambient light exists but at screen edges when you turn
			

// 		}else{
// 			intRadiance += lighting*skyLightDir; 
// 		}
// 	}
// 	lighting = intRadiance/nrays; 
// }


void rtGI(inout vec3 lighting, vec3 normal,vec2 noise,vec3 fragpos, float lightmap, vec3 albedo, float inShadow){
	int nrays = RAY_COUNT;
	vec3 intRadiance = vec3(0.0);
	vec3 occlusion = vec3(0.0);
	vec3 sunlight =vec3(0);

	// lighting *= 1.50;
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

		// float skyLightDir = rayDir.y > 0.0 ? 1.0 : max(rayDir.y,1.0-indoor); // the positons where the occlusion happens
		
		// vec3 AO = lighting * (normalize(rayHit.z - 1.0) / (1.1-rayDir.y));
		if (rayHit.z < 1){
			vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit)+ gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
		
			previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
			previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;

			if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0){
				intRadiance = DoContrast(texture2D(colortex5,previousPosition.xy).rgb ) ;
			}

		
		}
		occlusion = lighting * (normalize(rayHit.z - 1.0)/(1.1-rayDir.y));

		//  sunlight = lightCol.rgb * min( normalize(rayHit.z - 1.0)  / (1.001-dot(rayDir,WsunVec) ) ,0.1)	;



		// if (rayHit.z < 1.){
		// 	vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rayHit) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
		// 	previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
		// 	previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
		// 	if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0){
		// 		intRadiance += DoContrast(texture2D(colortex5,previousPosition.xy).rgb) ;
		// 	}else{
		// 		intRadiance += lighting;
		// 	}
		// 	// occlude += 1.0;

		// }else{
		// 	intRadiance += lighting;
		// }
	
		// occlude = (lighting/nrays)*(normalize(rayHit.z - 1.0) / (1.1-rayDir.y));

	}
	lighting = occlusion + intRadiance/nrays; 
}



float GetCloudShadow(vec3 eyePlayerPos){
	vec3 p3 = (eyePlayerPos + cameraPosition) - Cloud_Height;
	vec3 cloudPos = p3*Cloud_Size + WsunVec/abs(WsunVec.y) * ((3250 - 3250*0.35) - p3.y*Cloud_Size) ;
	float shadow = getCloudDensity(cloudPos, 1);
	// float shadow = (getCloudDensity(cloudPos, 1) + HighAltitudeClouds(cloudPos)) / 2.0;

	shadow = clamp(exp(-shadow*6),0.0,1.0);

		// float timething = (worldTime%24000)*1.0; 
		// float fadestart_evening = clamp(1.0 - clamp(timething-11500.0 ,0.0,2000.0)/1000. ,0.0,1.0);
		// float fadeend_evening =   clamp(	 clamp(14000.0-timething ,0.0,2000.0)/1000. ,0.0,1.0);

		// float fadestart_morning = clamp(clamp(23500.0-timething ,0.0,2000.0)/1000. ,0.0,1.0);
		// float fadeend_morning =   clamp(1.0 - clamp(timething-200.0 ,0.0,2000.0)/1000. ,0.0,1.0);

		// float TheSettingSun = fadeend_morning;

	return shadow ;
}

void SubsurfaceScattering(inout float SSS, float Scattering, float Density, float LabDenisty){
	#ifdef LabPBR_subsurface_scattering
		float labcurve = pow(LabDenisty,LabSSS_Curve);
		SSS = clamp(exp( -(10 - LabDenisty*7) * sqrt(Scattering) ), 0.0, labcurve);
		if (abs(Scattering-0.1) < 0.0004 ) SSS = labcurve;
	#else
		SSS = clamp(exp( -Density * sqrt(Scattering) ), 0.0, 1.0);
		if (abs(Scattering-0.1) < 0.0004 ) SSS = 1.0;
	#endif
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
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
void main() {

	vec2 texcoord = gl_FragCoord.xy*texelSize;
	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);

	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / pi;
	vec2 tempOffset=TAA_Offset;

	#ifdef AEROCHROME_MODE
		totEpsilon *= 10.0;
		scatterCoef *= 0.1;
	#endif

	float noise = blueNoise();

	float z0 = texture2D(depthtex0,texcoord).x;
	float z = texture2D(depthtex1,texcoord).x;

		
	vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);
	p3 += gbufferModelViewInverse[3].xyz;
	

	#ifdef DOF_JITTER
		vec2 jitter = clamp(jitter_offsets[frameCounter % 64], -1.0, 1.0);
		jitter = rotate(radians(float(frameCounter))) * jitter;
		jitter.y *= aspectRatio;
		jitter.x *= DOF_ANAMORPHIC_RATIO;
		jitter.xy *= 0.004 * JITTER_STRENGTH;

		vec3 fragpos_DOF = toScreenSpace(vec3((texcoord + jitter)/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z));
		vec3 p3_DOF = mat3(gbufferModelViewInverse) * fragpos_DOF;
		vec3 np3_DOF = normVec(p3_DOF);
		p3_DOF += gbufferModelViewInverse[3].xyz;
	#else
		vec2 jitter = vec2(0.0);
		vec3 p3_DOF = p3;
		vec3 np3_DOF = np3;
	#endif

	float iswaterstuff = texture2D(colortex7,texcoord).a ;
	bool iswater = iswaterstuff > 0.99;
	vec4 SpecularTex = texture2D(colortex8,texcoord);

	vec4 data = texture2D(colortex1,texcoord); // terraom
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y));
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));

	vec4 translucentCol = texture2D(colortex13,texcoord); // translucents
	

	vec3 normal = decode(dataUnpacked0.yw);
	
	vec4 normalAndAO = texture2D(colortex15,texcoord);
	float vanilla_AO = normalAndAO.a;

	normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);
	vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;

    vec3 geometryNormal = normalize(cross(dFdx(p3), dFdy(p3)));
	#ifdef Horrible_slope_normals
		vec3 slope_normal = normalize(clamp(normal, geometryNormal*2.0 - 1.0,geometryNormal*2.0 + 1.0));
	#else
		vec3 slope_normal = normal;
	#endif



	vec2 lightmap = dataUnpacked1.yz;

	bool translucent = abs(dataUnpacked1.w-0.5) <0.01;	// Strong translucency
	bool translucent2 = abs(dataUnpacked1.w-0.6) <0.01;	// Weak translucency
	bool translucent3 = abs(dataUnpacked1.w-0.55) <0.01;	// all blocks
	bool translucent4 = abs(dataUnpacked1.w-0.65) <0.01;	// Weak translucency
	bool entities = abs(dataUnpacked1.w-0.45) <0.01;	
	
	bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
	bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;
	
	vec3 filtered = vec3(1.412,1.0,0.0);
	if (!hand) filtered = texture2D(colortex3,texcoord).rgb;

	float Diffuse_final = 1.0;

	vec3 ambientCoefs = slope_normal/dot(abs(slope_normal),vec3(1.));

	float cloudShadow = 1.0;

	vec3 color = vec3(0.0);

	vec3 skyTEX = skyFromTex(np3_DOF,colortex4)/150. ;

	float lightleakfix = clamp(eyeBrightness.y/240.0 + lightmap.y,0.0,1.0);

	if ( z >= 1.) { //sky
	

		vec4 cloud = texture2D_bicubic(colortex0,(texcoord+jitter)*CLOUDS_QUALITY);

		color += stars(np3_DOF);

		#ifndef ambientLight_only
			// #ifdef Allow_Vanilla_sky
			// 	vec3 SkyTextured = toLinear(texture2D(colortex12,texcoord).rgb);
			// 	color += SkyTextured * (lightCol.a == 1 ? lightCol.rgb : 0.75 + blackbody2(Moon_temp)) * sqrt(luma(SkyTextured));
			// #else
				color += drawSun(dot(lightCol.a * WsunVec, np3_DOF),0, lightCol.rgb/150.,vec3(0.0)) ; // sun 
				color += drawSun(dot(lightCol.a * -WsunVec, np3_DOF),0, blackbody2(Moon_temp)/500.,vec3(0.0)); // moon
			// #endif
		#endif
	
		color *= clamp(normalize(np3-0.02).y*5.0,0.0,1.0); // fade from the approximated base of the cloud plane, so it doesnt peek under it.

		color += skyTEX;
		color = color*cloud.a+cloud.rgb;
		
		gl_FragData[0].rgb = clamp(fp10Dither(color * 5.0,triangularize(noise)),0.0,65000.);

	}else{//land



   	////// ----- direct ----- //////

		vec3 Direct_lighting = vec3(1.0);
		vec3 directLightCol = lightCol.rgb;

		float NdotL = dot(slope_normal,WsunVec);
		float diffuseSun = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);

		float shading = clamp(1.0 - filtered.b,0.0,1.0);
		if (abs(filtered.y-0.1) < 0.0004 && !iswater) shading = clamp((lightmap.y-0.85)*25,0,1);
	
		float SSS = 0.0;
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);
		float SSS_strength = 0.0;	
		float scattering = 0.0;


		if (diffuseSun > 0.001) {

			GriAndEminShadowFix(p3, viewToWorld(FlatNormals), normalAndAO.a, lightmap.y, entities);
			// p3 += getShadowBias(p3,FlatNormals, diffuseSun, lightmap.y, normalAndAO.a);

			vec3 projectedShadowPosition = mat3(shadowModelView) * p3  + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;

			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0){
		
				float diffthresh = 0.0;
				if(hand && eyeBrightness.y/240. > 0.0) diffthresh = 0.0003;

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);
				shading = 0.0;

				float rdMul = filtered.x*distortFactor*d0*k/shadowMapResolution;

				for(int i = 0; i < SHADOW_FILTER_SAMPLE_COUNT; i++){
					if(hand) noise = 0.0;
					vec2 offsetS = tapLocation(i,SHADOW_FILTER_SAMPLE_COUNT,1.618,noise,0.0);
					float weight = 1.0+(i+noise)*rdMul/SHADOW_FILTER_SAMPLE_COUNT*shadowMapResolution;
					float isShadow = shadow2D(shadow,vec3(projectedShadowPosition + vec3(rdMul*offsetS,-diffthresh*weight))).x;

					shading += isShadow/SHADOW_FILTER_SAMPLE_COUNT;
				}
			}
		}

		#ifdef CAVE_LIGHT_LEAK_FIX
			if (isEyeInWater == 0 || (iswater && isEyeInWater == 1) ) shading = mix(0.0, shading, lightleakfix);
		#endif

	#ifdef Sub_surface_scattering
		#ifdef Variable_Penumbra_Shadows
	
			if (translucent)  SSS_strength = 3; // strong sss
			else if (translucent2) SSS_strength = 5; /// weak sss
			else if (translucent3) SSS_strength = 5; // misc sss
			else if (translucent4) SSS_strength = 10; // mob sss
			else SSS_strength = -1; // anything less than zero is no SSS

			bool hasSSS = SSS_strength > 0.0 || LabSSS > 0.0 ;

			if(hasSSS) SubsurfaceScattering(SSS, filtered.y, SSS_strength, LabSSS) ;

			if (isEyeInWater == 0) SSS *= lightleakfix; // light leak fix
		#endif



		if (!hand){
			
			 if (abs(filtered.y-0.1) < 0.0004 && ( !translucent || !translucent2 || !translucent3 ||  !translucent4  ) ) SSS = 0.0;

			#ifndef SCREENSPACE_CONTACT_SHADOWS
			
			 if (abs(filtered.y-0.1) < 0.0004 && ( translucent || translucent2  ||  translucent4 )	) SSS = clamp((lightmap.y-0.87)*25,0,1) * clamp(pow(1+dot(WsunVec,normal),25),0,1);
			
			#else
				vec3 vec = lightCol.a*sunVec;
				float screenShadow = rayTraceShadow(vec, fragpos, interleaved_gradientNoise());
				
				#ifdef Variable_Penumbra_Shadows
					shading = min(screenShadow, shading);
					if (abs(filtered.y-0.1) < 0.0004 && ( translucent || translucent2   )	) SSS = shading;
				// #else

				#endif


			#endif
		}

		#ifdef Variable_Penumbra_Shadows
			SSS = clamp(SSS, diffuseSun*shading, 1.0);
			SSS = (phaseg(clamp(dot(np3, WsunVec),0.0,1.0), 0.5) * 10.0 + 1.0 ) * SSS ;
		#endif
		#else
		 SSS = 0.0;
	#endif


		#ifdef VOLUMETRIC_CLOUDS
		#ifdef CLOUDS_SHADOWS
			cloudShadow = GetCloudShadow(p3);
			shading *= cloudShadow;
			SSS *= cloudShadow;
		#endif
		#endif
			 
		Diffuse_final = diffuseSun * shading ;
	
   	////// ----- indirect ----- //////

		vec3 Indirect_lighting = vec3(1.0);

		// vec3 ambientLight = vec3(0.0);
		vec3 ambientLight = avgAmbient * 2.0;
		vec3 custom_lightmap = texture2D(colortex4, (vec2(lightmap.x, pow(lightmap.y,2))*15.0+0.5+vec2(0.0,19.))*texelSize).rgb*8./150./3.; // y = torch

		custom_lightmap.x = max(custom_lightmap.x, Diffuse_final * 8./150./3. ); // make it so that sunlight color is the same even where ambient light is dark
		
		// apply ambient light to the sky lightmap and do adjustments
		ambientLight = ambientLight * custom_lightmap.x + custom_lightmap.z;
		if( (isEyeInWater == 1 && !iswater) ) ambientLight = avgAmbient * 8./150./3.;
		ambientLight *= ambient_brightness;

		// add torch lightmap to ambientlight and do adjustments
		vec3 Lightsources = custom_lightmap.y * vec3(TORCH_R,TORCH_G,TORCH_B);
		if(hand) Lightsources *= 0.15;
		
		// if(blocklights) Lightsources *= 0.3;

		if(custom_lightmap.y > 10.0) Lightsources *= 0.3;
		// Lightsources *= 0.0;


		ambientLight += Lightsources;

		// debug for direct or ambient
		#ifdef ambientLight_only
			directLightCol = vec3(0);
		#endif
		#ifdef ambientLight_only
			Indirect_lighting = vec3(0);
		#endif



		#if indirect_effect == 0
			ambientLight *=  1.0 - exp2(-5 * pow(1-vanilla_AO,3)) ;
			float skylight = clamp(abs(ambientCoefs.y+1),0.35,2.0) ;
			ambientLight *= skylight;
		#endif
		#if indirect_effect == 1
			// ambientLight *=  mix(1.0 - exp2(-5 * pow(1-vanilla_AO,2)), 1.0, diffuseSun*shading) ;
			if (!hand) ssAO(ambientLight, fragpos, 1.0, blueNoise(gl_FragCoord.xy).rg,   FlatNormals , texcoord, ambientCoefs, lightmap.xy, diffuseSun*shading ) ;
		#endif
		#if indirect_effect == 2
			if (!hand) rtAO(ambientLight, slope_normal, blueNoise(gl_FragCoord.xy).rg, fragpos, lightmap.y, diffuseSun*shading);
		#endif
		#if indirect_effect == 3
			if (!hand) rtGI(ambientLight, slope_normal, blueNoise(gl_FragCoord.xy).rg, fragpos, lightmap.y, (directLightCol/127.0), diffuseSun*shading);
		#endif
		#if indirect_effect == 4
			if (!hand) ssDO(ambientLight, fragpos, 1.0, blueNoise(gl_FragCoord.xy).rg,   FlatNormals, worldToView(slope_normal) , texcoord, ambientCoefs, lightmap.xy, diffuseSun*shading ) ;
		#endif
		

		vec3 waterabsorb_speculars = vec3(1);

 		if ((iswater && isEyeInWater == 0) || (!iswater && isEyeInWater == 1)  || iswaterstuff == 1.0){

			vec3 fragpos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z0));
			float Vdiff = distance(fragpos,fragpos0);
			float VdotU = np3.y;
			float estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane
			float estimatedDepth2 = Vdiff * abs(VdotU);	//assuming water plane
			if (isEyeInWater == 1){
				Vdiff = length(fragpos);
				estimatedDepth =  clamp((15.5-lightmap.y*16.0)/15.5,0.,1.0);
				estimatedDepth *= estimatedDepth*estimatedDepth*32.0;

				#ifndef lightMapDepthEstimation
					estimatedDepth = max(Water_Top_Layer - (cameraPosition.y+p3.y),0.0);
				#endif

				estimatedDepth2 =  clamp((15.5-lightmap.y*16.0)/15.5,0.,1.0);
				estimatedDepth2 *= estimatedDepth2*estimatedDepth2*32.0;
			}

			float estimatedSunDepth = estimatedDepth/abs(WsunVec.y); //assuming water plane
			vec3 thething = exp2(-totEpsilon*estimatedSunDepth);
			
			float estimatedSunDepth2 = estimatedDepth2/abs(WsunVec.y); //assuming water plane
			vec3 thething2 = max(exp2(-totEpsilon*estimatedSunDepth2),0.01);
			// water absorbtion for the sunlight. when this isnt active, the water fog is
			if (isEyeInWater == 1) directLightCol *= thething*(0.91-pow(1.0-WsunVec.y,5.0)*0.86);

			// allow the sun specular reflection to have water absorbtion when looking at it from outside the water
			// waterabsorb_speculars.rgb = (iswater && isEyeInWater == 0) ? waterabsorb_speculars.rgb * thething*(0.91-pow(1.0-WsunVec.y,5.0)*0.86) : waterabsorb_speculars.rgb;
			waterabsorb_speculars.rgb = waterabsorb_speculars.rgb*thething;
			// caustics...
			float Direct_caustics  = waterCaustics(mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition, WsunVec);
			float Ambient_Caustics = waterCaustics(mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition, vec3(0.5, 1.0, 0.5));
			
			// apply caustics to the sunlight
			directLightCol *= 0.5 + max(pow(Direct_caustics*2,2),0.0); 

			
			// interpolate between normal ambient light to a different ambient light with caustics and water absorbtion
			Ambient_Caustics = 0.5 + max(pow(Ambient_Caustics,2),0.0);
			// vec3 underwater_ambient = max(Ambient_Caustics ,0.0)  ;  


			// if( (isEyeInWater == 1 && iswater) || (isEyeInWater == 1 && !iswater) ) Indirect_lighting *= 8./150./3.*0.5;
			if( isEyeInWater == 1 && !iswater ) Indirect_lighting = Indirect_lighting*thething + Indirect_lighting*Ambient_Caustics*thething2 + Lightsources	;


			//combine all light sources 
			// Direct_lighting = max(Diffuse_final ,SSS) * (directLightCol/127.0);
			// gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * albedo;

		}
		#ifdef Seasons
		#ifdef Snowy_Winter
			float SnowPatches = densityAtPosSNOW(vec3(p3.x,p3.y/48.,p3.z)*250);
			SnowPatches = 1.0 - clamp( exp(pow(SnowPatches,3.5) * -100.0) ,0,1);
			SnowPatches *= clamp(sqrt(normal.y),0,1) * clamp(pow(lightmap.y,25)*25,0,1);

			if(!hand && !iswater){
				albedo = mix(albedo, vec3(0.8,0.9,1.0), SnowPatches);
				SpecularTex.rg = mix(SpecularTex.rg, vec2(1,0.05), SnowPatches);
			}
		#endif
		#endif
				// do this after water and stuff is done because yea

		Indirect_lighting = ambientLight;
		//combine all light sources 
		Direct_lighting = (Diffuse_final + SSS) * (directLightCol/127.0) ;
		// Direct_lighting = max(Diffuse_final ,SSS) * (directLightCol/127.0) ;
		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * albedo;

		#ifdef Specular_Reflections	
			vec3 fragpos_spec = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
			vec3 p3_spec = mat3(gbufferModelViewInverse) * fragpos_spec;
			vec3 np3_spec = normVec(p3_spec);

			MaterialReflections(texcoord, gl_FragData[0].rgb, SpecularTex.r, SpecularTex.ggg, albedo, WsunVec, lightCol.rgb * waterabsorb_speculars, Diffuse_final , lightmap.y,  slope_normal, np3, fragpos, vec3(blueNoise(gl_FragCoord.xy).rg, interleaved_gradientNoise()), hand);
		#endif

		#ifdef LabPBR_Emissives
			gl_FragData[0].rgb = SpecularTex.a < 255.0/255.0 ? mix(gl_FragData[0].rgb, albedo * Emissive_Brightness , SpecularTex.a) + Direct_lighting*albedo : gl_FragData[0].rgb;
		#endif
	}


	#ifdef Glass_Tint
		// glass tint.
		vec4 glassColor = texture2D(colortex13,texcoord);

		#ifdef BorderFog
			float fog = 1.0 - clamp( exp2(-pow(length(fragpos / far),10.)*4.0)  ,0.0,1.0);
 			if(z < 1.0 && isEyeInWater == 0 && glassColor.a > 0.0) gl_FragData[0].rgb = mix(gl_FragData[0].rgb, skyTEX * 5.0, fog*lightleakfix ) ;
		#endif
		
		float colorstrength = 0.75; 
		glassColor.rgb *=  5.;
		if(glassColor.a > 0.0 && !iswater &&  (iswaterstuff < 0.1 && iswaterstuff > 0.0 )) gl_FragData[0].rgb = gl_FragData[0].rgb*glassColor.rgb + gl_FragData[0].rgb * clamp(pow(1.0-luma(glassColor.rgb),5.),0,1);
	#endif


	if (iswater){
		vec3 fragpos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(tempOffset)*texelSize*0.5,z0));
		float Vdiff = distance(fragpos,fragpos0);
		float VdotU = np3.y;
		float estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane
		float estimatedSunDepth = estimatedDepth/abs(WsunVec.y); //assuming water plane

		float custom_lightmap_T = texture2D(colortex14, texcoord).x; // y = torch

		vec3 ambientColVol = avgAmbient * 8./150./1.5 * max(custom_lightmap_T,0.0025);
		vec3 lightColVol = lightCol.rgb * 8./127. * max(lightleakfix,0.0);

		if (isEyeInWater == 0) waterVolumetrics(gl_FragData[0].rgb, fragpos0, fragpos, estimatedDepth, estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(np3, WsunVec));	
	}


	#ifdef DOF_JITTER
		vec3 laserColor;
		#if FOCUS_LASER_COLOR == 0 // Red
		laserColor = vec3(25, 0, 0);
		#elif FOCUS_LASER_COLOR == 1 // Green
		laserColor = vec3(0, 25, 0);
		#elif FOCUS_LASER_COLOR == 2 // Blue
		laserColor = vec3(0, 0, 25);
		#elif FOCUS_LASER_COLOR == 3 // Pink
		laserColor = vec3(25, 10, 15);
		#elif FOCUS_LASER_COLOR == 4 // Yellow
		laserColor = vec3(25, 25, 0);
		#elif FOCUS_LASER_COLOR == 5 // White
		laserColor = vec3(25);
		#endif

		#if DOF_JITTER_FOCUS < 0
		float focusDist = mix(pow(512.0, screenBrightness), 512.0 * screenBrightness, 0.25);
		#else
		float focusDist = DOF_JITTER_FOCUS;
		#endif

		if( hideGUI < 1.0) gl_FragData[0].rgb += laserColor * pow( clamp( 	 1.0-abs(focusDist-abs(fragpos.z))		,0,1),25) ;
	#endif


	/* RENDERTARGETS:3 */
}