#version 120
#extension GL_EXT_gpu_shader4 : enable

#include "/lib/settings.glsl"

#define NETHER
#include "/lib/diffuse_lighting.glsl"


varying vec2 texcoord;

flat varying vec3 avgAmbient;

flat varying vec2 TAA_Offset;
flat varying float tempOffsets;

const bool colortex5MipmapEnabled = true;

uniform sampler2D colortex0;//clouds
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform sampler2D colortex4;//Skybox
uniform sampler2D colortex3;
uniform sampler2D colortex7;
uniform sampler2D colortex5;
uniform sampler2D colortex2;
uniform sampler2D colortex8;
uniform sampler2D colortex15;
uniform sampler2D colortex6;//Skybox
uniform sampler2D depthtex1;//depth
uniform sampler2D depthtex0;//depth
uniform sampler2D noisetex;//depth

uniform int heldBlockLightValue;
uniform int frameCounter;
uniform int isEyeInWater;
uniform mat4 shadowModelViewInverse;
uniform mat4 shadowProjectionInverse;
uniform float far;
uniform float near;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;
uniform mat4 gbufferModelView;

uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 previousCameraPosition;

uniform vec2 texelSize;
uniform float viewWidth;
uniform float viewHeight;
uniform float aspectRatio;
uniform vec3 cameraPosition;
uniform vec3 sunVec;
uniform ivec2 eyeBrightnessSmooth;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}


#include "/lib/color_transforms.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/sky_gradient.glsl"




float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

vec2 RENDER_SCALE = vec2(1.0);

#include "/lib/specular.glsl"
#include "/lib/nether_fog.glsl"





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
float interleaved_gradientNoise(float temp){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+temp);
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
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
// float linZ(float depth) {
//     return (2.0 * near) / (far + near - depth * (far - near));
// 	// l = (2*n)/(f+n-d(f-n))
// 	// f+n-d(f-n) = 2n/l
// 	// -d(f-n) = ((2n/l)-f-n)
// 	// d = -((2n/l)-f-n)/(f-n)

// }
// float invLinZ (float lindepth){
// 	return -((2.0*near/lindepth)-far-near)/(far-near);
// }

// vec3 toClipSpace3(vec3 viewSpacePosition) {
//     return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
// }




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
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y);
}
vec3 toShadowSpaceProjected(vec3 p3){
    p3 = mat3(gbufferModelViewInverse) * p3 + gbufferModelViewInverse[3].xyz;
    p3 = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
    p3 = diagonal3(shadowProjection) * p3 + shadowProjection[3].xyz;

    return p3;
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


float ssao(vec3 fragpos, float dither,vec3 normal)
{
	float mulfov = 1.0;
	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/180.);
	float mulfov2 = gbufferProjection[1][1]/tan70;

	const float PI = 3.14159265;
	const float samplingRadius = 0.712;
	float angle_thresh = 0.05;




	float rd = mulfov2*0.05;
	//pre-rotate direction
	float n = 0.;

	float occlusion = 0.0;

	vec2 acc = -vec2(TAA_Offset)*texelSize*0.5;
	float mult = (dot(normal,normalize(fragpos))+1.0)*0.5+0.5;

	vec2 v = fract(vec2(dither,interleaved_gradientNoise()) + (frameCounter%10000) * vec2(0.75487765, 0.56984026));
	for (int j = 0; j < 7+2 ;j++) {
			vec2 sp = tapLocation(j,v.x,7+2,2.,v.y);
			vec2 sampleOffset = sp*rd;
			ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight));
			if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth && offset.y < viewHeight ) {
				vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x));

				vec3 vec = t0.xyz - fragpos;
				float dsquared = dot(vec,vec);
				if (dsquared > 1e-5){
					if (dsquared < fragpos.z*fragpos.z*0.05*0.05*mulfov2*2.*1.412){
						float NdotV = clamp(dot(vec*inversesqrt(dsquared), normalize(normal)),0.,1.);
						occlusion += NdotV;
					}
					n += 1.0;
				}
			}
		}




		return clamp(1.0-occlusion/n*2.0,0.,1.0);
}
vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}
vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
void waterVolumetrics(inout vec3 inColor, vec3 rayStart, vec3 rayEnd, float estEndDepth, float estSunDepth, float rayLength, float dither, vec3 waterCoefs, vec3 scatterCoef, vec3 ambient){
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

vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
}

void LabEmission(
	inout vec3 Lighting,
	vec3 Albedo,
	float Emission
){
	// if( Emission < 255.0/255.0 ) Lighting = mix(Lighting, Albedo * Emissive_Brightness, pow(Emission, Emissive_Curve)); // old method.... idk why
	if( Emission < 255.0/255.0 ) Lighting += (Albedo * Emissive_Brightness) * pow(Emission, Emissive_Curve);
}


vec3 SubsurfaceScattering_sky(vec3 albedo, float Scattering, float Density){

	vec3 absorbed = max(luma(albedo) - albedo,0.0);

	// vec3 scatter = exp(-sqrt(max(Scattering+0.05,0.0) * absorbed * 25)) * exp(Scattering * -5);
	vec3 scatter =   exp(-sqrt(Scattering * absorbed * 5)) * pow((-Scattering+1.0)*1.25,2.0);
	scatter *= pow(Density,LabSSS_Curve);
	// temporary

	scatter *= ambientsss_brightness;

	return scatter;
}

void ScreenSpace_SSS(inout float sss, vec3 fragpos, vec2 noise, vec3 normal){
	ivec2 pos = ivec2(gl_FragCoord.xy);
	const float tan70 = tan(70.*3.14/180.);

	float dist = 1.0 + (clamp(fragpos.z*fragpos.z/50.0,0,2)); // shrink sample size as distance increases
	float mulfov2 = gbufferProjection[1][1]/(tan70 * dist);

	float dist3 = clamp(1-exp( fragpos.z*fragpos.z / -50),0,1);
	float maxR2_2 = mix(10, fragpos.z*fragpos.z*mulfov2*2./50.0, dist3);

	float rd = mulfov2 * 0.1;


	vec2 acc = -(TAA_Offset*(texelSize/2)) ;

	// int seed = (frameCounter%40000)*2 + (1+frameCounter);
	// float randomDir = fract(R2_samples(seed).y + noise.x ) * 1.61803398874 ;

	float n = 0.0;
	vec2 v = fract(vec2(noise.x,interleaved_gradientNoise()) + (frameCounter%10000) * vec2(0.75487765, 0.56984026));

	for (int j = 0; j < 7+2 ;j++) {

			vec2 sp = tapLocation(j,v.x,7+2,2.,v.y);
		
		// vec2 sp = tapLocation_alternate(j, 0.0, 7, 20, randomDir);
		vec2 sampleOffset = sp*rd;
		ivec2 offset = ivec2(gl_FragCoord.xy + sampleOffset*vec2(viewWidth,viewHeight*aspectRatio));

		if (offset.x >= 0 && offset.y >= 0 && offset.x < viewWidth && offset.y < viewHeight ) {
			vec3 t0 = toScreenSpace(vec3(offset*texelSize+acc+0.5*texelSize,texelFetch2D(depthtex1,offset,0).x) );
			vec3 vec = t0.xyz - fragpos;
			float dsquared = dot(vec,vec);

			if (dsquared > 1e-5){
				if(dsquared > maxR2_2){
					float NdotV = 1.0 - clamp(dot(vec*dsquared, normalize(normal)),0.,1.);
					sss += max((NdotV - (1.0-NdotV)) * clamp(1.0-maxR2_2/dsquared,0.0,1.0) ,0.0);
				}
				n += 1;
			}
		}
	}
	sss = max(1.0 - sss/n, 0.0);
}







void main() {
	float dirtAmount = Dirt_Amount;
	vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
	vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
	vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

	float z0 = texture2D(depthtex0,texcoord).x;
	float z = texture2D(depthtex1,texcoord).x;

	vec2 tempOffset=TAA_Offset;
	float noise = blueNoise();

	vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);


	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	
	vec4 data = texture2D(colortex1,texcoord);
	vec4 dataUnpacked0 = vec4(decodeVec2(data.x),decodeVec2(data.y)); // albedo, masks
	vec4 dataUnpacked1 = vec4(decodeVec2(data.z),decodeVec2(data.w)); // normals, lightmaps
	// vec4 dataUnpacked2 = vec4(decodeVec2(data.z),decodeVec2(data.w));
	
	vec3 albedo = toLinear(vec3(dataUnpacked0.xz,dataUnpacked1.x));
	vec2 lightmap = dataUnpacked1.yz;
	vec3 normal = decode(dataUnpacked0.yw);
	
	////// --------------- UNPACK MISC --------------- //////
	
	vec4 SpecularTex = texture2D(colortex8,texcoord);
	float LabSSS = clamp((-65.0 + SpecularTex.z * 255.0) / 190.0 ,0.0,1.0);	

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

	

	bool iswater = texture2D(colortex7,texcoord).a > 0.99;
	bool lightningBolt = abs(dataUnpacked1.w-0.5) <0.01;
	bool isLeaf = abs(dataUnpacked1.w-0.55) <0.01;
	bool entities = abs(dataUnpacked1.w-0.45) < 0.01;	
	
	bool hand = abs(dataUnpacked1.w-0.75) < 0.01;
	// bool blocklights = abs(dataUnpacked1.w-0.8) <0.01;

	if (z >=1.0) {
		vec3 color = clamp(gl_Fog.color.rgb*pow(luma(gl_Fog.color.rgb),-0.75)*0.65,0.0,1.0)*0.02;

		gl_FragData[0].rgb = clamp(fp10Dither(color*8./3. * (1.0-rainStrength*0.4),triangularize(noise)),0.0,65000.);

	} else {

		p3 += gbufferModelViewInverse[3].xyz + cameraPosition;

    	vec3 FogColor =  (gl_Fog.color.rgb / pow(0.00001 + dot(gl_Fog.color.rgb,vec3(0.3333)),1.0) ) * 0.2;

		// do all ambient lighting stuff
		vec3 Indirect_lighting = DoAmbientLighting_Nether(FogColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmap.x, normal, np3, p3 );
		
		vec3 AO = vec3( exp( (vanilla_AO*vanilla_AO) * -5) )  ;

		if(!hand) Indirect_lighting *= ssao(fragpos,noise,FlatNormals) * AO;


		// ScreenSpace_SSS(Indirect_SSS, fragpos, vec2(R2_dither()), FlatNormals);


		// Indirect_lighting *= 1 + SubsurfaceScattering_sky(albedo, Indirect_SSS, LabSSS) * 5;



        vec3 LightColor = LightSourceColor();
		
		float SdotV = dot(normalize(viewspace_sunvec), normalize(fragpos));
		float OrbMie = max(exp((p3.y - 60) / -30.),0);
		
		// 0.5 added because lightsources are always high radius.
		float NdotL = clamp( dot(normal,normalize(WsunVec)) + 0.25,0.0,1.0);

		vec3 LightSource = LightColor * NdotL * OrbMie ;

		// LightSource *= rayTraceShadow(worldToView(normalize(-LightPos)), fragpos, interleaved_gradientNoise());
		// LightSource *= GetCloudShadow(p3, WsunVec, blueNoise());


		// finalize
		gl_FragData[0].rgb = Indirect_lighting * albedo;
		// gl_FragData[0].rgb = LightSource * albedo;

		#ifdef Specular_Reflections	
			MaterialReflections_N(gl_FragData[0].rgb, SpecularTex.r, SpecularTex.ggg, albedo, normal, np3, fragpos, vec3(blueNoise(gl_FragCoord.xy).rg,noise), hand);
		#endif

		LabEmission(gl_FragData[0].rgb, albedo, SpecularTex.a);

		if(lightningBolt) gl_FragData[0].rgb += vec3(Lightning_R,Lightning_G,Lightning_B) ;

	}

  	// ////// border Fog
	// if(Translucent_Programs > 0.0){
	// 	vec3 fragpos = toScreenSpace(vec3(texcoord-vec2(0.0)*texelSize*0.5,z));
    // 	float fogdistfade = 1.0 - clamp( exp(-pow(length(fragpos / far),2.)*5.0)  ,0.0,1.0);

    // 	gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb*0.5*NetherFog_brightness, fogdistfade) ;
	// }

	
  	////// Water Fog
 	if ((isEyeInWater == 0 && iswater) || (isEyeInWater == 1 && !iswater)){
		vec3 fragpos0 = toScreenSpace(vec3(texcoord-vec2(tempOffset)*texelSize*0.5,z0));
		float Vdiff = distance(fragpos,fragpos0);

		if(isEyeInWater == 1) Vdiff = (length(fragpos)); 

		float VdotU = np3.y;
		float estimatedDepth = Vdiff;	//assuming water plane
		float estimatedSunDepth = estimatedDepth; //assuming water plane

		vec3 ambientColVol = vec3(1.0,0.25,0.5) * 0.33 ;

		waterVolumetrics(gl_FragData[0].rgb, fragpos0, fragpos, estimatedDepth , estimatedSunDepth, Vdiff, noise, totEpsilon, scatterCoef, ambientColVol);	
	}



	// gl_FragData[0].rgb = SubsurfaceScattering_sky(albedo, Indirect_SSS, 1.0) * vec3(1);
/* DRAWBUFFERS:3 */
}
