varying vec4 color;
varying vec2 texcoord;

uniform sampler2D texture;

flat varying float exposure;

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

//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
//////////////////////////////VOID MAIN//////////////////////////////
#if defined SPIDER_EYES || defined BEACON_BEAM || defined GLOWING
    /* DRAWBUFFERS:1 */
#endif

#ifdef ENCHANT_GLINT
	/* DRAWBUFFERS:2 */
#endif

void main() {

	vec4 Albedo = texture2D(texture, texcoord);

    #if defined SPIDER_EYES || defined BEACON_BEAM || defined GLOWING 
        vec4 data1 = vec4(1.0); float materialMask = 1.0;

        #if defined SPIDER_EYES || defined GLOWING
            if(Albedo.a < 0.1) discard;
            Albedo.rgb *= color.a;
        #endif

        #ifdef BEACON_BEAM
            Albedo.rgb = Albedo.rgb * color.rgb;
            materialMask = 0.75;
        #endif

	    gl_FragData[0] = vec4(encodeVec2(Albedo.x,data1.x),	encodeVec2(Albedo.y,data1.y),	encodeVec2(Albedo.z,data1.z),	encodeVec2(data1.w, materialMask));
    #endif

    #ifdef ENCHANT_GLINT
        vec3 GlintColor = toLinear(Albedo.rgb * color.rgb) / clamp(exposure,0.01,1.0);

	    gl_FragData[0] = vec4(GlintColor , Albedo.a * 0.1);
    #endif
}