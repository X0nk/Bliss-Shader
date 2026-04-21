uniform sampler2D colortex2;
uniform sampler2D colortex14;
uniform sampler2D depthtex1;

/* RENDERTARGETS:2,14 */

void main() {
	// write voxy forward rendered color buffer into vanilla forward rendered color buffer
	vec4 voxyForwardColor = texelFetch(colortex14, ivec2(gl_FragCoord.xy), 0).rgba;

	if(texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r < 1.0) voxyForwardColor = vec4(0.0,0.0,0.0,0.0);

	gl_FragData[0] = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).rgba + voxyForwardColor;

	// clear colortex14 ( nothing is written to it but voxy forward color at this time )
	gl_FragData[1] = vec4(0.0,0.0,0.0,0.0);
}