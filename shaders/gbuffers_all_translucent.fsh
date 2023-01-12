// #version 120
#extension GL_EXT_gpu_shader4 : enable

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 normalMat;
varying vec3 binormal;
uniform sampler2D normals;
varying vec3 tangent;
varying vec4 tangent_other;
varying vec3 viewVector;
varying float dist;

#include "lib/settings.glsl"
#include "/lib/res_params.glsl"


uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2DShadow shadow;
uniform sampler2D gaux2;
uniform sampler2D gaux1;
uniform sampler2D depthtex1;

uniform vec4 lightCol;
uniform float nightVision;

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





#include "lib/Shadow_Params.glsl"
#include "lib/color_transforms.glsl"
#include "lib/projections.glsl"
#include "lib/sky_gradient.glsl"
#include "lib/waterBump.glsl"
#include "lib/clouds.glsl"
#include "lib/stars.glsl"
#include "lib/volumetricClouds.glsl"

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
				float sp = sqrt(texelFetch2D(gaux1,ivec2(spos.xy/texelSize/4),0).w/65000.0);
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

	#define PW_DEPTH 0.0 //[0.5 1.0 1.5 2.0 2.5 3.0]
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
	float waterHeight = getWaterHeightmap(posxz.xz, waveM, waveZ, iswater) ;
	
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

	vec3 applyBump(mat3 tbnMatrix, vec3 bump){	
		float bumpmult = 1.0;
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
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
//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
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




float square(float x){
  return x*x;
}
float g(float NdotL, float roughness){
    float alpha = square(max(roughness, 0.02));
    return 2.0 * NdotL / (NdotL + sqrt(square(alpha) + (1.0 - square(alpha)) * square(NdotL)));
}
float gSimple(float dp, float roughness){
  float k = roughness + 1;
  k *= k/8.0;
  return dp / (dp * (1.0-k) + k);
}

vec3 GGX2(vec3 n, vec3 v, vec3 l, float r, vec3 F0,float fresnel) {

  float roughness = r;

  float alpha = square(roughness) + 1e-4;  // when roughness is zero it fucks up

  vec3 h = normalize(l + v) * mix(1.000, 1.0025, 	pow(fresnel,2)	);
  
  float dotLH = clamp(dot(h,l),0.,1.);
  float dotNH = clamp(dot(h,n),0.,1.);
  float dotNL = clamp(dot(n,l),0.,1.);
  float dotNV = clamp(dot(n,v),0.,1.);
  float dotVH = clamp(dot(h,v),0.,1.);


  float D = alpha / (0.0541592653589793*square(square(dotNH) * (alpha - 1.0) + 1.0));
  float G = gSimple(dotNV, roughness) * gSimple(dotNL, roughness);
  vec3 F = F0 + (1. - F0) * exp2((-5.55473*dotVH-6.98316)*dotVH);

  return dotNL * F * (G * D / (4 * dotNV * dotNL + 1e-7));
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
/* RENDERTARGETS:2,7,1,11,13,14 */
void main() {
	if (gl_FragCoord.x * texelSize.x < RENDER_SCALE.x  && gl_FragCoord.y * texelSize.y < RENDER_SCALE.y )	{
		vec2 tempOffset=offsets[framemod8];
		float iswater = normalMat.w;
		vec3 fragC = gl_FragCoord.xyz*vec3(texelSize,1.0);
		vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
		gl_FragData[0] = texture2D(texture, lmtexcoord.xy,-5)*color;
		// float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);
		// gl_FragData[0].rgb = clamp((gl_FragData[0].rgb)*pow(avgBlockLum,-0.33)*0.85,0.0,1.0);

		vec3 albedo = toLinear(gl_FragData[0].rgb);


		#ifndef Vanilla_like_water
			if (iswater > 0.4) {
				albedo = vec3(1.0);
				gl_FragData[0] = vec4(0.42,0.6,0.7,0.7);
			}
			if (iswater > 0.9) {
				gl_FragData[0] = vec4(vec3(0.0),1./255.);
			}
		#endif
		
		#ifdef Vanilla_like_water
			if (iswater > 0.5) {
				gl_FragData[0].a = luma(albedo.rgb);
				albedo = color.rgb;
			}
		#endif

		gl_FragData[4] = vec4(albedo,	gl_FragData[0].a);


		vec3 normal = normalMat.xyz;

		vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
		mat3 tbnMatrix = mat3(tangent.x, binormal.x, normal.x,
							  tangent.y, binormal.y, normal.y,
							  tangent.z, binormal.z, normal.z);
		if (iswater > 0.4){
			float bumpmult = 1.;
			vec3 posxz = p3+cameraPosition;
			posxz.xz-=posxz.y;
			vec3 bump;


			posxz.xyz = getParallaxDisplacement(posxz,iswater,bumpmult,normalize(tbnMatrix*fragpos));

			bump = normalize(getWaveHeight(posxz.xz,iswater));
			bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
			normal = normalize(bump * tbnMatrix);
		}else {
			vec3 normalTex = texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).rgb;
			
			normalTex.xy = normalTex.xy*2.0-1.0;
			normalTex.z = clamp(sqrt(1.0 - dot(normalTex.xy, normalTex.xy)),0.0,1.0);
			normal = applyBump(tbnMatrix,normalTex);
		}

		vec4 data0 = vec4(1);
		vec4 data1 = clamp( encode(viewToWorld(normal), lmtexcoord.zw),0.0,1.0);
		gl_FragData[3] = vec4(encodeVec2(data0.x,data1.x),	encodeVec2(data0.y,data1.y),	encodeVec2(data0.z,data1.z),	encodeVec2(data1.w,data0.w));
		gl_FragData[5] = vec4(encodeVec2(lmtexcoord.a,lmtexcoord.a),	encodeVec2(lmtexcoord.a,lmtexcoord.a),	encodeVec2(lmtexcoord.a,lmtexcoord.a),	encodeVec2(lmtexcoord.a,lmtexcoord.a));

		float NdotL = lightSign*dot(normal,sunVec);
		float NdotU = dot(upVec,normal);
		float diffuseSun = clamp(NdotL,0.0f,1.0f);
		diffuseSun =  clamp((-15 + diffuseSun*255.0) / 240.0  ,0.0,1.0);

		vec3 direct = texelFetch2D(gaux1,ivec2(6,37),0).rgb/127.0;

		#ifdef ambientLight_only
			direct = vec3(0);
		#endif


		float shading = 1.0;
		float cloudShadow = 1.0;
		//compute shadows only if not backface
		if (diffuseSun > 0.001) {
			vec3 p3 = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
			vec3 projectedShadowPosition = mat3(shadowModelView) * p3 + shadowModelView[3].xyz;
			projectedShadowPosition = diagonal3(shadowProjection) * projectedShadowPosition + shadowProjection[3].xyz;

			//apply distortion
			float distortFactor = calcDistort(projectedShadowPosition.xy);
			projectedShadowPosition.xy *= distortFactor;
			//do shadows only if on shadow map
			if (abs(projectedShadowPosition.x) < 1.0-1.5/shadowMapResolution && abs(projectedShadowPosition.y) < 1.0-1.5/shadowMapResolution){
				const float threshMul = max(2048.0/shadowMapResolution*shadowDistance/128.0,0.95);
				float distortThresh = (sqrt(1.0-diffuseSun*diffuseSun)/diffuseSun+0.7)/distortFactor;
				float diffthresh = distortThresh/6000.0*threshMul;

				projectedShadowPosition = projectedShadowPosition * vec3(0.5,0.5,0.5/6.0) + vec3(0.5,0.5,0.5);

				shading = 0.0;
				float noise = blueNoise();
				float rdMul = 4.0/shadowMapResolution;
				for(int i = 0; i < 9; i++){
					vec2 offsetS = tapLocation(i,9, 1.618,noise,0.0);

					float weight = 1.0+(i+noise)*rdMul/9.0*shadowMapResolution;
					shading += shadow2D(shadow,vec3(projectedShadowPosition + vec3(rdMul*offsetS,-diffthresh*weight))).x/9.0;
					}
				direct *= shading;
			}


			#ifdef VOLUMETRIC_CLOUDS
			#ifdef CLOUDS_SHADOWS
				vec3 campos = (p3 + cameraPosition)-319 ;
				// get cloud position
				vec3 cloudPos = campos*Cloud_Size + WsunVec/abs(WsunVec.y) * (2250 - campos.y*Cloud_Size);
				// get the cloud density and apply it
				cloudShadow = getCloudDensity(cloudPos, 1);
				// cloudShadow = exp(-cloudShadow*sqrt(cloudDensity)*25);
				
				cloudShadow = clamp(exp(-cloudShadow*10),0,1);
			
				// make these turn to zero when occluded by the cloud shadow
				direct *= cloudShadow;
			#endif
			#endif
		}
		
	
		vec3 ambientLight = (texture2D(gaux1,(lmtexcoord.zw*15.+0.5)*texelSize).rgb * 2.0) * 8./150./3.;

		direct *= (iswater > 0.9 ? 0.2: 1.0)*diffuseSun*lmtexcoord.w;

		vec3 directLight = direct;

		vec3 color = vec3(0);

		
		color += ambientLight ;
		color += directLight;

		#ifdef Glass_Tint
			float alphashit = min(pow(gl_FragData[0].a,2.0),1.0);
			color *= alphashit;
		#endif

		color *= albedo;
		
		vec2 specularstuff = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rg;
		specularstuff = iswater > 0.0 && specularstuff.r > 0.0 && specularstuff.g < 0.9 ? specularstuff : vec2(1.0,0.02);

		if (iswater > 0.0){
			
			float roughness = pow(1.0-specularstuff.r,2.0);
			float f0 = 0;

			float F0 = f0;

			vec3 reflectedVector = reflect(normalize(fragpos), normal);
			float normalDotEye = dot(normal, normalize(fragpos));
			float fresnel = pow(clamp(1.0 + normalDotEye,0.0,1.0), 5.0);

			// snells window looking thing
			if(isEyeInWater == 1 && iswater > 0.99) fresnel = clamp(pow(1.66 + normalDotEye,25),0.02,1.0);

			fresnel = mix(F0, 1.0, fresnel); 
			float indoors = clamp((lmtexcoord.w-0.6)*5.0, 0.0,1.0);
			vec3 wrefl = mat3(gbufferModelViewInverse)*reflectedVector;

			vec3 sky_c = skyCloudsFromTex(wrefl,gaux1).rgb / 150. * 5. ;
			sky_c.rgb *= indoors;

			float visibilityFactor = clamp(exp2((pow(roughness,3.0) / F0) * -4),0,1);

			sky_c = mix(sky_c,color,(1.0-indoors)) ;

			vec4 reflection = vec4(0.);
			#ifdef SCREENSPACE_REFLECTIONS
				vec3 rtPos = rayTrace(reflectedVector,fragpos.xyz, interleaved_gradientNoise(), fresnel, isEyeInWater == 1);
				if (rtPos.z <1.){
					vec3 previousPosition = mat3(gbufferModelViewInverse) * toScreenSpace(rtPos) + gbufferModelViewInverse[3].xyz + cameraPosition-previousCameraPosition;
					previousPosition = mat3(gbufferPreviousModelView) * previousPosition + gbufferPreviousModelView[3].xyz;
					previousPosition.xy = projMAD(gbufferPreviousProjection, previousPosition).xy / -previousPosition.z * 0.5 + 0.5;
					if (previousPosition.x > 0.0 && previousPosition.y > 0.0 && previousPosition.x < 1.0 && previousPosition.x < 1.0) {
						reflection.a = 1.0;
						reflection.rgb = texture2D(gaux2,previousPosition.xy).rgb;
					}
				}
			#endif

			if(isEyeInWater == 1 ) sky_c.rgb = color.rgb*lmtexcoord.w;

			reflection.rgb = mix(sky_c.rgb, reflection.rgb, reflection.a);

			vec3 sunSpec = shading*directLight * GGX2(normal, -normalize(fragpos),  lightSign*sunVec, roughness, vec3(f0), fresnel)		;

			sunSpec *= max(cloudShadow-0.5,0.0);

			vec3 reflected = reflection.rgb*fresnel  + sunSpec ;

			// reflected = vec3(0);

			float alpha0 = gl_FragData[0].a;
			// //correct alpha channel with fresnel
			gl_FragData[0].a = -gl_FragData[0].a*fresnel+gl_FragData[0].a+fresnel;
			gl_FragData[0].rgb = clamp(color/gl_FragData[0].a*alpha0*(1.0-fresnel)*0.1+reflected/gl_FragData[0].a*0.1,0.0,65100.0);

			

			if (gl_FragData[0].r > 65000.) gl_FragData[0].rgba = vec4(0.);

			#ifdef BorderFog
				float fog = 1.0 - clamp( exp2(-pow(length(fragpos / far),10.)*3.0)  ,0.0,1.0);
				gl_FragData[0].a = mix(gl_FragData[0].a, 0.0, fog);
			#endif

		} 
		else 
		gl_FragData[0].rgb = color*.1;

		gl_FragData[1] = vec4(albedo,iswater);

	}
}
