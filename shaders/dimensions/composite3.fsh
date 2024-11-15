#include "/lib/settings.glsl"

flat varying vec3 zMults;

flat varying vec2 TAA_Offset;
flat varying vec3 WsunVec;

#ifdef OVERWORLD_SHADER
  flat varying vec3 skyGroundColor;
#endif

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

	// const bool colortex4MipmapEnabled = true;
#ifdef DISTANT_HORIZONS
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;
#endif

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex15;
uniform vec2 texelSize;

uniform sampler2D colortex4;
uniform float viewHeight;
uniform float viewWidth;
uniform float nightVision;
uniform vec3 sunVec;
uniform float frameTimeCounter;
uniform int frameCounter;
uniform float far;
uniform float near;
uniform float farPlane;
uniform float dhNearPlane;
uniform float dhFarPlane;

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;

uniform int hideGUI;
uniform int dhRenderDistance;
uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;
uniform float caveDetection;

#include "/lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#ifdef OVERWORLD_SHADER
  #include "/lib/climate_settings.glsl"
#endif

#include "/lib/sky_gradient.glsl"

uniform float eyeAltitude;


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

float ld(float depth) {
    return 1.0 / (zMults.y - depth * zMults.z);		// (-depth * (far - near)) = (2.0 * near)/ld - far - near
}
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}
vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 playerPos = p * 2. - 1.;
    vec4 fragposition = iProjDiag * playerPos.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"


float interleaved_gradientNoise_temporal(){
	#ifdef TAA
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y ) + 1.0/1.6180339887);
	#endif
}
float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy ;

	#ifdef TAA
		coord +=  (frameCounter%40000) * 2.0;
	#endif
	
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}
float blueNoise(){
	#ifdef TAA
  		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
	#else
		return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887);
	#endif
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord)%512 , 0) ;
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}
float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
vec4 BilateralUpscale(sampler2D tex, sampler2D tex2, sampler2D depth, vec2 coord, float referenceDepth, inout float CLOUDALPHA){
	ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth  = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor  = ivec2(coord*VL_RENDER_RESOLUTION);
 	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[5] = ivec2[](
    ivec2(-1,-1),
	 	ivec2( 1, 1),
		ivec2(-1, 1),
		ivec2( 1,-1),
		ivec2( 0, 0)
  );

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.01;
	#else
		float diffThreshold = zMults.x;
	#endif

	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 5; i++) {
		
		ivec2 radius = getRadius[i];

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;

    #if defined OVERWORLD_SHADER && defined CLOUDS_INTERSECT_TERRAIN
	    CLOUDALPHA += texelFetch2D(tex2, posColor + radius + pos, 0).x * EDGES;
    #endif
		
    SUM += EDGES;
	}

  #if defined OVERWORLD_SHADER && defined CLOUDS_INTERSECT_TERRAIN
   CLOUDALPHA = CLOUDALPHA / SUM;
  #endif

	return RESULT / SUM;
}

vec3 decode (vec2 encn){
    vec3 n = vec3(0.0);
    encn = encn * 2.0 - 1.0;
    n.xy = abs(encn);
    n.z = 1.0 - n.x - n.y;
    n.xy = n.z <= 0.0 ? (1.0 - n.yx) * sign(encn) : encn;
    return clamp(normalize(n.xyz),-1.0,1.0);
}


vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
vec3 viewToWorld(vec3 viewPosition) {
    vec4 pos;
    pos.xyz = viewPosition;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

/// thanks stackoverflow https://stackoverflow.com/questions/944713/help-with-pixel-shader-effect-for-brightness-and-contrast#3027595
void applyContrast(inout vec3 color, float contrast){
  color = ((color - 0.5) * max(contrast, 0.0)) + 0.5;
}

void ApplyDistortion(inout vec2 Texcoord, vec2 TangentNormals, float lineardistance, bool isTranslucentEntity){

  vec2 UnalteredTexcoord = Texcoord;
  
  float refractionStrength = isTranslucentEntity ? 0.25 : 1.0 ;

  // Texcoord = abs(Texcoord + (TangentNormals * clamp((ld(depths.x) - ld(depths.y)) * 0.5,0.0,0.15)) * RENDER_SCALE * refractionStrength );
  // Texcoord = abs(Texcoord + (TangentNormals * mix(0.01, 0.1, pow(clamp(1.0-lineardistance/(32*4),0.0,1.0),2))) * RENDER_SCALE * refractionStrength );
  Texcoord = abs(Texcoord + TangentNormals * RENDER_SCALE * 0.1 );

  float DistortedAlpha = decodeVec2(texture2D(colortex11,Texcoord).b).g;
  // float DistortedAlpha = decodeVec2(texelFetch2D(colortex11,ivec2(Texcoord/texelSize),0).b).g;
  // float DistortedAlpha = texelFetch2D(colortex2,ivec2(Texcoord/texelSize),0).a;
  
  Texcoord = mix(Texcoord, UnalteredTexcoord,  min(max(0.1-DistortedAlpha,0.0) * 1000.0,1.0)); // remove distortion on non-translucents
}

vec3 doRefractionEffect( inout vec2 texcoord, vec2 normal, float linearDistance){
  
  // make the tangent space normals match the directions of the texcoord UV, this greatly improves the refraction effect.
  vec2 UVNormal = vec2(normal.x,-normal.y);
  
  float refractionMult = 0.3 / (1.0 + linearDistance);
  float diffractionMult = 0.035;
  float smudgeMult = 1.0;

  // for diffraction, i wanted to know *when* normals were at an angle, not what the
  float clampValue = 0.2;
  vec2 abberationOffset = (clamp(UVNormal,-clampValue, clampValue)/clampValue) * diffractionMult;

  // return vec3(abs(abberationOffset), 0.0);

  #ifdef REFRACTION_SMUDGE
    vec2 directionalSmudge = abberationOffset * (blueNoise()-0.5) * smudgeMult;
  #else
    vec2 directionalSmudge = vec2(0.0);
  #endif
  
  vec2 refractedUV = texcoord - (UVNormal + directionalSmudge)*refractionMult;
  
  // a max bound around screen edges and edges of the refracted screen
  vec2 vignetteSides = clamp(min((1.0 - refractedUV)/0.05, refractedUV/0.05)+0.5,0.0,1.0);
  float vignette = vignetteSides.x*vignetteSides.y;

  refractionMult *= decodeVec2(texelFetch2D(colortex11, ivec2(refractedUV/texelSize),0).b).g > 0.0 ? 1.0 : 0.0;

  vec3 color = vec3(0.0);

  #ifdef FAKE_DISPERSION_EFFECT
    //// RED
    refractedUV = clamp(texcoord - ((UVNormal + abberationOffset) + directionalSmudge)*refractionMult ,0.0,1.0);
    color.r = texelFetch2D(colortex3, ivec2(refractedUV/texelSize),0).r;
    //// GREEN
    refractedUV = clamp(texcoord - (UVNormal + directionalSmudge)*refractionMult ,0,1);
    color.g = texelFetch2D(colortex3, ivec2(refractedUV/texelSize),0).g;
    //// BLUE
    refractedUV = clamp(texcoord - ((UVNormal - abberationOffset) + directionalSmudge)*refractionMult ,0.0,1.0);
    color.b = texelFetch2D(colortex3, ivec2(refractedUV/texelSize),0).b;
  
  #else
    refractedUV = clamp(texcoord - UVNormal,0.0,1.0);
    color = texture2D(colortex3, refractedUV).rgb;
  #endif

  // texcoord = texcoord - (UVNormal+directionalSmudge)*refractionMult*vignette;
  return color;
}

vec3 toClipSpace3Prev(vec3 viewSpacePosition) {
    return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}

vec3 closestToCamera5taps(vec2 texcoord, sampler2D depth)
{
	vec2 du = vec2(texelSize.x*2., 0.0);
	vec2 dv = vec2(0.0, texelSize.y*2.);

	vec3 dtl = vec3(texcoord,0.) + vec3(-texelSize, 				texture2D(depth, texcoord - dv - du).x);
	vec3 dtr = vec3(texcoord,0.) + vec3( texelSize.x, -texelSize.y, texture2D(depth, texcoord - dv + du).x);
	vec3 dmc = vec3(texcoord,0.) + vec3( 0.0, 0.0, 					texture2D(depth, texcoord).x);
	vec3 dbl = vec3(texcoord,0.) + vec3(-texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv - du).x);
	vec3 dbr = vec3(texcoord,0.) + vec3( texelSize.x, texelSize.y, 	texture2D(depth, texcoord + dv + du).x);

	vec3 dmin = dmc;
	dmin = dmin.z > dtr.z ? dtr : dmin;
	dmin = dmin.z > dtl.z ? dtl : dmin;
	dmin = dmin.z > dbl.z ? dbl : dmin;
	dmin = dmin.z > dbr.z ? dbr : dmin;
	
	#ifdef TAA_UPSCALING
		dmin.xy = dmin.xy/RENDER_SCALE;
	#endif

	return dmin;
}

vec3 toClipSpace3Prev_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef DISTANT_HORIZONS
		mat4 projectionMatrix = depthCheck ? dhPreviousProjection : gbufferPreviousProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferPreviousProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif
}

vec3 toScreenSpace_DH_special(vec3 POS, bool depthCheck ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);

	#ifdef DISTANT_HORIZONS
    	if (depthCheck) {
			iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
			viewPos.xyz /= viewPos.w;

		} else {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = POS * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
			
	#ifdef DISTANT_HORIZONS
		}
	#endif

    return viewPos.xyz;
}
vec3 tonemap(vec3 col){
	return col/(1+luma(col));
}
vec3 invTonemap(vec3 col){
	return col/(1-luma(col));
}

vec4 VLTemporalFiltering(vec3 viewPos, bool depthCheck, out float DEBUG){
  vec2 texcoord = ((gl_FragCoord.xy)*2.0 + 0.5)*texelSize/2.0;

  vec2 VLtexCoord = texcoord * VL_RENDER_RESOLUTION;

	// vec3 closestToCamera = closestToCamera5taps(texcoord, depthtex0);
	// vec3 viewPos_5tap = toScreenSpace(closestToCamera);

	// get previous frames position stuff for UV
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz + (cameraPosition - previousCameraPosition);
	vec3 previousPosition = mat3(gbufferPreviousModelView) * playerPos + gbufferPreviousModelView[3].xyz;
	previousPosition = toClipSpace3Prev(previousPosition);

	vec2 velocity = previousPosition.xy - texcoord/RENDER_SCALE;
	previousPosition.xy = texcoord + velocity;

  // vec4 currentFrame = texture2D_bicubic(colortex0, VLtexCoord);
  vec4 currentFrame = texture2D(colortex0, VLtexCoord );
  // vec4 currentFrame = texelFetch2D(colortex0, ivec2(VLtexCoord/texelSize),0);

  if (previousPosition.x < 0.0 || previousPosition.y < 0.0 || previousPosition.x > 1.0 || previousPosition.y > 1.0) return currentFrame;
  
	vec4 col1 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  texelSize.y));
	vec4 col2 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x, -texelSize.y));
	vec4 col3 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x, -texelSize.y));
	vec4 col4 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  texelSize.y));
	vec4 col5 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			    texelSize.y));
	vec4 col6 = texture2D(colortex0, VLtexCoord + vec2( 0.0,			   -texelSize.y));
	vec4 col7 = texture2D(colortex0, VLtexCoord + vec2(-texelSize.x,  		    0.0));
	vec4 col8 = texture2D(colortex0, VLtexCoord + vec2( texelSize.x,  		    0.0));

	vec4 colMax = max(currentFrame,max(col1,max(col2,max(col3, max(col4, max(col5, max(col6, max(col7, col8))))))));
	vec4 colMin = min(currentFrame,min(col1,min(col2,min(col3, min(col4, min(col5, min(col6, min(col7, col8))))))));
	
  // colMin = 0.5 * (colMin + min(currentFrame,min(col5,min(col6,min(col7,col8)))));
  // colMax = 0.5 * (colMax + max(currentFrame,max(col5,max(col6,max(col7,col8)))));

  // vec4 col0 = texture(colortex0, VLtexCoord + vec2( texelSize.x,	 		 0.0));
  // vec4 col1 = texture(colortex0, VLtexCoord + vec2( 0.0,			 texelSize.y));
  // vec4 col2 = texture(colortex0, VLtexCoord + vec2(-texelSize.x,	 		 0.0));
  // vec4 col3 = texture(colortex0, VLtexCoord + vec2( 0.0,			-texelSize.y));

  // vec4 colMin = min(currentFrame, min(col0, min(col1, min(col2, col3))));
  // vec4 colMax = max(currentFrame, max(col0, max(col1, max(col2, col3))));

  vec4 frameHistory = texture2D(colortex10, previousPosition.xy);
  vec4 clampedFrameHistory = clamp(frameHistory, colMin, colMax);
  
  float blendingFactor = 0.1;
	// if((min(max(clampedFrameHistory.a - frameHistory.a,0.0) / 0.0000001, 1.0)) > 0.0) blendingFactor = 1.0;
  
	// if(abs(clampedFrameHistory.a-frameHistory.a) > 0.1 && abs(currentFrame.a-frameHistory.a) > 0.1) blendingFactor = 1.0;

  // if(abs(currentFrame.a - frameHistory.a) > 0.6) blendingFactor = 1.0;
  if(abs(clampedFrameHistory.a  - frameHistory.a) > 0.1) blendingFactor = 1.0;
  // blendingFactor = clamp(blendingFactor + abs(clampedFrameHistory.a - frameHistory.a),0.0,1.0);

  // DEBUG = abs(clampedFrameHistory.a - frameHistory.a) > 0.1 ? 0. : 1.0;
  // DEBUG = clamp(abs(clampedFrameHistory.a - frameHistory.a),0.0,1.0);
  
  return clamp(mix(clampedFrameHistory, currentFrame, blendingFactor),0.0,65000.0);
}

void main() {
  /* RENDERTARGETS:7,3,10 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;

  float z = texture2D(depthtex0, texcoord).x;
  float z2 = texture2D(depthtex1, texcoord).x;
  float frDepth = ld(z);

	float swappedDepth = z;

	#ifdef DISTANT_HORIZONS
    float DH_depth0 = texture2D(dhDepthTex,texcoord).x;
		float depthOpaque = z;
		float depthOpaqueL = linearizeDepthFast(depthOpaque, near, farPlane);
		
		float dhDepthOpaque = DH_depth0;
		float dhDepthOpaqueL = linearizeDepthFast(dhDepthOpaque, dhNearPlane, dhFarPlane);
	  if (depthOpaque >= 1.0 || (dhDepthOpaqueL < depthOpaqueL && dhDepthOpaque > 0.0)){
		  depthOpaque = dhDepthOpaque;
		  depthOpaqueL = dhDepthOpaqueL;
		}

		swappedDepth = depthOpaque;

	#else
		float DH_depth0 = 0.0;
	#endif

	vec3 viewPos = toScreenSpace_DH(texcoord/RENDER_SCALE, z, DH_depth0);
	vec3 playerPos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
	vec3 playerPos_normalized = normVec(playerPos);
	vec3 playerPos222 = mat3(gbufferModelViewInverse) * toScreenSpace_DH(texcoord/RENDER_SCALE, 1.0,1.0) + gbufferModelViewInverse[3].xyz ;

  float linearDistance = length(playerPos);
  float linearDistance_cylinder = length(playerPos.xz);

	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	float lightleakfixfast = clamp(eyeBrightness.y/240.,0.0,1.0);

	////// --------------- UNPACK OPAQUE GBUFFERS --------------- //////
	// float opaqueMasks = decodeVec2(texture2D(colortex1,texcoord).a).y;
	// bool isOpaque_entity = abs(opaqueMasks-0.45) < 0.01;

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec4 data = texelFetch2D(colortex11,ivec2(texcoord/texelSize),0).rgba;
	vec4 unpack0 = vec4(decodeVec2(data.r),decodeVec2(data.g)) ;
	vec4 unpack1 = vec4(decodeVec2(data.b),0,0) ;
	
	vec4 albedo = vec4(unpack0.ba,unpack1.rg);
	vec2 tangentNormals = unpack0.xy*2.0-1.0;
  if(albedo.a < 0.01) tangentNormals = vec2(0.0);


	////// --------------- UNPACK MISC --------------- //////
	// 1.0 = water mask
	// 0.9 = entity mask
	// 0.8 = reflective entities
	// 0.7 = reflective blocks
  float translucentMasks = texture2D(colortex7, texcoord).a;

	bool isWater = translucentMasks > 0.99;
	bool isReflectiveEntity = abs(translucentMasks - 0.8) < 0.01;
	bool isReflective = abs(translucentMasks - 0.7) < 0.01 || isWater || isReflectiveEntity;
	bool isEntity = abs(translucentMasks - 0.9) < 0.01 || isReflectiveEntity;

  ////// --------------- get volumetrics


  #if defined OVERWORLD_SHADER && defined CLOUDS_INTERSECT_TERRAIN 
    float cloudAlpha = 0.0;
  #else
    float cloudAlpha = 1.0;
  #endif
  float DEBUG = 0.0;
  vec4 temporallyFilteredVL = VLTemporalFiltering(viewPos, z >= 1.0,DEBUG);
  gl_FragData[2] = temporallyFilteredVL;
  
  // #ifdef DISTANT_HORIZONS
  //   vec4 vl = BilateralUpscale(colortex0, colortex14, colortex12, gl_FragCoord.xy - 1.5, sqrt(texture2D(colortex12,texcoord).a/65000.0), cloudAlpha);
  // #else
  //   vec4 vl = BilateralUpscale(colortex0, colortex14, depthtex0, gl_FragCoord.xy - 1.5, frDepth,cloudAlpha);
  // #endif
  // vec4 temporallyFilteredVL = vl;

  // vec4 temporallyFilteredVL = texture2D(colortex10, texcoord*VL_RENDER_RESOLUTION);


  float bloomyFogMult = 1.0;

  ////// --------------- distort texcoords as a refraction effect
  vec2 refractedCoord = texcoord;

  ////// --------------- MAIN COLOR BUFFER
  #ifdef FAKE_REFRACTION_EFFECT
    // ApplyDistortion(refractedCoord, tangentNormals, linearDistance, isEntity);
    // vec3 color = texture2D(colortex3, refractedCoord).rgb;
    vec3 color = doRefractionEffect(refractedCoord, tangentNormals.xy, linearDistance);
  #else
    // vec3 color = texture2D(colortex3, refractedCoord).rgb;
    vec3 color = texelFetch2D(colortex3, ivec2(refractedCoord/texelSize),0).rgb;
  #endif
  vec4 TranslucentShader = texture2D(colortex2, texcoord);
  // color = vec3(texcoord-0.5,0.0) * mat3(gbufferModelViewInverse);
  // apply block breaking effect.
  if(albedo.a > 0.01 && !isWater && TranslucentShader.a <= 0.0 && !isEntity) color = mix(color*6.0, color, luma(albedo.rgb)) * albedo.rgb;

  ////// --------------- BLEND TRANSLUCENT GBUFFERS 
  //////////// and do border fog on opaque and translucents

  #if defined BorderFog
    #ifdef DISTANT_HORIZONS
    	float fog = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance_cylinder / dhRenderDistance,0.0)*3.0,1.0)   );
    #else
    	float fog = smoothstep(1.0, 0.0, min(max(1.0 - linearDistance_cylinder / far,0.0)*3.0,1.0)   );
    #endif

    fog *= exp(-10.0 * pow(clamp(playerPos_normalized.y,0.0,1.0)*4.0,2.0));

    fog *= (1.0-caveDetection);

    if(swappedDepth >= 1.0 || isEyeInWater != 0) fog = 0.0;

    #ifdef SKY_GROUND
      vec3 borderFogColor = skyGroundColor;
    #else
      vec3 borderFogColor = skyFromTex(playerPos_normalized, colortex4)/30.0;
    #endif

    color.rgb = mix(color.rgb, borderFogColor, fog);
  #else
    float fog = 0.0;
  #endif
	
  if (TranslucentShader.a > 0.0){
    #ifdef Glass_Tint
      if(!isWater) color *= mix(normalize(albedo.rgb+1e-7), vec3(1.0), max(fog, min(max(0.1-albedo.a,0.0) * 10.0,1.0))) ;
    #endif

    #ifdef BorderFog
      TranslucentShader = mix(TranslucentShader, vec4(0.0), fog);
    #endif
    
    color *= (1.0-TranslucentShader.a);
    color += TranslucentShader.rgb*10.0; 
  }

////// --------------- VARIOUS FOG EFFECTS (behind volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

#if defined OVERWORLD_SHADER && defined CAVE_FOG
    if (isEyeInWater == 0 && eyeAltitude < 1500){

      vec3 cavefogCol = vec3(CaveFogColor_R, CaveFogColor_G, CaveFogColor_B);

      #ifdef PER_BIOME_ENVIRONMENT
        BiomeFogColor(cavefogCol);
      #endif

      cavefogCol *= 1.0-pow(1.0-pow(1.0 - max(1.0 - linearDistance/far,0.0),2.0),CaveFogFallOff);
      cavefogCol *= exp(-7.0*clamp(normalize(playerPos_normalized).y*0.5+0.5,0.0,1.0)) * 0.999 + 0.001;

      cavefogCol *= 0.3;

  	  float skyhole = pow(clamp(1.0-pow(max(playerPos_normalized.y - 0.6,0.0)*5.0,2.0),0.0,1.0),2);

      color.rgb = mix(color.rgb + cavefogCol * caveDetection, cavefogCol, z >= 1.0 ? skyhole * caveDetection : 0.0);
      
    }
#endif


////// --------------- underwater fog
  if (isEyeInWater == 1){
    float dirtAmount = Dirt_Amount;
    vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
    vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
    vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;
		vec3 scatterCoef = dirtAmount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;

    vec3 absorption = exp(-2.0 * totEpsilon * linearDistance);
    vec3 fixedAbsorption = exp(-30.0 * totEpsilon) ;
    vec3 finalAbsorption =  (absorption + fixedAbsorption * 5.0 * (1.0 + nightVision*10));   
    // vec3 finalAbsorption =  absorption;   

    linearDistance = length(vec3(playerPos.x,max(-playerPos.y,0.0),playerPos.z));

    // in vanilla, the water fog has a max distance of ~7 chunks
    float fogfade =  max(1.0 - linearDistance / min(far, 16.0*7.0), 0.0);
    fogfade *= fogfade;
    // fogfade = exp(-5.0* (1.0-fogfade));

    color.rgb = mix(fixedAbsorption, color.rgb * finalAbsorption, fogfade);
    // color.rgb = color.rgb * finalAbsorption;

    bloomyFogMult *= 0.4;
  }

////// --------------- BLEND FOG INTO SCENE
//////////// apply VL fog over opaque and translucents

  bloomyFogMult *= temporallyFilteredVL.a;
  color *= temporallyFilteredVL.a;
  color += temporallyFilteredVL.rgb;
  
////// --------------- VARIOUS FOG EFFECTS (in front of volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

////// --------------- bloomy rain effect
  #ifdef OVERWORLD_SHADER
    float rainDrops =  clamp(texture2D(colortex9,texcoord).a,  0.0,1.0); 
    if(rainDrops > 0.0) bloomyFogMult *= clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0);
  #endif
  
////// --------------- lava.
  if (isEyeInWater == 2){
    color.rgb = mix(color.rgb, vec3(0.1,0.0,0.0), 1.0-exp(-10.0*clamp(linearDistance*0.5,0.,1.))*0.5  );
    bloomyFogMult = 0.0;
  }

///////// --------------- powdered snow
  if (isEyeInWater == 3){
    color.rgb = mix(color.rgb,vec3(0.5,0.75,1.0),clamp(linearDistance*0.5,0.,1.));
    bloomyFogMult = 0.0;
  }

////// --------------- blidnesss
  color.rgb *= mix(1.0,clamp( exp(pow(linearDistance*(blindness*0.2),2) * -5),0.,1.)   ,    blindness);

//////// --------------- darkness effect
  color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(viewPos)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);
  
////// --------------- FINALIZE
  #ifdef display_LUT

    // if(hideGUI == 0){
      vec3 thingy = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy/150),0).rgb /1200.0;

      if(luma(thingy) > 0.0){
        color.rgb =  thingy;
      //   // vl.a = 1.0;
      }
    // }
    #if defined OVERWORLD_SHADER
    
      if( hideGUI == 1) color.rgb = skyCloudsFromTex(playerPos_normalized, colortex4).rgb/1200.0;
    #else
      if( hideGUI == 1) color.rgb = volumetricsFromTex(playerPos_normalized, colortex4, 0.0).rgb/1200.0;
    #endif
  #endif
// color.rgb = vec3(DEBUG);
  gl_FragData[0].r = bloomyFogMult; // pass fog alpha so bloom can do bloomy fog
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);
  // gl_FragData[1].rgb =  vec3(tangentNormals.xy,0.0) * 0.1  ;
  // gl_FragData[1].rgb =  vec3(1.0) * ld(    (data.a > 0.0 ? data.a : texture2D(depthtex0, texcoord).x   )              )   ;
  // gl_FragData[1].rgb = gl_FragData[1].rgb * (1.0-TranslucentShader.a) + TranslucentShader.rgb*10.0;
  // gl_FragData[1].rgb = 1-(texcoord.x > 0.5 ? vec3(TranslucentShader.a) : vec3(data.a));

}