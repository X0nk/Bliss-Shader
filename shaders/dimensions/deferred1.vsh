#include "/lib/settings.glsl"

uniform vec2 texelSize;
#include "/lib/res_params.glsl"
void main() {
	gl_Position = ftransform();
	vec2 scaleRatio = max(vec2(0.25), vec2(18.+258*2,258.)*texelSize);
	gl_Position.xy = (gl_Position.xy*0.5+0.5)*clamp(scaleRatio+0.01,0.0,1.0)*2.0-1.0;
}
