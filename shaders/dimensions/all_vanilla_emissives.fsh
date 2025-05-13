#include "/lib/settings.glsl"

varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D noisetex;

varying vec4 tangent;
varying vec4 normalMat;
uniform float frameTimeCounter;

//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
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

uniform mat4 gbufferModelViewInverse;

vec3 viewToWorld(vec3 viewPos) {
    vec4 pos;
    pos.xyz = viewPos;
    pos.w = 0.0;
    pos = gbufferModelViewInverse * pos;
    return pos.xyz;
}

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////

/* DRAWBUFFERS:2 */

void main() {

	vec4 Albedo = texture2D(texture, texcoord);
	Albedo.rgb = toLinear(Albedo.rgb * color.rgb);

    #if defined SPIDER_EYES || defined BEACON_BEAM || defined GLOWING 

        if(Albedo.a < 0.102 || dot(Albedo.rgb, vec3(0.33333)) < 1.0/255.0) { discard; return; }

        float minimumBrightness = 0.5;

        #ifdef BEACON_BEAM
            minimumBrightness = 10.0;
        #endif

        #ifdef DISABLE_VANILLA_EMISSIVES
            vec3 emissiveColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 emissiveColor =  Albedo.rgb * color.a ;//* autoBrightnessAdjust;
        #endif
        
	    gl_FragData[0] = vec4(emissiveColor*0.1, Albedo.a * sqrt(color.a));
    #endif

    #ifdef ENCHANT_GLINT

        Albedo.rgb = clamp(Albedo.rgb ,0.0,1.0); // for safety

        #ifdef DISABLE_ENCHANT_GLINT
            vec3 GlintColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 GlintColor = Albedo.rgb * Emissive_Brightness;
        #endif

	    gl_FragData[0] = vec4(GlintColor*0.1, dot(Albedo.rgb,vec3(0.333)) * Albedo.a  );
    #endif
}