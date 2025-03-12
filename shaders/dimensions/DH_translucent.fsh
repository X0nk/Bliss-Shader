#include "/lib/settings.glsl"
#include "/lib/util.glsl"
#include "/lib/res_params.glsl"
#include "/lib/color_transforms.glsl"
#include "/lib/projections.glsl"

uniform vec2 texelSize;
// uniform int moonPhase;
uniform float frameTimeCounter;
uniform sampler2D noisetex;

const bool shadowHardwareFiltering = true;
uniform sampler2DShadow shadow;

#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

uniform sampler2D colortex12;
// uniform sampler2D colortex7;
uniform sampler2D colortex4;
uniform sampler2D colortex5;


#include "/lib/sky_gradient.glsl"
#include "/lib/waterBump.glsl"
#include "/lib/Shadow_Params.glsl"

varying vec4 pos;
varying vec4 gcolor;

varying vec4 normals_and_materials;

varying vec2 lightmapCoords;

flat varying int isWater;

// uniform float far;
uniform float dhFarPlane;
uniform float dhNearPlane;

uniform vec3 previousCameraPosition;
// uniform vec3 cameraPosition;

// uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;

// uniform mat4 shadowModelView;
// uniform mat4 shadowModelViewInverse;
// uniform mat4 shadowProjection;
// uniform mat4 shadowProjectionInverse;



uniform int frameCounter;


// uniform sampler2D colortex4;
flat varying vec3 averageSkyCol_Clouds;
flat varying vec4 lightCol;
flat varying vec3 WsunVec;
flat varying vec3 WsunVec2;



// uniform mat4 dhPreviousProjection;
// uniform mat4 dhProjectionInverse;
// uniform mat4 dhProjection;



#include "/lib/DistantHorizons_projections.glsl"

vec3 DH_toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

vec3 DH_toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(dhProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}
uniform float near;
float invLinZ (float lindepth){
	return -((2.0*near/lindepth)-far-near)/(far-near);
}
float ld(float dist) {
    return (2.0 * near) / (far + near - dist * (far - near));
}

// float DH_ld(float dist) {
//     return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
// }
// float DH_invLinZ (float lindepth){
// 	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
// }

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}

float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}




uniform int isEyeInWater;
uniform float rainStrength;

#ifdef OVERWORLD_SHADER
	#define CLOUDSHADOWSONLY
	#include "/lib/volumetricClouds.glsl"
#endif

float GGX(vec3 n, vec3 v, vec3 l, float r, float f0) {
  r = max(pow(r,2.5), 0.0001);

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (3.141592653589793 * denom * denom);

  float F = f0 + (1. - f0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}

uniform int framemod8;

#include "/lib/TAA_jitter.glsl"



// float DH_ld(float dist) {
//     return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
// }
// float DH_invLinZ (float lindepth){
// 	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
// }

// float linearizeDepthFast(const in float depth, const in float near, const in float far) {
//     return (near * far) / (depth * (near - far) + far);
// }

// uniform float far;

vec3 rayTrace(vec3 dir, vec3 position,float dither, float fresnel, bool inwater){

    float quality = mix(5,SSR_STEPS,fresnel);
    vec3 clipPosition = DH_toClipSpace3(position);
	float rayLength = ((position.z + dir.z * dhFarPlane*sqrt(3.)) > -dhNearPlane) ?
       (-dhNearPlane - position.z) / dir.z : dhFarPlane*sqrt(3.);
    vec3 direction = normalize(DH_toClipSpace3(position+dir*rayLength)-clipPosition);  //convert to clip space
    direction.xy = normalize(direction.xy);

    //get at which length the ray intersects with the edge of the screen
    vec3 maxLengths = (step(0.,direction)-clipPosition) / direction;
    float mult = min(min(maxLengths.x,maxLengths.y),maxLengths.z);


    vec3 stepv = direction * mult / quality * vec3(RENDER_SCALE,1.0);


	vec3 spos = clipPosition*vec3(RENDER_SCALE,1.0) + stepv*dither;
	float minZ = clipPosition.z;
	float maxZ = spos.z+stepv.z*0.5;
	
	spos.xy += offsets[framemod8]*texelSize*0.5/RENDER_SCALE;

    for (int i = 0; i <= int(quality); i++) {

		// float sp = DH_inv_ld(sqrt(texelFetch2D(colortex12,ivec2(spos.xy/texelSize/4),0).a/65000.0));
		float sp = DH_inv_ld(sqrt(texelFetch2D(colortex12,ivec2(spos.xy/texelSize/4),0).a/64000.0));

        if(sp <= max(maxZ,minZ) && sp >= min(maxZ,minZ)) return vec3(spos.xy/RENDER_SCALE,sp);

        spos += stepv;

		//small bias
		minZ = maxZ-0.0000035/DH_ld(spos.z);

		maxZ += stepv.z;
    }

    return vec3(1.1);
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	float noise = fract( 52.9829189 * fract( (coord.x * 0.06711056) + (coord.y * 0.00583715) ) );
	return noise ;
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
vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
	float bumpmult = puddle_values;
	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	// 
	return normalize(bump*tbnMatrix);
}


/* RENDERTARGETS:2,7 */
void main() {
if (gl_FragCoord.x * texelSize.x < 1.0  && gl_FragCoord.y * texelSize.y < 1.0 )	{
   
    bool iswater = isWater > 0;
   
    float material = 0.7;
    if(iswater) material = 1.0;

    vec3 normals = normals_and_materials.xyz;
    vec3 viewPos = pos.xyz;
    vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
    float transition = exp(-25* pow(clamp(1.0 - length(playerPos)/(far-8),0.0,1.0),2));

    #ifdef DH_OVERDRAW_PREVENTION
		#if OVERDRAW_MAX_DISTANCE == 0
			float maxOverdrawDistance = far;
		#else
			float maxOverdrawDistance = OVERDRAW_MAX_DISTANCE;
		#endif

        if(length(playerPos) < clamp(far-16*4, 16, maxOverdrawDistance) ){ discard; return;}
    #endif

    if(iswater && abs(normals.y) > 0.0){
	    vec3 posxz = playerPos+cameraPosition;

		vec3 bump = normalize(getWaveNormal(posxz, true));

		float bumpmult = 10.0 * WATER_WAVE_STRENGTH;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

        normals.xz = bump.xy;
    }
    
    normals = worldToView(normals);

    gl_FragData[0] = gcolor;
    // float UnchangedAlpha = gl_FragData[0].a;

	#ifdef WhiteWorld
		gl_FragData[0].rgb = vec3(0.5);
		gl_FragData[0].a = 1.0;
	#endif
    
	vec3 Albedo = toLinear(gl_FragData[0].rgb);

	#ifndef WhiteWorld
	    #ifndef Vanilla_like_water
	    	if (iswater){
	    		Albedo = vec3(0.0);
	    		gl_FragData[0].a = 1.0/255.0;
	    	}
        #endif
    #endif

    // diffuse
	vec3 Indirect_lighting = vec3(0.0);
	// vec3 MinimumLightColor = vec3(1.0);
	// if(isEyeInWater == 1) MinimumLightColor = vec3(10.0);
	vec3 Direct_lighting = vec3(0.0);

    #ifdef OVERWORLD_SHADER
		vec3 DirectLightColor = lightCol.rgb/80.0;

    	float NdotL = clamp(dot(normals, normalize(WsunVec2)),0.0,1.0); 
        NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);

        float Shadows = 1.0;

        #ifdef DISTANT_HORIZONS_SHADOWMAP
    	    vec3 feetPlayerPos_shadow = mat3(gbufferModelViewInverse) * pos.xyz + gbufferModelViewInverse[3].xyz;

    	    vec3 projectedShadowPosition = mat3(shadowModelView) * feetPlayerPos_shadow  + shadowModelView[3].xyz;
    	    projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

    	    //apply distortion
    	    #ifdef DISTORT_SHADOWMAP
    	        float distortFactor = calcDistort(projectedShadowPosition.xy);
    	    	projectedShadowPosition.xy *= distortFactor;
    	    #else
    	    	float distortFactor = 1.0;
    	    #endif

    	    float smallbias = -0.0035;

    	    bool ShadowBounds = abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.z) < 6.0;

    	    if(ShadowBounds){
    	    	Shadows = 0.0;
    	    	projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5);

    	    	Shadows = shadow2D(shadow, projectedShadowPosition + vec3(0.0,0.0, smallbias)).x;
    	    }
        #endif
        #ifdef CLOUDS_SHADOWS
    		Shadows *= pow(GetCloudShadow(playerPos),3);
        #endif

    	Direct_lighting = DirectLightColor * NdotL * Shadows;

    	vec3 AmbientLightColor = averageSkyCol_Clouds/30.0;

    	vec3 ambientcoefs = normals_and_materials.xyz / dot(abs(normals_and_materials.xyz), vec3(1.0));
    	float SkylightDir = ambientcoefs.y*1.5;
    
    	float skylight = max(pow(viewToWorld(normals_and_materials.xyz).y*0.5+0.5,0.1) + SkylightDir, 0.2);
    	AmbientLightColor *= skylight;
    #endif
	
    #ifndef OVERWORLD_SHADER
		vec3 AmbientLightColor = vec3(0.5);
	#endif

    Indirect_lighting = AmbientLightColor;

	vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo;

    // specular
    #ifdef WATER_REFLECTIONS
		vec3 Reflections_Final = vec3(0.0);
		vec4 Reflections = vec4(0.0);
		vec3 BackgroundReflection = FinalColor; 
		vec3 SunReflection = vec3(0.0);
		
        float roughness = 0.035;
		float f0 = 0.02;
		// f0 = 0.9;

        vec3 reflectedVector = reflect(normalize(viewPos), normals);
	    float normalDotEye = dot(normals, normalize(viewPos));

	    float fresnel =  pow(clamp(1.0 + normalDotEye, 0.0, 1.0),5.0);

	    fresnel = mix(f0, 1.0, fresnel);

        #ifdef SNELLS_WINDOW
	    	if(isEyeInWater == 1) fresnel = pow(clamp(1.5 + normalDotEye,0.0,1.0), 25.0);
	    #endif
        #if defined SCREENSPACE_REFLECTIONS && defined DH_SCREENSPACE_REFLECTIONS
            vec3 rtPos = rayTrace(reflectedVector, viewPos, interleaved_gradientNoise(), fresnel, false);
            if (rtPos.z < 1.){
            	vec3 previousPosition = mat3(gbufferModelViewInverse) * DH_toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
            	previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
            	previousPosition.xy = projMAD(dhPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
            	if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
            		Reflections.a = 1.0;
            		Reflections.rgb = texture2D(colortex5, previousPosition.xy).rgb;
            	}
            }
        #endif
		#ifdef WATER_BACKGROUND_SPECULAR
            BackgroundReflection = skyCloudsFromTex(mat3(gbufferModelViewInverse) * reflectedVector, colortex4).rgb / 30.0; 
        #endif
        #ifdef WATER_SUN_SPECULAR
            SunReflection = Direct_lighting * GGX(normalize(normals), -normalize(viewPos), normalize(WsunVec2), roughness, f0) * (1.0-Reflections.a);
        #endif

		Reflections_Final = mix(BackgroundReflection, Reflections.rgb, Reflections.a) * fresnel;
		Reflections_Final += SunReflection;

		//correct alpha channel with fresnel
		float alpha0 = gl_FragData[0].a;

		gl_FragData[0].a = -gl_FragData[0].a * fresnel + gl_FragData[0].a + fresnel;

		// prevent reflections from being darkened by buffer blending
		gl_FragData[0].rgb = clamp(FinalColor / gl_FragData[0].a*alpha0*(1.0-fresnel) * 0.1		+	Reflections_Final / gl_FragData[0].a * 0.1,0.0,65100.0);

		if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.0);
	#else
		gl_FragData[0].rgb = FinalColor*0.1;
	#endif
    
    #ifdef DH_OVERDRAW_PREVENTION
        float distancefade = min(max(1.0 - length(playerPos)/clamp(far-16*4, 16, maxOverdrawDistance),0.0)*5,1.0);

        if(texture2D(depthtex0, gl_FragCoord.xy*texelSize).x < 1.0 ||  distancefade > 0.0){
            gl_FragData[0].a = 0.0;
            material = 0.0;
        }
    #endif
	
    #if DEBUG_VIEW == debug_DH_WATER_BLENDING
        if(gl_FragCoord.x*texelSize.x > 0.53) gl_FragData[0] = vec4(0.0);
    #endif

    gl_FragData[1] = vec4(Albedo, material);
}
}