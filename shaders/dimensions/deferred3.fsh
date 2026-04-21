uniform sampler2D colortex2;
uniform sampler2D depthtex1;

/* RENDERTARGETS:2 */

void main() {
	// re-write contents back to the buffer so as to not lose anything
	gl_FragData[0] = texelFetch(colortex2, ivec2(gl_FragCoord.xy), 0).rgba;

	if(texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r < 1.0) gl_FragData[0] = vec4(0.0);
}