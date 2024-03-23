#include "/lib/settings.glsl"

flat varying vec3 zMults;

flat varying vec2 TAA_Offset;
flat varying vec3 skyGroundColor;

uniform sampler2D noisetex;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D dhDepthTex;
uniform sampler2D dhDepthTex1;


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
uniform sampler2D colortex15;
uniform vec2 texelSize;

#if defined NETHER_SHADER || defined END_SHADER
  uniform sampler2D colortex4;
#endif

flat varying vec4 lightCol; //main light source color (rgb),used light source(1=sun,-1=moon)
flat varying vec3 WsunVec;

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

uniform int isEyeInWater;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;
uniform float rainStrength;
uniform float blindness;
uniform float darknessFactor;
uniform float darknessLightFactor;


#include "/lib/waterBump.glsl"
#include "/lib/res_params.glsl"

#ifdef OVERWORLD_SHADER
  #include "/lib/sky_gradient.glsl"
  #include "/lib/lightning_stuff.glsl"
  #include "/lib/volumetricClouds.glsl"
#endif
#ifndef OVERWORLD_SHADER
  #include "/lib/climate_settings.glsl"
#endif


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
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}

#include "/lib/DistantHorizons_projections.glsl"

float DH_ld(float dist) {
    return (2.0 * dhNearPlane) / (dhFarPlane + dhNearPlane - dist * (dhFarPlane - dhNearPlane));
}
float DH_inv_ld (float lindepth){
	return -((2.0*dhNearPlane/lindepth)-dhFarPlane-dhNearPlane)/(dhFarPlane-dhNearPlane);
}
float linearizeDepthFast(const in float depth, const in float near, const in float far) {
    return (near * far) / (depth * (near - far) + far);
}

vec4 BilateralUpscale(sampler2D tex, sampler2D depth, vec2 coord, float referenceDepth){
	ivec2 scaling = ivec2(1.0/VL_RENDER_RESOLUTION);
	ivec2 posDepth  = ivec2(coord*VL_RENDER_RESOLUTION) * scaling;
	ivec2 posColor  = ivec2(coord*VL_RENDER_RESOLUTION);
 	ivec2 pos = ivec2(gl_FragCoord.xy*texelSize + 1);

	ivec2 getRadius[4] = ivec2[](
   	ivec2(-2,-2),
	 	ivec2(-2, 0),
		ivec2( 0, 0),
		ivec2( 0,-2)
  );

	#ifdef DISTANT_HORIZONS
		float diffThreshold = 0.01;
	#else
		float diffThreshold = zMults.x;
	#endif


	vec4 RESULT = vec4(0.0);
	float SUM = 0.0;

	for (int i = 0; i < 4; i++) {
		
		ivec2 radius = getRadius[i];

		#ifdef DISTANT_HORIZONS
			float offsetDepth = sqrt(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling,0).a/65000.0);
		#else
			float offsetDepth = ld(texelFetch2D(depth, posDepth + radius * scaling + pos * scaling, 0).r);
		#endif

		float EDGES = abs(offsetDepth - referenceDepth) < diffThreshold ? 1.0 : 1e-5;
		
		RESULT += texelFetch2D(tex, posColor + radius + pos, 0) * EDGES;

		SUM += EDGES;
	}
	// return vec4(1) * SUM;
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
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}

vec3 worldToView(vec3 worldPos) {
    vec4 pos = vec4(worldPos, 0.0);
    pos = gbufferModelView * pos;
    return pos.xyz;
}
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
vec4 blueNoise(vec2 coord){
  return texelFetch2D(colortex6, ivec2(coord )%512  , 0);
}
vec3 normVec (vec3 vec){
	return vec*inversesqrt(dot(vec,vec));
}

float interleaved_gradientNoise(){
	vec2 coord = gl_FragCoord.xy;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
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

void ApplyDistortion(inout vec2 Texcoord, vec2 TangentNormals, float lineardistance, bool isEntity){

  vec2 UnalteredTexcoord = Texcoord;
  
  float refractionStrength = isEntity ? 0.5 : 1.0;

  // Texcoord = abs(Texcoord + (TangentNormals * clamp((ld(depths.x) - ld(depths.y)) * 0.5,0.0,0.15)) * RENDER_SCALE * refractionStrength );
  Texcoord = abs(Texcoord + (TangentNormals * mix(0.01, 0.1, pow(clamp(1.0-lineardistance/(32*4),0.0,1.0),2))) * RENDER_SCALE * refractionStrength );

  float DistortedAlpha = decodeVec2(texture2D(colortex11,Texcoord).b).g;
  
  if(DistortedAlpha < 0.1) Texcoord = UnalteredTexcoord; // remove distortion on non-translucents
}

uniform float dhRenderDistance;
uniform float eyeAltitude;

void main() {
  /* DRAWBUFFERS:73 */

	////// --------------- SETUP STUFF --------------- //////
  vec2 texcoord = gl_FragCoord.xy*texelSize;

  float z = texture2D(depthtex0,texcoord).x;
  float z2 = texture2D(depthtex1,texcoord).x;
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

	vec3 fragpos = toScreenSpace_DH(texcoord/RENDER_SCALE-vec2(TAA_Offset)*texelSize*0.5, z, DH_depth0);
  
	// vec3 fragpos = toScreenSpace(vec3(texcoord/RENDER_SCALE-vec2(TAA_Offset)*texelSize*0.5,z));
	vec3 p3 = mat3(gbufferModelViewInverse) * fragpos;
	vec3 np3 = normVec(p3);

  float linearDistance = length(p3);
  float linearDistance_cylinder = length(p3.xz);

	float lightleakfix = clamp(pow(eyeBrightnessSmooth.y/240.,2) ,0.0,1.0);
	float lightleakfixfast = clamp(eyeBrightness.y/240.,0.0,1.0);

	////// --------------- UNPACK TRANSLUCENT GBUFFERS --------------- //////
	vec3 data = texture2D(colortex11,texcoord).rgb;
	vec4 unpack0 =  vec4(decodeVec2(data.r),decodeVec2(data.g)) ;
	vec4 unpack1 = vec4(decodeVec2(data.b),0,0) ;
	
	vec4 albedo = vec4(unpack0.ba,unpack1.rg);
	vec2 tangentNormals = unpack0.xy*2.0-1.0;

  if(albedo.a < 0.01) tangentNormals = vec2(0.0);

  vec4 TranslucentShader = texture2D(colortex2, texcoord);

	////// --------------- UNPACK MISC --------------- //////
  float trpData = texture2D(colortex7,texcoord).a;

	////// --------------- MASKS/BOOLEANS --------------- //////
  bool iswater = trpData > 0.99;
  bool isTranslucentEntity = abs(trpData-0.1) < 0.01;	
  float translucentAlpha = trpData;



  ////// --------------- get volumetrics
  #ifdef TOGGLE_VL_FOG
    #ifdef DISTANT_HORIZONS
      vec4 vl = BilateralUpscale(colortex0, colortex12, gl_FragCoord.xy, sqrt(texture2D(colortex12,texcoord).a/65000.0));
    #else
      vec4 vl = BilateralUpscale(colortex0, depthtex0, gl_FragCoord.xy, frDepth);
    #endif
  #else
    vec4 vl = vec4(0,0,0,1);
  #endif

  float bloomyFogMult = 1.0;

  ////// --------------- distort texcoords as a refraction effect
  vec2 refractedCoord = texcoord;
  #ifdef Refraction
    ApplyDistortion(refractedCoord, tangentNormals, linearDistance, isTranslucentEntity);
  #endif
  
  ////// --------------- MAIN COLOR BUFFER
  vec3 color = texture2D(colortex3, refractedCoord).rgb;


  ////// --------------- BLEND TRANSLUCENT GBUFFERS 
  //////////// and do border fog on opaque and translucents

  #if defined BorderFog

    #ifdef DISTANT_HORIZONS
      float fog = 1.0 - pow(1.0-pow(1.0-min(max(1.0 - linearDistance_cylinder / dhFarPlane,0.0)*3.0,1.0),2.0),2.0);
    #else
    	float fog =  1.0 - pow(1.0-pow(1.0-min(max(1.0 - linearDistance_cylinder / far,0.0)*5.0,1.0),2.0),2.0);
    #endif

    fog *= exp(-10.0 * pow(clamp(np3.y,0.0,1.0)*4.0,2.0));
    if(swappedDepth >= 1.0 || isEyeInWater != 0) fog = 0.0;
    
    if(lightleakfixfast < 1.0) fog *= lightleakfix;
  
    #ifdef SKY_GROUND
      vec3 borderFogColor = skyGroundColor;
    #else
     vec3 borderFogColor = skyFromTex(np3, colortex4)/30.0;
    #endif

    color.rgb = mix(color.rgb, borderFogColor, fog);
  #endif

  if (TranslucentShader.a > 0.0){
		#ifdef Glass_Tint
      if(!iswater) color *= normalize(albedo.rgb+0.0001)*0.9+0.1;
    #endif

    color = color*(1.0-TranslucentShader.a) + TranslucentShader.rgb; 

    #ifdef BorderFog
      color.rgb = mix(color.rgb, borderFogColor, fog);
    #endif
  }

////// --------------- VARIOUS FOG EFFECTS (behind volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

#if defined OVERWORLD_SHADER && defined CAVE_FOG
    if (isEyeInWater == 0 && eyeAltitude < 1500 && lightleakfix < 1.0){

      float cavefog = clamp( pow(linearDistance / far, CaveFogFallOff) ,0.0,1.0);
      cavefog = cavefog*0.95 + clamp( pow(1.0 - exp((linearDistance / far) * -5), 2.0) ,0.0,1.0)*0.05;

  	  cavefog *= exp(-30.0*(pow(clamp(np3.y-0.5,0.0,1.0),2.0))); // create a hole in the fog above, so the sky is a little visible.

      vec3 cavefogCol = vec3(CaveFogColor_R, CaveFogColor_G, CaveFogColor_B);
      cavefogCol *= clamp( exp(clamp(np3.y * 0.5 + 0.5,0,1) * -3.0)  ,0.0,1.0); // apply a vertical gradient to the fog color

      #ifdef PER_BIOME_ENVIRONMENT
        BiomeFogColor(cavefogCol);
      #endif

      color.rgb = mix(color.rgb,  cavefogCol,  cavefog * (1-lightleakfix));
    }
#endif

////// --------------- Distance fog for the end shader
#ifdef END_SHADER
    if (isEyeInWater == 0){
      vec3 hazeColor = vec3(0.3,0.75,1.0) * 0.3;

      float hazeDensity = clamp(1.0 - linearDistance / max(far, 32.0 * 24.0),0.0,1.0);
      color.rgb = mix(hazeColor,  color.rgb,  hazeDensity) ; 
    }
#endif

////// --------------- underwater fog
  if (isEyeInWater == 1){
    float dirtAmount = Dirt_Amount + 0.01;
    vec3 waterEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
    vec3 dirtEpsilon = vec3(Dirt_Absorb_R, Dirt_Absorb_G, Dirt_Absorb_B);
    vec3 totEpsilon = dirtEpsilon*dirtAmount + waterEpsilon;

    vec3 absorbColor = exp(-totEpsilon*linearDistance);
    vec3 maxAbsorb = exp(-8.0 * totEpsilon);

    #ifdef OVERWORLD_SHADER
    
      linearDistance = length(vec3(p3.x,max(-p3.y,0.0),p3.z));
      float fogfade =  exp(-0.001*(linearDistance*linearDistance));
      vec3 thresholdAbsorbedColor = mix(maxAbsorb, absorbColor, clamp(dot(absorbColor,vec3(0.33333)),0.0,1.0));
      color.rgb = mix(vec3(1.0) * clamp(WsunVec.y,0,1) * pow(normalize(np3).y*0.3+0.7,1.5) * maxAbsorb, color.rgb * thresholdAbsorbedColor, clamp(fogfade,0.0,1.0));
    
    #else
   
      color.rgb *= absorbColor;
      
    #endif
    
    bloomyFogMult *= 0.4;
  }

////// --------------- BLEND FOG INTO SCENE
//////////// apply VL fog over opaque and translucents
  color *= vl.a;
  color += vl.rgb;
  bloomyFogMult *= vl.a;
  
////// --------------- VARIOUS FOG EFFECTS (in front of volumetric fog)
//////////// blindness, nightvision, liquid fogs and misc fogs

////// --------------- bloomy rain effect
  #ifdef OVERWORLD_SHADER
    float rainDrops =  clamp(texture2D(colortex9,texcoord).a,  0.0,1.0); 
    if(rainDrops > 0.0) bloomyFogMult *= clamp(1.0 - pow(rainDrops*5.0,2),0.0,1.0);
  #endif
  
////// --------------- lava.
  if (isEyeInWater == 2){
    color.rgb = vec3(4.0,0.5,0.1);
  }

///////// --------------- powdered snow
  if (isEyeInWater == 3){
    color.rgb = mix(color.rgb,vec3(10,15,20),clamp(linearDistance*0.5,0.,1.));
    bloomyFogMult = 0.0;
  }

////// --------------- blidnesss
  color.rgb *= mix(1.0,clamp( exp(pow(linearDistance*(blindness*0.2),2) * -5),0.,1.)   ,    blindness);

//////// --------------- darkness effect
  color.rgb *= mix(1.0, (1.0-darknessLightFactor*2.0) * clamp(1.0-pow(length(fragpos)*(darknessFactor*0.07),2.0),0.0,1.0), darknessFactor);
  
////// --------------- FINALIZE
  #ifdef display_LUT
    vec3 thingy = texelFetch2D(colortex4,ivec2(gl_FragCoord.xy),0).rgb / 30;

    if(luma(thingy) > 0.0){
      color.rgb =  thingy;
      vl.a = 1.0;
    }
  #endif
// color.rgb = vec3(1) * sqrt(texture2D(colortex12,texcoord).a/65000.0);

  gl_FragData[0].r = bloomyFogMult; // pass fog alpha so bloom can do bloomy fog
  gl_FragData[1].rgb = clamp(color.rgb, 0.0,68000.0);

  // gl_FragData[1].rgb = vec3(1) * sqrt(texelFetch2D(colortex12,ivec2(gl_FragCoord.xy),0).a/65000.0);

  // gl_FragData[1].rgb = vl.rgb;
}