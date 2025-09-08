#include "/lib/settings.glsl"

varying vec4 color;
varying vec2 texcoord;
uniform sampler2D texture;


//faster and actually more precise than pow 2.2
vec3 toLinear(vec3 sRGB){
	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
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

    #if defined BEACON_BEAM
	    gl_FragData[0] = vec4(Albedo.rgb*Albedo.rgb * 0.1 * 5.0 * Emissive_Brightness, Albedo.a*color.a);
    #endif

    #if defined LIGHTNING_AND_DRAGON_DEATH_BEAMS
        gl_FragData[0] = vec4(Albedo.rgb * pow(1.0-pow(1.0-color.a,2),2) * 5.0 * 0.1, color.a);
    #endif

    #if defined SPIDER_EYES || defined GLOWING 

        if(Albedo.a < 1.0/255.0 || dot(Albedo.rgb, vec3(0.33333)) < 1.0/255.0) { discard; return; }

        #ifdef DISABLE_VANILLA_EMISSIVES
            vec3 emissiveColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 emissiveColor = Albedo.rgb * Albedo.a * Emissive_Brightness;
        #endif
        
	    gl_FragData[0] = vec4(emissiveColor*0.1, 0.000001);
    #endif

    #if defined ENCHANT_GLINT

        #ifdef DISABLE_ENCHANT_GLINT
            vec3 GlintColor = vec3(0.0);
            Albedo.a = 0.0;
        #else
            vec3 GlintColor = Albedo.rgb * 0.2 * Emissive_Brightness;
        #endif

	    gl_FragData[0] = vec4(GlintColor*0.1, 0.000001);
    #endif
}