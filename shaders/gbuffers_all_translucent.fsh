// #version 120
//#extension GL_EXT_gpu_shader4 : disable

varying vec4 lmtexcoord;
varying vec4 color;


uniform sampler2D normals;
varying vec4 tangent;

varying vec4 normalMat;
varying vec3 binormal;


varying vec3 viewVector;

#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"


uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;
// uniform sampler2D gaux2;
// uniform sampler2D gaux1;

// uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D depthtex1;


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
uniform ivec2 eyeBrightness;
uniform ivec2 eyeBrightnessSmooth;


flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)

flat varying vec3 averageSkyCol_Clouds;
// flat varying vec3 averageSkyCol;



#include "/lib/Shadow_Params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/projections.glsl"
#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/clouds.glsl"
#include "/lib/stars.glsl"
#include "/lib/volumetricClouds.glsl"
#define OVERWORLD
#include "/lib/diffuse_lighting.glsl"


float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000);
	// vec2 coord = gl_FragCoord.xy + frameTimeCounter;
	// vec2 coord = gl_FragCoord.xy;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715)) );
	return noise ;
}
float interleaved_gradientNoise(float temporal){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y)+temporal);
	return noise;
}

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);







#define PW_DEPTH 1.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
#define PW_POINTS 1 //[2 4 6 8 16 32]

vec3 getParallaxDisplacement(vec3 posxz, float iswater,float bumpmult,vec3 viewVec) {
	float waveZ = mix(20.0,0.25,iswater);
	float waveM = mix(0.0,4.0,iswater);

	vec3 parallaxPos = posxz;
	vec2 vec = viewVector.xy * (1.0 / float(PW_POINTS)) * 22.0 * PW_DEPTH;
	float waterHeight = getWaterHeightmap(posxz.xz, waveM, waveZ, iswater) ;
	
	parallaxPos.xz += waterHeight * vec;

	return parallaxPos;

}

vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
	float bumpmult = 1;
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	return normalize(bump*tbnMatrix);
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
vec4 encode (vec3 n, vec2 lightmaps){
	n.xy = n.xy / dot(abs(n), vec3(1.0));
	n.xy = n.z <= 0.0 ? (1.0 - abs(n.yx)) * sign(n.xy) : n.xy;
    vec2 encn = clamp(n.xy * 0.5 + 0.5,-1.0,1.0);
	
    return vec4(encn,vec2(lightmaps.x,lightmaps.y));
}

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}


float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
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

	float dist = 1.0 + clamp(position.z*position.z/50.0,0,2); // shrink sample size as distance increases
    for (int i = 0; i <= int(quality); i++) {
		#ifdef USE_QUARTER_RES_DEPTH
				// decode depth buffer
				float sp = sqrt(texelFetch2D(colortex4,ivec2(spos.xy/texelSize/4),0).w/65000.0);
				sp = invLinZ(sp);

         		if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);
		#else
			float sp = texelFetch2D(depthtex1,ivec2(spos.xy/texelSize),0).r;
          	if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);
	        

		#endif

        spos += stepv;
		//small bias
		minZ = maxZ-(0.0001/dist)/ld(spos.z);
		if(inwater) minZ = maxZ-0.0004/ld(spos.z);
		maxZ += stepv.z;
    }

    return vec3(1.1);
}

vec3 GGX (vec3 n, vec3 v, vec3 l, float r, vec3 F0) {
  r = pow(r,2.5);
//   r*=r;

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);
  vec3 F = F0 + (1. - F0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}



#define PHYSICSMOD_FRAGMENT
#include "/lib/oceans.glsl"

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS:2,7,11,14 */
void main() {
if (gl_FragCoord.x * texelSize.x < RENDER_SCALE.x  && gl_FragCoord.y * texelSize.y < RENDER_SCALE.y )	{
	vec2 tempOffset = offsets[framemod8];
	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));

	gl_FragData[0] = texture2D(texture, lmtexcoord.xy, Texture_MipMap_Bias) * color;
	vec3 Albedo = toLinear(gl_FragData[0].rgb);

	float UnchangedAlpha = gl_FragData[0].a;

	float iswater = normalMat.w;

	#ifdef HAND
		iswater = 0.1;
	#endif

	#ifdef Vanilla_like_water
		if (iswater > 0.5) {
			gl_FragData[0].a = luma(Albedo.rgb);
			Albedo = color.rgb * sqrt(luma(Albedo.rgb));
		}
	#else
		if (iswater > 0.9) {
			Albedo = vec3(0.0);
			gl_FragData[0] = vec4(vec3(0.0),1.0/255.0);
		}
	#endif


	vec4 COLORTEST = vec4(Albedo,UnchangedAlpha);


	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;

	vec3 normal = normalMat.xyz;
	vec2 TangentNormal = vec2(0); // for refractions
	
	vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
	mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
							  tangent.y, tangent2.y, normal.y,
							  tangent.z, tangent2.z, normal.z);

	


	/// ------ NORMALS ------ ///

	vec4 NormalTex = texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).rgba;
	NormalTex.xy = NormalTex.xy*2.0-1.0;
	NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0) ;
	TangentNormal = NormalTex.xy*0.5+0.5;

	normal = applyBump(tbnMatrix, NormalTex.xyz,  1.0);

	if (iswater > 0.95){
		#ifdef PhysicsMod_support
		if(physics_iterationsNormal < 1.0){
		#endif
			float bumpmult = 1.0;
			vec3 bump = vec3(0);
			vec3 posxz = p3+cameraPosition;

			posxz.xz -= posxz.y;
			posxz.xyz = getParallaxDisplacement(posxz,iswater,bumpmult,normalize(tbnMatrix*fragpos)) ;

			bump = normalize(getWaveHeight(posxz.xz,iswater));
			
			TangentNormal = bump.xy*0.5+0.5; // tangent space normals for refraction

			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			normal = normalize(bump * tbnMatrix);
		
		#ifdef PhysicsMod_support
		}else{	
			/// ------ PHYSICS MOD OCEAN SHIT ------ ///
		
			WavePixelData wave = physics_wavePixel(physics_localPosition.xz, physics_localWaviness, physics_iterationsNormal, physics_gameTime);
			// float Foam = wave.foam;
		
			// Albedo = mix(Albedo,vec3(1),Foam);
			// gl_FragData[0].a = Foam;
			
			
			normal = normalize(worldToView(wave.normal) + mix(normal, vec3(0.0), clamp(physics_localWaviness,0.0,1.0)));
		
			vec3 worldSpaceNormal = normal;
		
			vec3 bitangent = normalize(cross(tangent.xyz, worldSpaceNormal));
			mat3 tbn_new =  mat3(tangent.xyz, binormal, worldSpaceNormal);
			vec3 tangentSpaceNormal = worldSpaceNormal * tbn_new;
		
			TangentNormal = tangentSpaceNormal.xy * 0.5 + 0.5;
		}
		#endif
	}

	gl_FragData[2] = vec4(encodeVec2(TangentNormal), encodeVec2(COLORTEST.rg), encodeVec2(COLORTEST.ba), UnchangedAlpha);

	
	float NdotL = clamp(lightSign*dot(normal,sunVec) ,0.0,1.0);
	NdotL =  clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);

	float Shadows = 1.0;
	int shadowmapindicator = 0;
	//compute shadows only if not backface
	if (NdotL > 0.001) {
		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
		projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

		//apply distortion
		float distortFactor = calcDistort(projectedShadowPosition.xy);
		projectedShadowPosition.xy *= distortFactor;
		//do shadows only if on shadow map
		if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
			
			Shadows = 0.0;
			projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);
			
			#ifdef BASIC_SHADOW_FILTER
				const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
				float distortThresh = (sqrt(1.0-NdotL*NdotL)/NdotL+0.7)/distortFactor;
				float diffthresh = distortThresh/6000.0*threshMul;

				float noise = blueNoise();
				float rdMul = 4.0/shadowMapResolution;

				for(int i = 0; i < 9; i++){
					vec2 offsetS = tapLocation(i,9, 1.618,noise,0.0);

					float weight = 1.0+(i+noise)*rdMul/9.0*shadowMapResolution;
					Shadows += shadow2D(shadow,vec3(projectedShadowPosition + vec3(rdMul*offsetS,-diffthresh*weight))).x/9.0;
				}
			#else
				Shadows = shadow2D(shadow, projectedShadowPosition + vec3(0.0,0.0,-0.0001)).x;
			#endif
			
			shadowmapindicator = 1;
		}
	}

	if(shadowmapindicator < 1) Shadows = clamp((lmtexcoord.w-0.8) * 5,0,1);

	#ifdef CLOUDS_SHADOWS
		Shadows *= GetCloudShadow(p3);
	#endif

	vec3 AmbientLightColor = averageSkyCol_Clouds;
	vec3 DirectLightColor = lightCol.rgb/80.0;

	vec3 WS_normal = viewToWorld(normal);
	vec3 ambientCoefs = WS_normal/dot(abs(WS_normal),vec3(1.));
	float skylight = clamp(ambientCoefs.y + 0.5,0.25,2.0);

	vec2 lightmaps2 = lmtexcoord.zw;

	
	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240. + lightmaps2.y,2) ,0.0,1.0);

	AmbientLightColor += (lightningEffect * 10) * skylight * pow(lightmaps2.y,2);

	vec3 Indirect_lighting = DoAmbientLighting(AmbientLightColor, vec3(TORCH_R,TORCH_G,TORCH_B), lightmaps2, skylight);
	vec3 Direct_lighting = DoDirectLighting(DirectLightColor, Shadows, NdotL, 0.0);

	vec3 FinalColor = (Direct_lighting + Indirect_lighting) * Albedo;
	
	#ifdef Glass_Tint
		float alphashit = min(pow(gl_FragData[0].a,2.0),1.0);
		FinalColor *= alphashit;
	#endif

	#ifdef WATER_REFLECTIONS
		vec2 SpecularTex = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rg;
		
		SpecularTex = (iswater > 0.0 && iswater < 0.9) && SpecularTex.r > 0.0 && SpecularTex.g < 0.9 ? SpecularTex : vec2(1.0,0.1);
	
		float roughness = max(pow(1.0-SpecularTex.r,2.0),0.05);
		float f0 = SpecularTex.g;
	
		if (iswater > 0.0){
			vec3 Reflections_Final = vec3(0.0);
			vec4 Reflections = vec4(0.0);
			vec3 SkyReflection = vec3(0.0); 
			vec3 SunReflection = vec3(0.0);
	
			float indoors = clamp((lmtexcoord.w-0.6)*5.0, 0.0,1.0);
	
			vec3 reflectedVector = reflect(normalize(fragpos), normal);
			float normalDotEye = dot(normal, normalize(fragpos));
			float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 5.0);

			// snells window looking thing
			#ifdef PhysicsMod_support
				if(isEyeInWater == 1 && physics_iterationsNormal > 0.0) fresnel = clamp( 1.0 - (pow( normalDotEye * 1.66 ,25)),0.02,1.0);
			#else
				if(isEyeInWater == 1 ) fresnel = pow(clamp(1.66 + normalDotEye,0.0,1.0), 25.0);
			#endif

			fresnel = mix(f0, 1.0, fresnel); 
			
			vec3 wrefl = mat3(gbufferModelViewInverse)*reflectedVector;
	
			// SSR, Sky, and Sun reflections
			#ifdef WATER_BACKGROUND_SPECULAR
 				SkyReflection = skyCloudsFromTex(wrefl,colortex4).rgb / 30.0;
				if(isEyeInWater == 1) SkyReflection = vec3(0.0);
			#endif

			#ifdef WATER_SUN_SPECULAR
				SunReflection = Direct_lighting *  GGX(normal,  -normalize(fragpos),  lightSign*sunVec, roughness, vec3(f0)); 
			#endif
			#ifdef SCREENSPACE_REFLECTIONS
				if(iswater > 0.0){
					vec3 rtPos = rayTrace(reflectedVector,fragpos.xyz, interleaved_gradientNoise(), fresnel, isEyeInWater == 1);
					if (rtPos.z < 1.){
						vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
						previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
						previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
						if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
							Reflections.a = 1.0;
							Reflections.rgb = texture2D(colortex5,previousPosition.xy).rgb;
						}
					}
				}
			#endif

			float visibilityFactor = clamp(exp2((pow(roughness,3.0) / f0) * -4),0,1);

			Reflections_Final = mix(SkyReflection*indoors, Reflections.rgb, Reflections.a);
			Reflections_Final = mix(FinalColor, Reflections_Final, fresnel * visibilityFactor);
			Reflections_Final += SunReflection * lightleakfix;
			
			gl_FragData[0].rgb = Reflections_Final;
			
			//correct alpha channel with fresnel
			gl_FragData[0].a = mix(gl_FragData[0].a, 1.0, fresnel);
	
			if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.);
	
		} else {
			gl_FragData[0].rgb = FinalColor;
		}
	#else
		gl_FragData[0].rgb = FinalColor;
	#endif

	#ifndef HAND
		gl_FragData[1] = vec4(Albedo,iswater);
	#endif

	gl_FragData[3].a = max(lmtexcoord.w*blueNoise()*0.05 + lmtexcoord.w,0.0);
}
}