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


/*
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform float far;
uniform mat4 dhProjection;
uniform vec3 cameraPosition;

#define diagonal3(m) vec3((m)[0].x, (m)[1].y, m[2].z)
#define  projMAD(m, v) (diagonal3(m) * (v) + (m)[3].xyz)
vec4 toClipSpace3(vec3 viewSpacePosition) {
    return vec4(projMAD(dhProjection, viewSpacePosition),-viewSpacePosition.z);
}
*/  


void main() {
    gl_Position = ftransform();

	/*
		vec3 position = mat3(gl_ModelViewMatrix) * vec3(gl_Vertex) + gl_ModelViewMatrix[3].xyz;
	    vec3 worldpos = mat3(gbufferModelViewInverse) * position + gbufferModelViewInverse[3].xyz;

		float cellSize = 32*2;
		vec3 modulusWorldPos = vec3(worldpos.x,worldpos.y,worldpos.z) + fract(cameraPosition/cellSize)*cellSize - cellSize*0.5;

		worldpos.y -= (clamp(1.0-length(modulusWorldPos)/max(far-32,0.0),0.0,1.0)) * 50.0;
	    position = mat3(gbufferModelView) * worldpos + gbufferModelView[3].xyz;
		gl_Position = toClipSpace3(position);
	*/

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
	if (dhMaterialId == DH_BLOCK_LEAVES) SSSAMOUNT = 1.0;
	if (dhMaterialId == DH_BLOCK_SNOW) SSSAMOUNT = 0.5;

	// a mask for DH terrain in general.
	float MATERIALS = 0.65;

	normals_and_materials = vec4(normalize(gl_NormalMatrix * gl_Normal), MATERIALS);
}