#include "/lib/settings.glsl"
#include "/lib/res_params.glsl"

varying vec4 pos;
varying vec4 gcolor;
varying vec2 lightmapCoords;
varying vec4 normals_and_materials;
flat varying float SSSAMOUNT;
flat varying float EMISSIVE;

uniform vec2 texelSize;
uniform int framemod8;

const vec2[8] offsets = vec2[8](vec2(1./8.,-3./8.),
							vec2(-1.,3.)/8.,
							vec2(5.0,1.)/8.,
							vec2(-3,-5.)/8.,
							vec2(-5.,5.)/8.,
							vec2(-7.,-1.)/8.,
							vec2(3,7.)/8.,
							vec2(7.,-7.)/8.);
                            
void main() {
    gl_Position = ftransform();
    
	#ifdef TAA_UPSCALING
		gl_Position.xy = gl_Position.xy * RENDER_SCALE + RENDER_SCALE * gl_Position.w - gl_Position.w;
	#endif
    #ifdef TAA
		gl_Position.xy += offsets[framemod8] * gl_Position.w*texelSize;
	#endif
	
	lightmapCoords = gl_MultiTexCoord1.xy * 0.975; // is this even correct? lol'
    
    gcolor = gl_Color;
    pos = gl_ModelViewMatrix * gl_Vertex;

	EMISSIVE = 0.0;
	if(dhMaterialId == DH_BLOCK_ILLUMINATED || gl_MultiTexCoord1.x >= 0.95) EMISSIVE = 0.5;

	SSSAMOUNT = 0.0;
	if (dhMaterialId == DH_BLOCK_LEAVES ) SSSAMOUNT = 1.0;
	if (dhMaterialId == DH_BLOCK_SNOW) SSSAMOUNT = 0.5;

	// a mask for DH terrain in general.
	float MATERIALS = 0.65;

	normals_and_materials = vec4(normalize(gl_NormalMatrix * gl_Normal), MATERIALS);
}