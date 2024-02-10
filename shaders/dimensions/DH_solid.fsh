#include "/lib/settings.glsl"


varying vec4 pos;
varying vec4 gcolor;
varying vec2 lightmapCoords;
varying vec4 normals_and_materials;
flat varying float SSSAMOUNT;
flat varying float EMISSIVE;

uniform float far;
// uniform int hideGUI;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;

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

// uniform sampler2D depthtex0;
// uniform vec2 texelSize;


#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)

uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;

vec3 toScreenSpace(vec3 p) {
	vec4 iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);
    vec3 feetPlayerPos = p * 2. - 1.;
    vec4 viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
    return viewPos.xyz / viewPos.w;
}

uniform sampler2D noisetex;
uniform int frameCounter;
uniform float frameTimeCounter;
float blueNoise(){
  return fract(texelFetch2D(noisetex, ivec2(gl_FragCoord.xy)%512, 0).a + 1.0/1.6180339887 * frameCounter);
}
float interleaved_gradientNoise(){
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
}
float R2_dither(){
	vec2 coord = gl_FragCoord.xy + (frameCounter%40000) * 2.0;
	vec2 alpha = vec2(0.75487765, 0.56984026);
	return fract(alpha.x * coord.x + alpha.y * coord.y ) ;
}

/* RENDERTARGETS:1,7,8 */
void main() {
    // overdraw prevention
    if(clamp(1.0-length(pos.xyz)/max(far - 16.0,0.0),0.0,1.0) > 0.0 ){
        discard;
        return;
    }

    vec3 normals = viewToWorld(normals_and_materials.xyz);
    float materials = normals_and_materials.a;
    
    vec4 data1 = clamp( encode(normals.xyz, vec2(lightmapCoords)), 0.0, 1.0);
    
    // alpha is material masks, set it to 0.65 to make a DH LODs mask. 
    vec4 Albedo = vec4(gcolor.rgb, 1.0);
 
    #ifdef WhiteWorld
        Albedo.rgb = vec3(0.5);
    #endif
    
    gl_FragData[0] = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w, materials));
    
	gl_FragData[1].a = 0.0;
    
	#if EMISSIVE_TYPE == 0
		gl_FragData[2].a = 0.0;
	#else
		gl_FragData[2].a = EMISSIVE;
	#endif

	#if SSS_TYPE == 0
		gl_FragData[2].b = 0.0;
	#else
		gl_FragData[2].b = SSSAMOUNT;
	#endif
    
}