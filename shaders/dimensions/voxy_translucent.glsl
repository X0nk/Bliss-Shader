// THANK YOU SIXTHSURGE FOR ALLOWING USAGE OF PHOTON CODE TO BUILD THIS VOXY IMPLEMENTATION FROM: https://github.com/sixthsurge/photon
#define ANTIALIASING_RELATED_SETTINGS
#define VOLUMETRIC_CLOUD_RELATED_SETTINGS
#define SPECULAR_RELATED_SETTINGS
#define FORWARD_SPECULAR_RELATED_SETTINGS
#define AMBIENT_LIGHT_RELATED_SETTINGS
#define WATER_RELATED_SETTINGS
#include "/lib/settings.glsl"
// #include "/lib/macro_lod_mod.glsl"
#include "/lib/waterBump.glsl"
// #include "/lib/diffuseLighting.glsl"
#include "/lib/res_params.glsl"

// void readSceneControllerParameters(
// 	sampler2D colortex,
// 	out vec2 smallCumulus,
// 	out vec2 largeCumulus,
// 	out vec2 altostratus
// ){
//     // in colortex4, read the data stored within the 3 components of the sampled pixels, and pass it to the fragment stage
//     // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
// 	vec3 data1 = texelFetch(colortex,ivec2(1,3),0).rgb/150.0;
// 	vec3 data2 = texelFetch(colortex,ivec2(2,3),0).rgb/150.0;

// 	smallCumulus = vec2(data1.x,data1.y);
// 	largeCumulus = vec2(data1.z,data2.x);
// 	altostratus = vec2(data2.y,data2.z);
// };

// struct sceneController {
//   vec2 smallCumulus;
//   vec2 largeCumulus;
//   vec2 altostratus;
// } parameters;

// readSceneControllerParameters(colortex4, parameters.smallCumulus, parameters.largeCumulus, parameters.altostratus);

vec3 WsunVec = normalize((float(sunElevation > 1e-5)*2.0 - 1.0) * normalize(mat3(vxModelViewInv) * sunPosition));

// #define CLOUDSHADOWSONLY
// #include "/lib/volumetricClouds.glsl"

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
#define PI 3.141592653589793

uniform float LOD_NEARPLANE;
uniform float LOD_FARPLANE;
uniform int LOD_RENDERDISTANCE;


float DH_ld(float dist) {
    return (2.0 * LOD_NEARPLANE) / (LOD_FARPLANE + LOD_NEARPLANE - dist * (LOD_FARPLANE - LOD_NEARPLANE));
}

float DH_inv_ld(float lindepth){
	return -((2.0*LOD_NEARPLANE/lindepth)-LOD_FARPLANE-LOD_NEARPLANE)/(LOD_FARPLANE-LOD_NEARPLANE);
}

vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(vxProj, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(vxProjInv[0].x, vxProjInv[1].y, vxProjInv[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + vxProjInv[3];
    return fragposition.xyz / fragposition.w;
}

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = vxModelViewInv * pos;
    return pos.xyz;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = vxModelView * pos;
    return pos.xyz;
}

vec2 sphereToCarte(vec3 dir) {
    float lonlat = clamp(atan(-dir.x, -dir.z), -PI, PI);
    return vec2(lonlat * (0.5/PI) +0.5,	asin(dir.y)*(1.0/PI)+0.5);
}

vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}

vec4 skyCloudsFromTex(vec3 pos,sampler2D sampler){

	vec2 p = sphereToCarte(pos);
	vec2 uv = clamp(p, 0.0, 1.0) * texelSize*256. + vec2(18.5+257.,1.5)*texelSize;

	return texture2D(sampler, uv);
}

float GGX(vec3 n, vec3 v, vec3 l, float r, float f0) {
  r = max(pow(r,2.5), 0.0001);

  vec3 h = l + v;
  float hn = inversesqrt(dot(h, h));

  float dotLH = clamp(dot(h,l)*hn,0.,1.);
  float dotNH = clamp(dot(h,n)*hn,0.,1.) ;
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNHsq = dotNH*dotNH;

  float denom = dotNHsq * r - dotNHsq + 1.;
  float D = r / (PI * denom * denom);

  float F = f0 + (1. - f0) * exp2((-5.55473*dotLH-6.98316)*dotLH);
  float k2 = .25 * r;

  return dotNL * D * F / (dotLH*dotLH*(1.0-k2)+k2);
}

// vec3 doScreenSpaceReflectiom(vec3 dir, vec3 position, float dither, float quality){

// 	float biasAmount = 0.001;

// 	vec3 clipPosition = toClipSpace3(position);
// 	float rayLength = ((position.z + dir.z * LOD_FARPLANE*sqrt(3.)) > -LOD_NEARPLANE) ? (-LOD_NEARPLANE - position.z) / dir.z : LOD_FARPLANE*sqrt(3.);
	
// 	vec3 direction = toClipSpace3(position + dir*rayLength) - clipPosition;  //convert to clip space

// 	//get at which length the ray intersects with the edge of the screen
// 	vec3 maxLengths = (step(0.0, direction) - clipPosition) / direction;
// 	float mult = min(min(maxLengths.x, maxLengths.y), maxLengths.z);
// 	vec3 stepv = direction * mult / quality;

// 	clipPosition.xy *= RENDER_SCALE;
// 	stepv.xy *= RENDER_SCALE;

// 	vec3 spos = clipPosition + stepv*dither;
// 	spos.xy += texelSize*0.5;

// 	float minZ = spos.z - 0.00025 / DH_ld(spos.z);
// 	float maxZ = spos.z;
	
//   	for (int i = 0; i <= int(quality); i++) {

// 		if(spos.x < 0 || spos.x > 1 || spos.y < 0 || spos.y > 1) return vec3(1.1);

// 		float sampleDepth = sqrt(texelFetch(colortex12,ivec2(spos.xy/texelSize/4),0).a/65000.0);
// 		// float sampleDepth = DH_ld(texture2D(vxDepthTexOpaque, spos.xy).x);
// 		float sp = DH_inv_ld(sampleDepth);
		
// 		if(sp < max(minZ, maxZ) && sp > min(minZ, maxZ)) return vec3(spos.xy/RENDER_SCALE,sp);

// 		minZ = maxZ - biasAmount / DH_ld(spos.z);
// 		maxZ += stepv.z;

// 		spos += stepv;
//   	}
//   return direction;
// }

/*
struct VoxyFragmentParameters {
    vec4 sampledColour;
    vec2 tile;
    vec2 uv;
    uint face;
    uint modelId;
    vec2 lightMap;
    vec4 tinting;
    uint customId;//Same as iris's modelId
};
*/

layout(location = 0) out vec4 FORWARD_RENDERED_COLOR;
layout(location = 1) out vec4 TINT_AND_MASK;
layout(location = 2) out vec4 WRITE_DEPTH;

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    FORWARD_RENDERED_COLOR.rgba = vec4(0.0);
    
    // masks
    float material = 0.7;
    bool isWater = parameters.customId == 8;
    if(isWater) material = 1.0;
    
    // positions
    vec2 texcoord = gl_FragCoord.xy*texelSize;
    vec3 viewPos = toScreenSpace(vec3(texcoord, gl_FragCoord.z));
    vec3 playerPos = (mat3(vxModelViewInv) * viewPos + vxModelViewInv[3].xyz);

    // directions
    vec3 normal = vec3( uint((parameters.face >> 1) == 2), uint((parameters.face >> 1) == 0), uint((parameters.face >> 1) == 1) ) * (float(int(parameters.face) & 1) * 2.0 - 1.0);

    if(isWater && abs(normal.y) > 0.1){
	    vec3 waterPos = playerPos+cameraPosition;

		vec3 bump = normalize(getWaveNormal(waterPos.xzy, playerPos, false));
		float bumpmult = WATER_WAVE_STRENGTH;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);

        normal.xz = clamp(bump.xy,-0.1,0.1);
    }

    normal = normalize(normal);
    vec3 viewSpaceNormals = worldToView(normal);

    // colors
    vec4 Albedo = parameters.sampledColour * parameters.tinting;

    if(isWater) {
        Albedo = vec4(0.0);
        FORWARD_RENDERED_COLOR.a = 0.0;
    }

    TINT_AND_MASK.rgba = vec4(Albedo.rgb, material);
    Albedo.rgb = toLinear(Albedo.rgb);

    vec3 Direct_lighting = vec3(1.0);
    vec3 Indirect_lighting = vec3(1.0);
	vec3 DirectLightColor = vec3(0.0);
    vec3 AmbientLightColor = vec3(0.0);

    // diffuse lighting
    #ifdef OVERWORLD_SHADER
        // direct
	    DirectLightColor = texelFetch(colortex4, ivec2(6,37),0).rgb / 2400.0;

    	float NdotL = clamp(dot(normal, WsunVec),0.0,1.0); 
        NdotL = clamp((-15 + NdotL*255.0) / 240.0  ,0.0,1.0);

        float Shadows = 1.0;
		// Shadows *= GetCloudShadow(playerPos + cameraPosition, WsunVec);

    	Direct_lighting = DirectLightColor * NdotL * Shadows;
        
        // indirect
        AmbientLightColor = texelFetch(colortex4, ivec2(0,37),0).rgb / 900.0;

		vec3 indirectNormal = normal.xyz / dot(abs(normal.xyz),vec3(1.0));
		float indirect_NdotL = clamp(indirectNormal.y*0.7+0.3,0.0,1.0);
		indirect_NdotL = mix(0.08, 1.0, indirect_NdotL);

    	Indirect_lighting = AmbientLightColor * indirect_NdotL;
    #endif
    
    // combinar
	vec3 FinalColor = (Indirect_lighting + Direct_lighting) * Albedo.rgb;

    // specular lighting
	#ifdef FORWARD_SPECULAR
	    vec4 Reflections = vec4(0.0);
        float roughness = 0.0;
	    float f0 = 0.02;

        vec3 reflectedVector = reflect(normalize(viewPos), viewSpaceNormals);
	    float normalDotEye = dot(viewSpaceNormals, normalize(viewPos));

	    float fresnel =  pow(clamp(1.0 + normalDotEye, 0.0, 1.0),5.0);
	    fresnel = mix(f0, 1.0, fresnel);

        // #if FORWARD_SSR_QUALITY > 0 && defined DH_SCREENSPACE_REFLECTIONS
            // vec3 rtPos = doScreenSpaceReflectiom(reflectedVector, viewPos, 1.0, 30.0f);
            // Reflections.rgb = rtPos;
            // if (rtPos.z < 0.99999){
            	// vec3 previousPosition = mat3(vxModelViewInv) * toScreenSpace(rtPos) + vxModelViewInv[3].xyz + cameraPosition-previousCameraPosition;
            	// previousPosition = mat3(vxModelViewPrev) * previousPosition + vxModelViewPrev[3].xyz;
            	// previousPosition.xy = projMAD(vxProjPrev, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
            	// if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.y < 1.0) {
	    			// Reflections.a = 1.0;
	    			// Reflections.rgb = texture2D(colortex5, rtPos.xy).rgb;
            	// }
            // }
	    		// if (rtPos.x > 0.0 && rtPos.y > 0.0 && rtPos.x < 1.0 && rtPos.y < 1.0) SSR_HIT_SKY_MASK = 1.0;
	    	// }
        // #endif

	    #if defined FORWARD_BACKGROUND_REFLECTION
	        Reflections.rgb = mix(FinalColor, skyCloudsFromTex(mat3(vxModelViewInv) * reflectedVector, colortex4).rgb / 1200.0, fresnel);
        #endif

	    #if defined OVERWORLD_SHADER || SUN_SPECULAR_MULT > 0
            Reflections.rgb += (DirectLightColor * Shadows) * GGX(normal, -normalize(playerPos), WsunVec, roughness, f0);
        #endif

        FORWARD_RENDERED_COLOR.a = FORWARD_RENDERED_COLOR.a + (1.0-FORWARD_RENDERED_COLOR.a) * fresnel;
	    FORWARD_RENDERED_COLOR.rgb = clamp(Reflections.rgb / FORWARD_RENDERED_COLOR.a * 0.1, 0.0, 65000.0);
    #else
        FORWARD_RENDERED_COLOR.rgba = vec4(FinalColor.rgb*0.1, FORWARD_RENDERED_COLOR.a);
    #endif
    #if DEBUG_VIEW == debug_NORMALS
		FORWARD_RENDERED_COLOR.rgb = normal.xyz * 0.1;
		FORWARD_RENDERED_COLOR.a = 1.0;
	#endif
}