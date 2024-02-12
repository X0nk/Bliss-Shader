/////// ALL OF THIS IS BASED OFF OF THE DISTANT HORIZONS EXAMPLE PACK BY NULL

uniform mat4 dhPreviousProjection;
uniform mat4 dhProjectionInverse;
uniform mat4 dhProjection;

vec3 toScreenSpace_DH( vec2 texcoord, float depth, float DHdepth ) {

	vec4 viewPos = vec4(0.0);
	vec3 feetPlayerPos = vec3(0.0);
	vec4 iProjDiag = vec4(0.0);

	#ifdef DISTANT_HORIZONS
    	if (depth < 1.0) {
	#endif
			iProjDiag = vec4(gbufferProjectionInverse[0].x, gbufferProjectionInverse[1].y, gbufferProjectionInverse[2].zw);

    		feetPlayerPos = vec3(texcoord, depth) * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + gbufferProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
	
	#ifdef DISTANT_HORIZONS
		} else {
			iProjDiag = vec4(dhProjectionInverse[0].x, dhProjectionInverse[1].y, dhProjectionInverse[2].zw);

    		feetPlayerPos = vec3(texcoord, DHdepth) * 2.0 - 1.0;
    		viewPos = iProjDiag * feetPlayerPos.xyzz + dhProjectionInverse[3];
			viewPos.xyz /= viewPos.w;
		}
	#endif

    return viewPos.xyz;
}
vec3 toClipSpace3_DH( vec3 viewSpacePosition, bool depthCheck ) {

	#ifdef DISTANT_HORIZONS
		mat4 projectionMatrix = depthCheck ? dhProjection : gbufferProjection;
   		return projMAD(projectionMatrix, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#else
    	return projMAD(gbufferProjection, viewSpacePosition) / -viewSpacePosition.z * 0.5 + 0.5;
	#endif

}

mat4 DH_shadowProjectionTweak( in mat4 projection){
	
	#ifdef DH_SHADOWPROJECTIONTWEAK
		
		float _far = (3.0 * far);

		#ifdef DISTANT_HORIZONS
		    _far = 2.0 * dhFarPlane;
		#endif
		
		mat4 newProjection = projection;
		newProjection[2][2] = -2.0 / _far;
		newProjection[3][2] = 0.0;

		return newProjection;
	#else
		return projection;
	#endif
}
