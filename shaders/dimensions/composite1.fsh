#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

const bool colortex5MipmapEnabled = true;

#ifdef OVERWORLD_SHADER
	const bool shadowHardwareFiltering = true;
	uniform sampler2DShadow shadow;


	flat varying vec3 averageSkyCol_Clouds;
	flat varying vec4 lightCol;

	uniform sampler2D colortex14;
	#if Sun_specular_Strength != 0
		#define LIGHTSOURCE_REFLECTION
	#endif
	
	#include "/lib/lightning_stuff.glsl"
#endif

#ifdef NETHER_SHADER

	uniform float nightVision;
	uniform sampler2D colortex4;
	const bool colortex4MipmapEnabled = true;
	uniform vec3 lightningEffect;
	// #define LIGHTSOURCE_REFLECTION
#endif

#ifdef END_SHADER
	uniform float nightVision;
	uniform sampler2D colortex4;
	uniform vec3 lightningEffect;
	
	flat varying float Flashing;
	// #define LIGHTSOURCE_REFLECTION
#endif


uniform sampler2D noisetex; //noise
uniform sampler2D depthtex0; //depth
uniform sampler2D depthtex1; //depth
uniform sampler2D depthtex2; //depth

uniform sampler2D colortex0; //clouds
uniform sampler2D colortex1; //albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex2; //translucents(rgba)
uniform sampler2D colortex3; //filtered shadowmap(VPS)
// uniform sampler2D colortex4; //LUT(rgb), quarter res depth(alpha)
uniform sampler2D colortex5; //TAA buffer/previous frame
uniform sampler2D colortex6; //Noise
uniform sampler2D colortex7; //water?
uniform sampler2D colortex8; //Specular
uniform sampler2D colortex9; //Specular
uniform sampler2D colortex10;
uniform sampler2D colortex15; // flat normals(rgb), vanillaAO(alpha)



uniform mat4 shadowModelView;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjection;
uniform mat4 shadowProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection;
uniform mat4 gbufferPreviousModelView;

uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

// uniform float far;
uniform float near;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;

uniform float eyeAltitude;
flat varying vec2 TAA_Offset;

uniform int frameCounter;
uniform float frameTimeCounter;

uniform float rainStrength;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;

uniform vec3 sunVec;
flat varying vec3 WsunVec;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/sky_gradient.glsl"

#include "/lib/Shadow_Params.glsl"
#include "/lib/Shadows.glsl"
#include "/lib/stars.glsl"

#ifdef OVERWORLD_SHADER
	#include "/lib/volumetricClouds.glsl"
#endif

#include "/lib/diffuse_lighting.glsl"

float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}


#include "/lib/end_fog.glsl"
#include "/lib/specular.glsl"


vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}
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

vec3 fp10Dither(vec3 color,float dither){
	const vec3 mantissaBits = vec3(6.,6.,5.);
	vec3 exponent = floor(log2(color));
	return color + dither*exp2(-mantissaBits)*exp2(exponent);
}



float facos(float sx){
    float x = clamp(abs( sx ),0.,1.);
    return sqrt( 1. - x ) * ( -0.16882 * x + 1.56734 );
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


vec2 tapLocation(int sampleNumber,int nb, float nbRot,float jitter,float distort)
{
		float alpha0 = sampleNumber/nb;
    float alpha = (sampleNumber+jitter)/nb;
    float angle = jitter*6.28 + alpha * 4.0 * 6.28;

    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*sqrt(alpha);
}


vec3 BilateralFiltering(sampler2D tex, sampler2D depth,vec2 coord,float frDepth,float maxZ){
  vec4 sampled = vec4(texelFetch2D(tex,ivec2(coord),0).rgb,1.0);

  return vec3(sampled.x,sampled.yz/sampled.w);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715) ) );
	return noise ;
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}

vec3 toShadowSpaceProjected(vec3 feetPlayerPos){
    feetPlayerPos = mat3(gbufferModelViewInverse) * feetPlayerPos + gbufferModelViewInverse[3].xyz;
    feetPlayerPos = mat3(shadowModelView) * feetPlayerPos + shadowModelView[3].xyz;
    feetPlayerPos = diagonal3(shadowProjection) * feetPlayerPos + shadowProjection[3].xyz;

    return feetPlayerPos;
}

vec2 tapLocation(int sampleNumber, float spinAngle,int nb, float nbRot,float r0)
{
    float alpha = (float(sampleNumber*1.0f + r0) * (1.0 / (nb)));
    float angle = alpha * (nbRot * 6.28) + spinAngle*6.28;

    float ssR = alpha;
    float sin_v, cos_v;

	sin_v = sin(angle);
	cos_v = cos(angle);

    return vec2(cos_v, sin_v)*ssR;
}
vec2 tapLocation_simple(
	int samples, int totalSamples, float rotation, float rng
){
	const float PI = 3.141592653589793238462643383279502884197169;
    float alpha = float(samples + rng) * (1.0 / float(totalSamples));
    float angle = alpha * (rotation * PI);

	float sin_v = sin(angle);
	float cos_v = cos(angle);

    return vec2(cos_v, sin_v) * sqrt(alpha);
}

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}

void waterVolumetrics_notoverworld(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient){
		inColor *= exp(-rayLength * waterCoefs);	//No need to take the integrated value
		int spCount = rayMarchSampleCount;
		vec3 start = toShadowSpaceProjected(rayStart);
		vec3 end = toShadowSpaceProjected(rayEnd);
		vec3 dV = (end-start);
		//limit ray length at 32 blocks for performance and reducing integration error
		//you can't see above this anyway
		float maxZ = min(rayLength,12.0)/(1e-8+rayLength);
		dV *= maxZ;
		vec3 dVWorld = -mat3(gbufferModelViewInverse) * (rayEnd - rayStart) * maxZ;
		rayLength *= maxZ;
		float dY = normalize(mat3(gbufferModelViewInverse) * rayEnd).y * rayLength;
		estEndDepth *= maxZ;
		estSunDepth *= maxZ;
		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);


		float expFactor = 11.0;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
		for (int i=0;i<spCount;i++) {
			float d = (pow(expFactor, float(i+dither)/float(spCount))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
			float dd = pow(expFactor, float(i+dither)/float(spCount)) * log(expFactor) / float(spCount)/(expFactor-1.0);
			vec3 spPos = start.xyz + dV*d;
			progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

			vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs);

			vec3 light =  (ambientMul*ambient) * scatterCoef;

			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs *absorbance;
			absorbance *= exp(-dd * rayLength * waterCoefs);
		}
		inColor += vL;
}

#ifdef OVERWORLD_SHADER

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
float fogPhase(float lightPoint){
	float linear = 1.0 - clamp(lightPoint*0.5+0.5,0.0,1.0);
	float linear2 = 1.0 - clamp(lightPoint,0.0,1.0);

	float exponential = exp2(pow(linear,0.3) * -15.0 ) * 1.5;
	exponential += sqrt(exp2(sqrt(linear) * -12.5));

	return exponential;
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

		vec3 wpos = mat3(gbufferModelViewInverse) * rayStart  + gbufferModelViewInverse[3].xyz;
		vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

		// float phase = (phaseg(VdotL,0.6) + phaseg(VdotL,0.8)) * 0.5;
		float phase = fogPhase(VdotL) ;
		
		vec3 absorbance = vec3(1.0);
		vec3 vL = vec3(0.0);

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
				sh *= GetCloudShadow_VLFOG(progressW,WsunVec);
			#endif

			vec3 sunMul = exp(-max(estSunDepth * d,0.0) * waterCoefs) * 5.0;
			vec3 ambientMul = exp(-max(estEndDepth * d,0.0) * waterCoefs );

			vec3 Directlight = (lightSource * phase * sunMul) * sh;
			vec3 Indirectlight = ambientMul*ambient;

			vec3 light = (Directlight + Indirectlight) * scatterCoef;

			vL += (light - light * exp(-waterCoefs * dd * rayLength)) / waterCoefs * absorbance;
			absorbance *= exp(-dd * rayLength * waterCoefs);
		}
		inColor += vL;
}
#endif

void Emission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	// if( Emission < 255.0/255.0 ) Lighting = mix(Lighting, Albedo * Emissive_Brightness, pow(Emission, Emissive_Curve)); // old method.... idk why
	if( Emission < 255.0/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}

void SSRT_Shadows(vec3 viewPos, vec3 lightDir, float noise, bool isSSS, bool inshadowmap, inout float Shadow, inout float SSS){
    float steps = 16.0;
    vec3 clipPosition = toClipSpace3(viewPos);

	//prevents the ray from going behind the camera
	float rayLength = ((viewPos.z + lightDir.z * far*sqrt(3.)) > -near) ?
      				  (-near -viewPos.z) / lightDir.z : far*sqrt(3.);

    vec3 direction = toClipSpace3(viewPos + lightDir*rayLength) - clipPosition;  //convert to clip space
    direction.xyz = direction.xyz / max(abs(direction.x)/texelSize.x, abs(direction.y)/texelSize.y);	//fixed step size
   
    vec3 rayDir = direction * (isSSS ? 1.5 : 3.0) * vec3(RENDER_SCALE,1.0);
	
	vec3 screenPos = clipPosition*vec3(RENDER_SCALE,1.0) + rayDir*noise;

	if(isSSS) screenPos -= rayDir*0.9;

	float shadowgradient = 0;
	for (int i = 0; i < int(steps); i++) {
		
		screenPos += rayDir;

		float shadowGradient = i/steps;

		float samplePos = texture2D(depthtex1, screenPos.xy).x;
		if(samplePos <= screenPos.z) {
			vec2 linearZ = vec2(linZ(screenPos.z), linZ(samplePos));
			float calcthreshold = abs(linearZ.x - linearZ.y) / linearZ.x;

			bool depthThreshold1 = calcthreshold < 0.015;
			bool depthThreshold2 = calcthreshold < 0.05;

			// if (depthThreshold1) Shadow = inshadowmap ? shadowGradient : 0.0;
			if (depthThreshold1) Shadow = 0.0;

			if (depthThreshold2) SSS = shadowGradient;
				
		}
	}
}

#ifdef END_SHADER
	float GetShading( vec3 WorldPos, vec3 LightPos, vec3 Normal){

		float NdotL = clamp(dot(Normal, normalize(-LightPos)),0.0,1.0);
		float FogShadow = GetCloudShadow(WorldPos, LightPos);

		return EndLightMie(LightPos) * NdotL * FogShadow;
	}
#endif

float CustomPhase(float LightPos){

	float PhaseCurve = 1.0 - LightPos;
	float Final = exp2(sqrt(PhaseCurve) * -25.0);
	Final += exp(PhaseCurve * -10.0)*0.5;

	return Final;
}

vec3 SubsurfaceScattering_sun(vec3 albedo, float Scattering, float Density, float lightPos, bool inShadowmapBounds){

	float labcurve = pow(Density, LabSSS_Curve);

	float density = 15 - labcurve*10;

	vec3 absorbed = max(1.0 - albedo,0.0);

	vec3 scatter = exp(absorbed * Scattering * -5) * exp(Scattering * -density);

	scatter *= labcurve;
	
	// PHASE TIME
	// scatter *= 0.5 + CustomPhase(lightPos) * 13.0; // ~20x brighter at the peak
	// scatter *= 1.0 + CustomPhase(lightPos) * 12.6; // ~20x brighter at the peak

	// scatter *= 0.5 + CustomPhase(lightPos)*6.35; // ~10x brighter at the peak
	scatter *= 1.0 + CustomPhase(lightPos)*6.0; // ~10x brighter at the peak

	return scatter;

}
vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density){


	vec3 absorbed = max(1.0 - albedo,0.0);
	// vec3 scatter =   sqrt(exp(-(absorbed * Scattering * 15))) * (1.0 - Scattering);
	// vec3 scatter =   exp(-5 * Scattering)*vec3(1);
	
	vec3 scatter = exp((Scattering*Scattering) * absorbed  * -5) * sqrt(1.0 - Scattering);

	// scatter *= pow(Density,LabSSS_Curve);
	scatter *= clamp(1 - exp(Density * -10),0,1);


	return scatter ;
}


#include "/lib/indirect_lighting_effects.glsl"
#include "/lib/PhotonGTAO.glsl"

void main() {

	////// --------------- SETUP STUFF --------------- //////
		vec2 texcoord = gl_FragCoord.xy*texelSize;
	
		float z0 = texture2D(depthtex0,texcoord).x;
		float z = texture2D(depthtex1,texcoord).x;

		vec2 bnoise = blueNoise(gl_FragCoord.xy).rg;
		int seed = (frameCounter%40000) + frameCounter*2;
		float noise = fract(R2_samples(seed).y + bnoise.y);
		float noise_2 = R2_dither();

		vec2 tempOffset = TAA_Offset;
		vec3 viewPos = toScreenSpace(vec3(texcoord/RENDER_SCALE - TAA_Offset*texelSize*0.5,z));
		vec3 feetPlayerPos = mat3(gbufferModelViewInverse) * viewPos;
		vec3 feetPlayerPos_normalized = normVec(feetPlayerPos);

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	
		vec4 data = texture2D(colortex1,texcoord);

		vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
		vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
		// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));

		vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
		vec3 normal = decode(dataUnpacked0.yw);
		vec2 lightmap = dataUnpacked1.yz;

		#if defined END_SHADER || defined NETHER_SHADER
			lightmap.y = 1.0;
		#endif

	////// --------------- UNPACK MISC --------------- //////
	
		vec4 SpecularTex = texture2D(colortex8,texcoord);
		float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

		vec4 normalAndAO = texture2D(colortex15,texcoord);
		vec3 FlatNormals = normalAndAO.rgb * 2.0 - 1.0;
		vec3 slopednormal = normal;

		#ifdef POM
			#ifdef Horrible_slope_normals
    			vec3 ApproximatedFlatNormal = normalize(cross(dFdx(feetPlayerPos), dFdy(feetPlayerPos))); // it uses depth that has POM written to it.
				slopednormal = normalize(clamp(normal, ApproximatedFlatNormal*2.0 - 1.0, ApproximatedFlatNormal*2.0 + 1.0) );
			#endif
		#endif

		float vanilla_AO = clamp(normalAndAO.a,0,1);
		normalAndAO.a = clamp(pow(normalAndAO.a*5,4),0,1);

	////// --------------- MASKS/BOOLEANS --------------- //////

		bool iswater = texture2D(colortex7,texcoord).a > 0.99;
		bool lightningBolt = abs(dataUnpacked1.w-0.5) <0.01;
		bool isLeaf = abs(dataUnpacked1.w-0.55) <0.01;
		bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
		// bool isBoss = abs(dataUnpacked1.w-0.60) < 0.01;
		bool isGrass = abs(dataUnpacked1.w-0.60) < 0.01;
		bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
		// bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;


	////// --------------- COLORS --------------- //////

		float dirtAmount = Dirt_Amount;
		vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
		vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
		vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

		vec3 Indirect_lighting = vec3(1.0);
		vec3 AmbientLightColor = vec3(0.0);
		vec3 Indirect_SSS = vec3(0.0);

		vec3 ambientCoefs = slopednormal/dot(abs(slopednormal),vec3(1.));
		
		vec3 Direct_lighting = vec3(0.0);
		vec3 DirectLightColor = vec3(0.0);
		vec3 Direct_SSS = vec3(0.0);
		float cloudShadow = 1.0;
		float Shadows = 1.0;
		float NdotL = 1.0;

		#ifdef OVERWORLD_SHADER
			DirectLightColor = lightCol.rgb/80.0;
			
			#ifdef PER_BIOME_ENVIRONMENT
				BiomeSunlightColor(DirectLightColor);
			#endif
			
			AmbientLightColor = averageSkyCol_Clouds;

			vec3 filteredShadow = vec3(1.412,1.0,0.0);
			if (!hand) filteredShadow = texture2D(colortex3,texcoord).rgb;
			float ShadowBlockerDepth = filteredShadow.y;
			Shadows = clamp(1.0 - filteredShadow.b,0.0,1.0);
			bool inShadowmapBounds = false;
		#endif
	///////////////////////////// start drawin :D

	if (z >= 1.0) {
		
		#ifdef OVERWORLD_SHADER
			vec3 Background = vec3(0.0);

			vec3 orbitstar = vec3(feetPlayerPos_normalized.x,abs(feetPlayerPos_normalized.y),feetPlayerPos_normalized.z); orbitstar.x -= WsunVec.x*0.2;
			Background += stars(orbitstar) * 10.0;


			#if RESOURCEPACK_SKY == 2
				Background += toLinear(texture2D(colortex10, texcoord).rgb * (255.0 * 2.0));
			#else
				#if RESOURCEPACK_SKY == 1
					Background += toLinear(texture2D(colortex10, texcoord).rgb * (255.0 * 2.0));
				#endif
				#ifndef ambientLight_only
					Background += drawSun(dot(lightCol.a * WsunVec, feetPlayerPos_normalized),0, DirectLightColor,vec3(0.0));
					Background += drawMoon(feetPlayerPos_normalized,  lightCol.a * WsunVec, DirectLightColor*20, Background); 
				#endif
			#endif


			Background *= clamp( (feetPlayerPos_normalized.y+ 0.02)*5.0 + (eyeAltitude - 319)/800000  ,0.0,1.0);
			
			vec3 Sky = skyFromTex(feetPlayerPos_normalized, colortex4)/30.0;
			Background += Sky;

			#ifdef VOLUMETRIC_CLOUDS
				vec4 Clouds = texture2D_bicubic(colortex0, texcoord*CLOUDS_QUALITY);
				Background = Background * Clouds.a + Clouds.rgb;
			#endif

			gl_FragData[0].rgb = clamp(fp10Dither(Background, triangularize(noise_2)), 0.0, 65000.);
		#endif

		#if defined NETHER_SHADER || defined END_SHADER
			gl_FragData[0].rgb = vec3(0);
		#endif

	} else {

		feetPlayerPos += gbufferModelViewInverse[3].xyz;
	
	////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	MAJOR LIGHTSOURCE STUFF 	////////////////////////
	////////////////////////////////////////////////////////////////////////////////////
	
	#ifdef OVERWORLD_SHADER
		float LightningPhase = 0.0;
		vec3 LightningFlashLighting = Iris_Lightningflash(feetPlayerPos, lightningBoltPosition.xyz, slopednormal, LightningPhase) * pow(lightmap.y,10);
	#endif

	#ifdef OVERWORLD_SHADER

		NdotL = clamp((-15 + dot(slopednormal, WsunVec)*255.0) / 240.0  ,0.0,1.0);
		
		float shadowNDOTL = NdotL;
		#ifndef Variable_Penumbra_Shadows
			shadowNDOTL += LabSSS;
		#endif

		vec3 feetPlayerPos_shadow = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;

		if(!hand) GriAndEminShadowFix(feetPlayerPos_shadow, viewToWorld(FlatNormals), vanilla_AO, lightmap.y, entities);

		// mat4 Custom_ViewMatrix = BuildShadowViewMatrix(LightDir);
		// vec3 projectedShadowPosition = mat3(Custom_ViewMatrix) * feetPlayerPos_shadow  + Custom_ViewMatrix[3].xyz;
		
		vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos_shadow  + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;
		
		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
		
		bool ShadowBounds = false;
		if(shadowDistanceRenderMul > 0.0) ShadowBounds = length(feetPlayerPos_shadow) < max(shadowDistance - 20,0.0);
		
		if(shadowDistanceRenderMul < 0.0) ShadowBounds = abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0;

		//do shadows only if on shadow map
		if(ShadowBounds){
			if (shadowNDOTL >= -0.001){
				Shadows = 0.0;
				int samples = SHADOW_FILTER_SAMPLE_COUNT;
				float smallbias = 0;

				if(hand){
					samples = 1;
					smallbias = -0.0005;
					noise = 0.5;
				}
				

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

				#ifdef BASIC_SHADOW_FILTER
					#ifndef Variable_Penumbra_Shadows
						if(LabSSS > 0) smallbias = -0.0002;
					#endif
					float rdMul = filteredShadow.x*distortFactor*d0*k/shadowMapResolution;


					for(int i = 0; i < samples; i++){
						vec2 offsetS = tapLocation_simple(i, 7, 9, noise_2) * 0.5;

						float isShadow = shadow2D(shadow, projectedShadowPosition + vec3(rdMul*offsetS, smallbias)	).x;
						Shadows += isShadow/samples;
					}
				#else
					Shadows = shadow2D(shadow, projectedShadowPosition + vec3(0.0,0.0, smallbias)).x;
				#endif
			}
			inShadowmapBounds = true;
		}

		float lightmapAsShadows = 1.0;
		if(!inShadowmapBounds && !iswater){
			lightmapAsShadows = min(max(lightmap.y-0.8, 0.0) * 25,1.0);
			
			Shadows = lightmapAsShadows;
		}

		#ifdef OLD_LIGHTLEAK_FIX
			if (isEyeInWater == 0) Shadows *= clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0); // light leak fix
		#endif



	////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	SUN SSS		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////

		#if SSS_TYPE != 0
			#ifndef Variable_Penumbra_Shadows
				if(LabSSS > 0 ) {
					ShadowBlockerDepth = pow(1.0 - Shadows,2);
				}
			#endif

			if (!inShadowmapBounds) ShadowBlockerDepth = 0.0;

			float sunSSS_density = LabSSS;
			
			#ifndef RENDER_ENTITY_SHADOWS
				if(entities) sunSSS_density = 0.0;
			#endif

			if (!hand){
				#ifdef SCREENSPACE_CONTACT_SHADOWS
					
					float SS_shadow = 1.0; float SS_shadowSSS = 0.0;
					SSRT_Shadows(toScreenSpace(vec3(texcoord/RENDER_SCALE, z)), normalize(WsunVec*mat3(gbufferModelViewInverse)), interleaved_gradientNoise(), !inShadowmapBounds && LabSSS > 0.0, inShadowmapBounds, SS_shadow, SS_shadowSSS);

					Shadows = min(Shadows, SS_shadow);
					
					if (!inShadowmapBounds) ShadowBlockerDepth = max(ShadowBlockerDepth, SS_shadowSSS);
				#else

					if (!inShadowmapBounds) Direct_SSS = vec3(0.0);

				#endif
			
				Direct_SSS = SubsurfaceScattering_sun(albedo, ShadowBlockerDepth, sunSSS_density, clamp(dot(feetPlayerPos_normalized, WsunVec),0.0,1.0), inShadowmapBounds) ;
			}
			
			if (isEyeInWater == 0) Direct_SSS *= clamp(pow(eyeBrightnessSmooth.y/240. + lightmap.y,2.0) ,0.0,1.0); // light leak fix

			if (!inShadowmapBounds){
				Direct_SSS *= lightmapAsShadows;
				Direct_SSS *= 1.0-NdotL;
			}
		#endif



		// #if SSS_TYPE != 0
		// 	Direct_SSS *= 1.0-clamp(NdotL*Shadows,0,1);
		// #endif

		#ifdef CLOUDS_SHADOWS
			cloudShadow = GetCloudShadow(feetPlayerPos);
			Shadows *= cloudShadow;
			Direct_SSS *= cloudShadow;
		#endif

	#endif



	#ifdef END_SHADER
		vec3 LightPos1 = vec3(0); vec3 LightPos2 = vec3(0);
        LightSourcePosition(feetPlayerPos+cameraPosition, cameraPosition, LightPos1, LightPos2);

		vec3 LightCol1 = vec3(0); vec3 LightCol2 = vec3(0);
		LightSourceColors(LightCol1, LightCol2);
		// LightCol1 *= Flashing; 
		LightCol2 *= Flashing;

		Direct_lighting += LightCol1 * GetShading(feetPlayerPos+cameraPosition, LightPos1, slopednormal) ;
		
		#if lightsourceCount == 2
			Direct_lighting += LightCol2 * GetShading(feetPlayerPos+cameraPosition, LightPos2, slopednormal);
		#endif

		// float RT_Shadows = rayTraceShadow(worldToView(normalize(-LightPos)), viewPos, noise);
		// if(!hand) Direct_lighting *= RT_Shadows*RT_Shadows;
	#endif
	
	/////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	INDIRECT LIGHTING 	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////

		#if defined OVERWORLD_SHADER && (indirect_effect == 0 || indirect_effect == 1)

			vec3 ambientcoefs = slopednormal / dot(abs(slopednormal), vec3(1));

			float SkylightDir = ambientcoefs.y*1.5;
			if(isGrass) SkylightDir = 1.25;

			float skylight = max(pow(viewToWorld(FlatNormals).y*0.5+0.5,0.1) + SkylightDir, 0.25 + (1.0-lightmap.y) * 0.75) ;
		
			AmbientLightColor *= skylight;

		#endif

		#ifdef NETHER_SHADER
			AmbientLightColor = skyCloudsFromTexLOD2(normal, colortex4, 6).rgb;

			vec3 up 	= skyCloudsFromTexLOD2(vec3( 0, 1, 0), colortex4, 6).rgb;
			vec3 down 	= skyCloudsFromTexLOD2(vec3( 0,-1, 0), colortex4, 6).rgb;

			up   *= pow( max( slopednormal.y, 0), 2);
			down *= pow( max(-slopednormal.y, 0), 2);
			AmbientLightColor += up + down;
		#endif
		
		#ifdef END_SHADER
			vec3 AmbientLightColor = vec3(1.0);
		#endif

		Indirect_lighting = DoAmbientLightColor(AmbientLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.xy);
		
		#ifdef OVERWORLD_SHADER
			Indirect_lighting += LightningFlashLighting;
		#endif
	////////////////////////////////////////////////////////////////////////////////////////////
	////////////////////////////////	UNDER WATER SHADING		////////////////////////////////
	////////////////////////////////////////////////////////////////////////////////////////////
	#ifdef OVERWORLD_SHADER
 		if ((isEyeInWater == 0 && iswater) || (isEyeInWater == 1 && !iswater)){

			vec3 viewPos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0));
			float Vdiff = distance(viewPos, viewPos0);
			float VdotU = feetPlayerPos_normalized.y;
			float estimatedDepth = Vdiff * abs(VdotU);	//assuming water plane
			estimatedDepth = estimatedDepth;
			// make it such that the estimated depth flips to be correct when entering water.

			if (isEyeInWater == 1) estimatedDepth = (1.0-lightmap.y)*16.0;
			
			float estimatedSunDepth = Vdiff; //assuming water plane
			vec3 Absorbtion = exp2(-totEpsilon*estimatedDepth);

			// caustics...
			float Direct_caustics  = waterCaustics(feetPlayerPos + cameraPosition, WsunVec) * cloudShadow;
			// float Ambient_Caustics = waterCaustics(p3 + cameraPosition, vec3(0.5, 1, 0.5));
			
			// apply caustics to the lighting
			DirectLightColor *= 1.0 + max(pow(Direct_caustics * 3.0, 2.0),0.0);
			// Indirect_lighting *= 0.5 + max(pow(Ambient_Caustics, 2.0),0.0); 

			DirectLightColor *= Absorbtion;
			if(isEyeInWater == 1 ) Indirect_lighting = (Indirect_lighting/exp2(-estimatedDepth*0.5))  * Absorbtion;

			if(isEyeInWater == 0) DirectLightColor *= max(eyeBrightnessSmooth.y/240., 0.0);
			DirectLightColor *= cloudShadow;
		}
	#endif
	/////////////////////////////////////////////////////////////////////////////////////
	/////////////////////////////	EFFECTS FOR INDIRECT	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////////////////
	

		float SkySSS = 0.0;

		#if indirect_effect == 0
			vec3 AO = vec3( exp( (vanilla_AO*vanilla_AO) * -5) )  ;
			Indirect_lighting *= AO;
		#endif

		#if indirect_effect == 1
			vec3 AO = vec3( exp( (vanilla_AO*vanilla_AO) * -3) );

			vec2 SSAO_SSS = SSAO(viewPos, FlatNormals, hand, isLeaf, noise);
			// AO *= exp((1.0-SSAO_SSS.x) * -5.0);
			AO *= SSAO_SSS.x*SSAO_SSS.x*SSAO_SSS.x;
			SkySSS = SSAO_SSS.y;

			Indirect_lighting *= AO;
		#endif

		// GTAO
		#if indirect_effect == 2
			vec3 AO = vec3( exp( (vanilla_AO*vanilla_AO) * -3) );

			vec2 r2 = fract(R2_samples((frameCounter%40000) + frameCounter*2) + bnoise);
			if (!hand) AO = ambient_occlusion(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z), viewPos, worldToView(slopednormal), r2) * vec3(1.0);
			
			Indirect_lighting *= AO;
		#endif

		// RTAO and/or SSGI
		#if indirect_effect == 3 || indirect_effect == 4
			if (!hand) ApplySSRT(Indirect_lighting, viewPos, normal, vec3(bnoise, noise_2), lightmap.xy, AmbientLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), isGrass);
		#endif
		
		#ifdef SSS_view
			// albedo = vec3(1);
			Indirect_lighting = vec3(0.5);
		#endif

	////////////////////////////////	SKY SSS		////////////////////////////////
		#if defined Ambient_SSS && defined OVERWORLD_SHADER
			if (!hand){

				#if indirect_effect != 1
					SkySSS = ScreenSpace_SSS(viewPos, FlatNormals, hand, isLeaf, noise);
				#endif

				vec3 ambientColor = (averageSkyCol_Clouds / 10.0);
				float skylightmap =  pow(lightmap.y,3);

				Indirect_SSS = SubsurfaceScattering_sky(albedo, SkySSS, LabSSS);
				Indirect_SSS *= ambientColor;
				Indirect_SSS *= skylightmap;

				vec3 SSS_forSky = vec3((1.0 - SkySSS) * LabSSS);
				SSS_forSky *= ambientColor;
				SSS_forSky *= skylightmap;

				//light up dark parts so its more visible
				Indirect_lighting = max(Indirect_lighting, SSS_forSky);

				// apply to ambient light.
				Indirect_lighting = max(Indirect_lighting, Indirect_SSS * ambientsss_brightness);
			
				#ifdef OVERWORLD_SHADER
					if(LabSSS > 0.0) Indirect_lighting += (1.0-SkySSS) * LightningPhase * lightningEffect *  pow(lightmap.y,10);
				#endif
				
			}
		#endif

	/////////////////////////////////////////////////////////////////////////
	/////////////////////////////	FINALIZE	/////////////////////////////
	/////////////////////////////////////////////////////////////////////////
		#ifdef SSS_view
			albedo = vec3(1);
		#endif

		#ifdef OVERWORLD_SHADER
			// do these here so it gets underwater absorbtion.
			Direct_lighting =  max(DirectLightColor * (NdotL * Shadows), DirectLightColor * Direct_SSS);
		#endif

		gl_FragData[0].rgb = (Indirect_lighting + Direct_lighting) * albedo;

		#ifdef Specular_Reflections	
			vec2 specularNoises = vec2(noise, R2_dither());
			DoSpecularReflections(gl_FragData[0].rgb, viewPos, feetPlayerPos_normalized, WsunVec, specularNoises, normal, SpecularTex.r, SpecularTex.g, albedo, DirectLightColor*Shadows*NdotL, lightmap.y, hand);
		#endif

		Emission(gl_FragData[0].rgb, albedo, SpecularTex.a);
		
		if(lightningBolt) gl_FragData[0].rgb = vec3(77.0, 153.0, 255.0);
	}
	
	#ifdef OVERWORLD_SHADER
		if (iswater && isEyeInWater == 0){
			vec3 viewPos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0));
			float Vdiff = distance(viewPos,viewPos0);
			float VdotU = feetPlayerPos_normalized.y;
			float estimatedDepth = Vdiff * abs(VdotU) ;	//assuming water plane
			float estimatedSunDepth = estimatedDepth/abs(WsunVec.y); //assuming water plane

			float custom_lightmap_T = clamp(pow(texture2D(colortex14, texcoord).a,3.0),0.0,1.0);

			vec3 lightColVol = lightCol.rgb / 80.;
			// if(shadowmapindicator < 1) lightColVol *= clamp((custom_lightmap_T-0.8) * 15,0,1)

			vec3 lightningColor = (lightningEffect / 3) * (max(eyeBrightnessSmooth.y,0)/240.);
			vec3 ambientColVol =  max((averageSkyCol_Clouds / 30.0) *  custom_lightmap_T, vec3(0.2,0.4,1.0) * (MIN_LIGHT_AMOUNT*0.01 + nightVision)) ;

			waterVolumetrics(gl_FragData[0].rgb, viewPos0, viewPos, estimatedDepth , estimatedSunDepth, Vdiff, noise_2, totEpsilon, scatterCoef, ambientColVol, lightColVol, dot(feetPlayerPos_normalized, WsunVec));		
		}
	#else
		if (iswater && isEyeInWater == 0){
			vec3 viewPos0 = toScreenSpace(vec3(texcoord/RENDER_SCALE-TAA_Offset*texelSize*0.5,z0));
			float Vdiff = distance(viewPos,viewPos0);
			float VdotU = feetPlayerPos_normalized.y;
			float estimatedDepth = Vdiff * abs(VdotU) ;	//assuming water plane

			vec3 ambientColVol =  max(vec3(1.0,0.5,1.0) * 0.3, vec3(0.2,0.4,1.0) * (MIN_LIGHT_AMOUNT*0.01 + nightVision));
			
			waterVolumetrics_notoverworld(gl_FragData[0].rgb, viewPos0, viewPos, estimatedDepth , estimatedDepth, Vdiff, noise_2, totEpsilon, scatterCoef, ambientColVol);
		}
	#endif

	
	
/* DRAWBUFFERS:3 */
}