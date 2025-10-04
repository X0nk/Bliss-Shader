#include "/lib/res_params.glsl"

void main() {
	gl_Position = ftransform();

	#if TAA_MODE == 3
		gl_Position.xy = (gl_Position.xy*0.5+0.5)*RENDER_SCALE*2.0-1.0;
	#endif
}
