//#extension GL_EXT_gpu_shader4 : disable
//#extension GL_ARB_shader_texture_lod : disable

#include "/lib/settings.glsl"


flat varying int NameTags;

#ifndef USE_LUMINANCE_AS_HEIGHTMAP
#ifndef MC_NORMAL_MAP
#undef POM
#endif
#endif

#ifdef POM
#define MC_NORMAL_MAP
#endif


varying float VanillaAO;

const float mincoord = 1.0/4096.0;
const float maxcoord = 1.0-mincoord;

const float MAX_OCCLUSION_DISTANCE = MAX_DIST;
const float MIX_OCCLUSION_DISTANCE = MAX_DIST*0.9;
const int   MAX_OCCLUSION_POINTS   = MAX_ITERATIONS;

uniform vec2 texelSize;
uniform int framemod8;

// #ifdef POM
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec4 vtexcoord;

vec2 dcdx = dFdx(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);
vec2 dcdy = dFdy(vtexcoord.st*vtexcoordam.pq)*exp2(Texture_MipMap_Bias);
// #endif

#include "/lib/res_params.glsl"

varying vec4 lmtexcoord;
varying vec4 color;
varying vec4 NoSeasonCol;
varying vec4 seasonColor;
uniform float far;
varying vec4 normalMat;

#ifdef MC_NORMAL_MAP
	varying vec4 tangent;
	uniform sampler2D normals;
	varying vec3 FlatNormals;
#endif

uniform sampler2D specular;

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
uniform vec4 entityColor;

flat varying float blockID;

flat varying float SSSAMOUNT;
flat varying float EMISSIVE;
flat varying int LIGHTNING;
flat varying int SIGN;

flat varying float HELD_ITEM_BRIGHTNESS;

float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
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


#ifdef MC_NORMAL_MAP
	vec3 applyBump(mat3 tbnMatrix, vec3 bump, float puddle_values){
		float bumpmult = clamp(puddle_values,0.0,1.0);
		bump = bump * vec3(bumpmult, bumpmult, bumpmult) + vec3(0.0f, 0.0f, 1.0f - bumpmult);
		return normalize(bump*tbnMatrix);
	}
#endif

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

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
									vec2(-1.,3.)/8.,
									vec2(5.0,1.)/8.,
									vec2(-3,-5.)/8.,
									vec2(-5.,5.)/8.,
									vec2(-7.,-1.)/8.,
									vec2(3,7.)/8.,
									vec2(7.,-7.)/8.);

float bias(){
	return Texture_MipMap_Bias + (blueNoise()-0.5)*0.5;
}

vec4 texture2D_POMSwitch(
	sampler2D sampler, 
	vec2 lightmapCoord,
	vec4 dcdxdcdy, 
	bool ifPOM
){
	if(ifPOM){
		return texture2DGradARB(sampler, lightmapCoord, dcdxdcdy.xy, dcdxdcdy.zw);
	}else{
		return texture2D(sampler, lightmapCoord, bias());
	}
}
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* RENDERTARGETS: 1,7,8,15 */
void main() {


	bool ifPOM = false;

	#ifdef POM
		ifPOM = true;
	#endif

	if(SIGN > 0) ifPOM = false;

	vec3 normal = normalMat.xyz;

	#ifdef MC_NORMAL_MAP
		vec3 tangent2 = normalize(cross(tangent.rgb,normal)*tangent.w);
		mat3 tbnMatrix = mat3(tangent.x, tangent2.x, normal.x,
							  tangent.y, tangent2.y, normal.y,
							  tangent.z, tangent2.z, normal.z);
	#endif

	vec2 tempOffset=offsets[framemod8];

	vec3 fragpos = toScreenSpace(gl_FragCoord.xyz*vec3(texelSize,1.0)-vec3(vec2(tempOffset)*texelSize*0.5,0.0));
	vec3 worldpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz + cameraPosition;


	float torchlightmap = lmtexcoord.z;

	#ifdef Hand_Held_lights
		if(HELD_ITEM_BRIGHTNESS > 0.0) torchlightmap = max(torchlightmap, HELD_ITEM_BRIGHTNESS * clamp( pow(max(1.0-length(fragpos)/10,0.0),1.5),0.0,1.0));
	#endif
	
	float lightmap = clamp( (lmtexcoord.w-0.8) * 10.0,0.,1.);


	vec2 adjustedTexCoord = lmtexcoord.xy;

	#ifdef POM

		adjustedTexCoord = fract(vtexcoord.st)*vtexcoordam.pq+vtexcoordam.st;

		vec3 viewVector = normalize(tbnMatrix*fragpos);
		float dist = length(fragpos);

		gl_FragDepth = gl_FragCoord.z;

		#ifdef WORLD
			if (dist < MAX_OCCLUSION_DISTANCE) {

				float depthmap = readNormal(vtexcoord.st).a;
				float used_POM_DEPTH = 1.0;

		 		if ( viewVector.z < 0.0 && depthmap < 0.9999 && depthmap > 0.00001) {	

					#ifdef Adaptive_Step_length
						vec3 interval = (viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS * POM_DEPTH) * clamp(1.0-pow(depthmap,2),0.1,1.0) ;
						used_POM_DEPTH = 1.0;
					#else
						vec3 interval = viewVector.xyz /-viewVector.z/MAX_OCCLUSION_POINTS*POM_DEPTH;
					#endif
					vec3 coord = vec3(vtexcoord.st, 1.0);

					coord += interval * used_POM_DEPTH;

					float sumVec = 0.5;
					for (int loopCount = 0; (loopCount < MAX_OCCLUSION_POINTS) && (1.0 - POM_DEPTH + POM_DEPTH * readNormal(coord.st).a  ) < coord.p  && coord.p >= 0.0; ++loopCount) {
						coord = coord+interval * used_POM_DEPTH; 
						sumVec += 1.0 * used_POM_DEPTH; 
					}

					if (coord.t < mincoord) {
						if (readTexture(vec2(coord.s,mincoord)).a == 0.0) {
							coord.t = mincoord;
							discard;
						}
					}
					adjustedTexCoord = mix(fract(coord.st)*vtexcoordam.pq+vtexcoordam.st, adjustedTexCoord, max(dist-MIX_OCCLUSION_DISTANCE,0.0)/(MAX_OCCLUSION_DISTANCE-MIX_OCCLUSION_DISTANCE));

					vec3 truePos = fragpos + sumVec*inverse(tbnMatrix)*interval;

					gl_FragDepth = toClipSpace3(truePos).z;
				}
			}
		#endif
	#endif

	if(!ifPOM) adjustedTexCoord = lmtexcoord.xy;

	//////////////////////////////// 
	//////////////////////////////// ALBEDO
	//////////////////////////////// 

	vec4 Albedo = texture2D_POMSwitch(texture, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM) * color;
	if(LIGHTNING > 0) Albedo = vec4(1);

	#ifdef WORLD
		if (Albedo.a > 0.1) Albedo.a = normalMat.a;
		else Albedo.a = 0.0;
	#endif

	#ifdef HAND
		if (Albedo.a > 0.1) Albedo.a = 0.75;
		else Albedo.a = 0.0;
	#endif

	//////////////////////////////// 
	//////////////////////////////// NORMAL
	//////////////////////////////// 

	#ifdef WORLD
		#ifdef MC_NORMAL_MAP
		
			vec4 NormalTex = texture2D_POMSwitch(normals, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM);
			NormalTex.xy = NormalTex.xy*2.0-1.0;
			NormalTex.z = clamp(sqrt(1.0 - dot(NormalTex.xy, NormalTex.xy)),0.0,1.0) ;

			normal = applyBump(tbnMatrix, NormalTex.xyz,  1.0);
		#endif
	#endif

	//////////////////////////////// 
	//////////////////////////////// SPECULAR
	//////////////////////////////// 

	#ifdef WORLD
		vec4 SpecularTex = texture2D_POMSwitch(specular, adjustedTexCoord.xy, vec4(dcdx,dcdy), ifPOM);

		gl_FragData[2].rg = SpecularTex.rg;

		#if EMISSIVE_TYPE == 0
			gl_FragData[2].a = 0.0;
		#endif

		#if EMISSIVE_TYPE == 1
			gl_FragData[2].a = EMISSIVE;
		#endif

		#if EMISSIVE_TYPE == 2
			gl_FragData[2].a = SpecularTex.a;
			if(SpecularTex.a <= 0.0) gl_FragData[2].a = EMISSIVE;
		#endif

		#if EMISSIVE_TYPE == 3		
			gl_FragData[2].a = SpecularTex.a;
		#endif

		#if SSS_TYPE == 0
			gl_FragData[2].b = 0.0;
		#endif

		#if SSS_TYPE == 1
			gl_FragData[2].b = SSSAMOUNT;
		#endif

		#if SSS_TYPE == 2
			gl_FragData[2].b = SpecularTex.b;
			if(SpecularTex.b < 65.0/255.0) gl_FragData[2].b = SSSAMOUNT;
		#endif

		#if SSS_TYPE == 3		
			gl_FragData[2].b = SpecularTex.b;
		#endif

		// hit glow effect...
		#ifdef ENTITIES
			Albedo.rgb = mix(Albedo.rgb, entityColor.rgb, entityColor.a);
			gl_FragData[2].a = mix(gl_FragData[2].a, 0.9, entityColor.a);;
		#endif

	#endif

	//////////////////////////////// 
	//////////////////////////////// FINALIZE
	//////////////////////////////// 

	vec4 data1 = clamp( encode(viewToWorld(normal), (blueNoise()*vec2(torchlightmap,lmtexcoord.w) /	(30.0 * (1+ (1-RENDER_SCALE.x)))		) + vec2(torchlightmap,lmtexcoord.w)),	0.0,	1.0);
	gl_FragData[0] = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w,Albedo.w));

	gl_FragData[1].a = 0.0;

	//////////////////////////////// 
	//////////////////////////////// OTHER STUFF
	//////////////////////////////// 

	#ifdef WORLD
		gl_FragData[3] = vec4(FlatNormals * 0.5 + 0.5,VanillaAO);	
	#endif

	// gl_FragData[4].x = 0;

	// #ifdef ENTITIES
	// 	gl_FragData[4].x = 1;
	// #endif
}