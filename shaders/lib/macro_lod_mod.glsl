#if defined DISTANT_HORIZONS || defined VOXY
    #define USING_LOD_MOD
#endif
#if defined DISTANT_HORIZONS || defined VOXY
    #define USING_LOD_MOD
#endif

#ifdef DISTANT_HORIZONS
    #define LOD_DEPTHBUFFER_OPAQUE dhDepthTex0 
    #define LOD_DEPTHBUFFER_TRANSLUCENT dhDepthTex1
    #define LOD_PROJECTION dhProjection
    #define LOD_PROJECTION_INVERSE dhProjectionInverse
    #define LOD_PROJECTION_PREV dhPreviousProjection
#endif

#ifdef VOXY
    #define LOD_DEPTHBUFFER_OPAQUE vxDepthTexTrans
    #define LOD_DEPTHBUFFER_TRANSLUCENT vxDepthTexOpaque
    #define LOD_PROJECTION vxProj
    #define LOD_PROJECTION_INVERSE vxProjInv
    #define LOD_PROJECTION_PREV vxProjPrev
#endif

uniform sampler2D LOD_DEPTHBUFFER_OPAQUE;
uniform sampler2D LOD_DEPTHBUFFER_TRANSLUCENT;

// the rest are custom uniforms that swap in shaders.properties
uniform float LOD_NEARPLANE;
uniform float LOD_FARPLANE;
uniform int LOD_RENDERDISTANCE;
uniform mat4 LOD_PROJECTION;
uniform mat4 LOD_PROJECTION_INVERSE;
uniform mat4 LOD_PROJECTION_PREV;