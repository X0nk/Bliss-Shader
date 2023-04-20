#version 120

varying vec4 lmtexcoord;
varying vec4 color;

uniform sampler2D texture;

//faster and actually more precise than pow 2.2
// vec3 toLinear(vec3 sRGB){
// 	return sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878);
// }

// vec3 viewToWorld(vec3 viewPosition) {
//     vec4 pos;
//     pos.xyz = viewPosition;
//     pos.w = 0.0;
//     pos = gbufferModelViewInverse * pos;
//     return pos.xyz;
// }
// vec3 worldToView(vec3 worldPos) {
//     vec4 pos = vec4(worldPos, 0.0);
//     pos = gbufferModelView * pos;
//     return pos.xyz;
// }
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
/* DRAWBUFFERS:18 */

void main() {

    vec3 albedo = texture2D(texture, lmtexcoord.xy).rgb * color.rgb;



	vec4 data1 = clamp(encode(vec3(0.0), vec2(lmtexcoord.z,1)),	0.0,	1.0);
	gl_FragData[0] = vec4(encodeVec2(albedo.r,data1.x),	encodeVec2(albedo.g,data1.y),	encodeVec2(albedo.b,data1.z),	encodeVec2(data1.w,0.75));

   gl_FragData[1].a = 0.9;
}