#extension GL_EXT_gpu_shader4 : enable
#extension GL_ARB_shader_texture_lod : enable
//#define Specular_Reflections // reflections on blocks. REQUIRES A PBR RESOURCEPACK.
//#define POM
#define POM_MAP_RES 128.0 // [16.0 32.0 64.0 128.0 256.0 512.0 1024.0] Increase to improve POM quality
#define POM_DEPTH 0.1 // [0.025 0.05 0.075 0.1 0.125 0.15 0.20 0.25 0.30 0.50 0.75 1.0] //Increase to increase POM strength
#define MAX_ITERATIONS 50 // [5 10 15 20 25 30 40 50 60 70 80 90 100 125 150 200 400] //Improves quality at grazing angles (reduces performance)
#define MAX_DIST 25.0 // [5.0 10.0 15.0 20.0 25.0 30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 125.0 150.0 200.0 400.0] //Increases distance at which POM is calculated
//#define USE_LUMINANCE_AS_HEIGHTMAP	//Can generate POM on any texturepack (may look weird in some cases)
#define Texture_MipMap_Bias -1.00 // Uses a another mip level for textures. When reduced will increase texture detail but may induce a lot of shimmering. [-5.00 -4.75 -4.50 -4.25 -4.00 -3.75 -3.50 -3.25 -3.00 -2.75 -2.50 -2.25 -2.00 -1.75 -1.50 -1.25 -1.00 -0.75 -0.50 -0.25 0.00 0.25 0.50 0.75 1.00 1.25 1.50 1.75 2.00 2.25 2.50 2.75 3.00 3.25 3.50 3.75 4.00 4.25 4.50 4.75 5.00]
#define DISABLE_ALPHA_MIPMAPS //Disables mipmaps on the transparency of alpha-tested things like foliage, may cost a few fps in some cases


#define SSAO // screen-space ambient occlusion. 
#define texture_ao // ambient occlusion on the texture

#define Puddle_Size 1.0 // [0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5]
#ifdef Specular_Reflections
	#define Puddles // yes
#else
	// #define Puddles // yes
#endif
// #define Porosity

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;
const vec3 intervalMult = vec3(1.0, 1.0, 1.0/POM_DEPTH)/POM_MAP_RES * 1.0;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

uniform vec2 texelSize;
uniform int framemod8;

#ifdef POM
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

#endif
#include "/lib/res_params.glsl"
varying vec4 lmtexcoord;
varying vec4 color;
uniform float far;
varying vec4 normalMat;
#ifdef MC_NORMAL_MAP
varying vec4 tangent;
uniform float wetness;
uniform sampler2D normals;
uniform sampler2D specular;
#endif

#ifdef POM
	vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);
	vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);
#endif

flat varying int lightningBolt;
uniform sampler2D texture;
uniform sampler2D colortex1;//albedo(rgb),material(alpha) RGBA16
uniform float frameTimeCounter;
uniform int frameCounter;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelView;
uniform mat4 gbufferProjection;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;
uniform float rainStrength;
uniform sampler2D noisetex;//depth
uniform sampler2D depthtex0;
in vec3 test_motionVectors;

varying vec4 materialMask;

flat varying vec4 TESTMASK;

// float interleaved_gradientNoise(){
// 	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
// }
float interleaved_gradientNoise(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	vec2 coord = vec2(alpha.x * gl_FragCoord.x,alpha.y * gl_FragCoord.y)+ 1.0/1.6180339887 * frameCounter;
	float noise = fract(52.9829189*fract(0.06711056*coord.x + 0.00583715*coord.y));
	return noise;
}

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float R2_dither(){
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * gl_FragCoord.x + alpha.y * gl_FragCoord.y + 1.0/1.6180339887 * frameCounter) ;
}
vec2 decodeVec2(float a){
    const vec2 constant1 = 65535. / vec2( 256., 65536.);
    const float constant2 = 256. / 255.;
    return fract( a * constant1 ) * constant2 ;
}
mat3 inverse(mat3 m) {
  float a00 = m[0][0], a01 = m[0][1], a02 = m[0][2];
  float a10 = m[1][0], a11 = m[1][1], a12 = m[1][2];
  float a20 = m[2][0], a21 = m[2][1], a22 = m[2][2];

  float b01 = a22 * a11 - a12 * a21;
  float b11 = -a22 * a10 + a12 * a20;
  float b21 = a21 * a10 - a11 * a20;

  float det = a00 * b01 + a01 * b11 + a02 * b21;

  return mat3(b01, (-a22 * a01 + a02 * a21), (a12 * a01 - a02 * a11),
              b11, (a22 * a00 - a02 * a20), (-a12 * a00 + a02 * a10),
              b21, (-a21 * a00 + a01 * a20), (a11 * a00 - a01 * a10)) / det;
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


#ifdef MC_NORMAL_MAP
	// vec3 applyBump(mat3 tbnMatrix, vec3 bump){
	// 	float bumpmult = 1.0;
	// 	bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
	// 	return normalize(bump*tbnMatrix);
	// }
	vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
		float bumpmult = clamp(puddle_values,0.0,1.0);
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
	}
#endif

//encoding by jodie
float encodeVec2(vec2 a){
    const vec2 constant1 = vec2( 1., 256.) / 65535.;
    vec2 temp = floor( a * 255. );
	return temp.x*constant1.x+temp.y*constant1.y;
}
float encodeVec2(float x,float y){
    return encodeVec2(vec2(x,y));
}

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 p3 = p * 2. - 1.;
    vec4 fragposition = iProjDiag * p3.xyzz + gbufferProjectionInverse[3];
    return fragposition.xyz / fragposition.w;
}
vec3 toClipSpace3(vec3 viewSpacePosition) {
    return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
}
#ifdef POM
vec4 readNormal(in vec2 coord)
{
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}
vec4 readTexture(in vec2 coord)
{
	return texture2DGradARB(texture,fract(coord)*vtexcoordam.pq+vtexcoordam.st,dcdx,dcdy);
}
#endif
float luma(vec3 color) {
	return dot(color,vec3(0.21, 0.72, 0.07));
}


vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
}


const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);




// float getPuddleCoverage(vec3 samplePos){
// 	float puddle = texture2D(noisetex, samplePos.xz/25000).b ;

// 	return max(puddle,0.0);
// }

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS: 1,7,8,13 */
void main() {

	#ifdef BLOCK_ENT
		gl_FragData[3] = TESTMASK;
	#endif

    float phi = 2 * 3.14159265359;
	float noise = fract(fract(frameCounter * (1.0 / phi)) + interleaved_gradientNoise() )	;

	vec3 normal = normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
		mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
							  tangent.y, tangent2.y, normal.y,
							  tangent.z, tangent2.z, normal.z);
	#endif
	vec2 tempOffset=offsets[framemod8];

	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	


	vec3 worldpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition;
	float lightmap = clamp( (lmtexcoord.w-0.66) * 5.0,0.,1.);

	float rainfall = 0. ;
	float Puddle_shape = 0.;
	float puddle_shiny = 1.;
	float puddle_normal = 0.;
	
	#ifndef ENTITIES
	#ifdef WORLD
	#ifdef Puddles
		rainfall = rainStrength ;
		Puddle_shape =  1.0 - max(texture2D(noisetex, worldpos.xz * (0.015 * Puddle_Size)).b - (1.0-lightmap)  ,0.0);
		puddle_shiny =   clamp( pow(1.0-Puddle_shape,2.0)*2,0.5,1.)   ;
		puddle_normal =  clamp( pow(Puddle_shape,5.0) * 50.	,0.,1.)  ;
	#endif
	#endif
	#endif

	#ifdef POM
		// vec2 tempOffset=offsets[framemod8];
		vec2 adjustedTexCoord = fract(vtexcoord.st)*vtexcoordam.pq+vtexcoordam.st;
		// vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize/RENDER_SCALE,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
		vec3 viewVector = normalize(tbnMatrix*fragpos);
		float dist = length(fragpos);

		gl_FragDepth = gl_FragCoord.z;

		#ifdef WORLD
	    	if (dist < MAX_OCCLUSION_DISTANCE) {

	   	 	if ( viewVector.z < 0.0 && readNormal(vtexcoord.st).a < 0.9999 && readNormal(vtexcoord.st).a > 0.00001) {	

	  				vec3 interval = viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS*POM_DEPTH;
	  				vec3 coord = vec3(vtexcoord.st, 1.0);
	  				coord += noise*interval;
					float sumVec = noise;
	  				for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - POM_DEPTH + POM_DEPTH*readNormal(coord.st).a < coord.p) && coord.p >= 0.0; ++loopCount) { coord = coord+interval; sumVec += 1.0; }
	
					if (coord.t < mincoord) {
	  					if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
	  						coord.t = mincoord;
	  						discard;
	  					}
	  				}
	  				adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st, adjustedTexCoord, max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));

	  				vec3 truePos = fragpos + sumVec*inverse(tbnMatrix)*interval;
	  				// #ifdef Depth_Write_POM
	  					gl_FragDepth = toClipSpace3(truePos).z;
	  				// #endif
				}
	    	}
		#endif

			// color
			vec4 data0 = texture2DGradARB(texture, adjustedTexCoord.xy,dcdx,dcdy);

	 		#ifdef DISABLE_ALPHA_MIPMAPS
	 			data0.a = texture2DGradARB(texture, adjustedTexCoord.xy,vec2(0.),vec2(0.0)).a;
	 		#endif
			 
			data0.rgb *= color.rgb;
	  		float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);
	  		data0.rgb = clamp(data0.rgb*pow(avgBlockLum,-0.33)*0.85,0.0,1.0);


			#ifdef WORLD
				if (data0.a > 0.1) data0.a = normalMat.a;
				else data0.a = 0.0;
			#endif

			#ifdef HAND
				if (data0.a > 0.1) data0.a = 0.75;
				else data0.a = 0.0;
			#endif

			// normal
			#ifdef MC_NORMAL_MAP
				vec3 normalTex = texture2DGradARB(normals, adjustedTexCoord.xy, dcdx,dcdy).rgb;
				normalTex.xy = normalTex.xy*2.0-1.0;
				normalTex.z = clamp(sqrt(1.0 - dot(normalTex.xy, normalTex.xy)),0.0,1.0);
				normal = applyBump(tbnMatrix,normalTex, mix(1.0,puddle_normal,rainfall));
			#endif

			// specular
			gl_FragData[2] = texture2DGradARB(specular, adjustedTexCoord.xy,dcdx,dcdy);

			// finalize
			vec4 data1 = clamp(encode(viewToWorld(normal), lmtexcoord.zw),0.,1.0);
			gl_FragData[0] = vec4(encodeVec2(data0.x,data1.x),encodeVec2(data0.y,data1.y),encodeVec2(data0.z,data1.z),encodeVec2(data1.w,data0.w));
			
			gl_FragData[1].a = 0.0;

	#else
			// specular
			vec4 specular = texture2D(specular, lmtexcoord.xy, Texture_MipMap_Bias).rgba;
			vec4 specular_modded = vec4( max(specular.r,puddle_shiny), max(specular.g, puddle_shiny*0.1),specular.ba);
			gl_FragData[2].rgba = mix(specular, specular_modded, rainfall);

			float porosity = specular.z >= 64.5/255.0 ? 0.0 : (specular.z*255.0/64.0)*0.65;
			#ifndef Porosity
				porosity = 0.4;
			#endif
			// normal 
			#ifdef MC_NORMAL_MAP
				vec4 normalTex = texture2D(normals, lmtexcoord.xy, Texture_MipMap_Bias).rgba;
				normalTex.xy = normalTex.xy*2.0-1.0;
				normalTex.z = clamp(sqrt(1.0 - dot(normalTex.xy, normalTex.xy)),0.0,1.0) ;
				normal = applyBump(tbnMatrix, normalTex.xyz,  mix(1.0,puddle_normal, rainfall)  );
			#endif

			// color
			vec4 data0 = texture2D(texture, lmtexcoord.xy, Texture_MipMap_Bias)  ;

			data0.rgb *= mix(color.rgb, vec3(0.0), max((puddle_shiny*porosity)*0.5,0) * rainfall );



	  		float avgBlockLum = luma(texture2DLod(texture, lmtexcoord.xy,128).rgb*color.rgb);
	  		data0.rgb = clamp(data0.rgb*pow(avgBlockLum,-0.33)*0.85,0.0,1.0);

			#ifndef ENTITIES
				if(TESTMASK.r==255) data0.rgb = vec3(0);
			#endif
			
	  		#ifdef DISABLE_ALPHA_MIPMAPS
	  			data0.a = texture2DLod(texture,lmtexcoord.xy,0).a;
	  		#endif
			#ifdef WORLD
				if (data0.a > 0.1) data0.a = normalMat.a;
				else data0.a = 0.0;
				
			#endif
			#ifdef HAND
				if (data0.a > 0.1) data0.a = 0.75;
				else data0.a = 0.0;
			#endif
			
			// finalize
			vec4 data1 = clamp(blueNoise()/255.0 + encode(viewToWorld(normal), lmtexcoord.zw),0.0,1.0);
			gl_FragData[0] = vec4(encodeVec2(data0.x,data1.x),	encodeVec2(data0.y,data1.y),	encodeVec2(data0.z,data1.z),	encodeVec2(data1.w,data0.w));

		#ifdef WORLD
			gl_FragData[1].a = 0.0;
		#endif
	
	#endif


	
	#ifdef ENTITIES
	#ifdef WORLD
		gl_FragData[3].xyz = test_motionVectors;
	#endif
	#endif
  	// float z = texture2D(depthtex0,texcoord).x;
    // vec3 fragpos = toScreenSpace(vec3(texcoord,z));
	// gl_FragData[0].rgb *= vec3(1- clamp( pow( length(fragpos)/far, 1), 0, 1)) ;

	

}