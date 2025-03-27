// write various parameters within singular pixels of a texture, which is a non-clearing buffer reprojecting the previous frame of itself, onto itself.
// this allows smooth interpolation over time from any old parameter value, to any new parameter value.

// read in vertex stage of post processing passes (deferred, composite), so it only runs on 4 vertices
// pass to fragment stage for use.

// the parameters are stored as such:
// smallCumulus = (coverage, density)
// largeCumulus = (coverage, density)
// altostratus = (coverage, density)
// fog = (uniform fog density, cloudy fog density)
// ... and more, eventually

flat varying struct sceneController {
  vec2 smallCumulus;
  vec2 largeCumulus;
  vec2 altostratus;
  vec2 fog;
} parameters;

vec3 writeSceneControllerParameters(
	vec2 uv,
    vec2 smallCumulus,
	vec2 largeCumulus,
	vec2 altostratus,
	vec2 fog
){

    // in colortex4, data is written in a 3x3 pixel area from (1,1) to (3,3)
    // avoiding use of any variation of (0,0) to avoid weird textture wrapping issues
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
    
    /* (1,3) */ bool topLeft = uv.x > 1 && uv.x < 2 && uv.y > 3 && uv.y < 4;
    /* (2,3) */ bool topMiddle = uv.x > 2 && uv.x < 3 && uv.y > 3 && uv.y < 4;
    // /* (3,3) */ bool topRight = uv.x > 3 && uv.x < 5 && uv.y > 3 && uv.y < 4;
    // /* (1,2) */ bool middleLeft = uv.x > 1 && uv.x < 2 && uv.y > 2 && uv.y < 3;
    // /* (2,2) */ bool middleMiddle = uv.x > 2 && uv.x < 3 && uv.y > 2 && uv.y < 3;
    // /* (3,2) */ bool middleRight = uv.x > 3 && uv.x < 5 && uv.y > 2 && uv.y < 3;
    // /* (1,1) */ bool bottomLeft = uv.x > 1 && uv.x < 2 && uv.y > 1 && uv.y < 2;
    // /* (2,1) */ bool bottomMiddle = uv.x > 2 && uv.x < 3 && uv.y > 1 && uv.y < 2;
    // /* (3,1) */ bool bottomRight = uv.x > 3 && uv.x < 5 && uv.y > 1 && uv.y < 2;

    vec3 data = vec3(0.0,0.0,0.0);

    if(topLeft) data = vec3(smallCumulus.xy, largeCumulus.x);
    if(topMiddle) data = vec3(largeCumulus.y, altostratus.xy);

    // if(topRight)  	 data = vec4(groundSunColor,fogSunColor.r);
    // if(middleLeft)   data = vec4(groundAmbientColor,fogSunColor.g);
    // if(middleMiddle) data = vec4(fogAmbientColor,fogSunColor.b);
    // if(middleRight)  data = vec4(cloudSunColor,cloudAmbientColor.r);
    // if(bottomLeft)   data = vec4(cloudAmbientColor.gb,0.0,0.0);
    // if(bottomMiddle) data = vec4(0.0);
    // if(bottomRight)  data = vec4(0.0);

    return data;
}

void readSceneControllerParameters(
	sampler2D colortex,
	out vec2 smallCumulus,
	out vec2 largeCumulus,
	out vec2 altostratus,
	out vec2 fog
){
    
    // in colortex4, read the data stored within the 3 components of the sampled pixels, and pass it to the fragment stage
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
	vec3 data1 = texelFetch2D(colortex,ivec2(1,3),0).rgb/150.0;
	vec3 data2 = texelFetch2D(colortex,ivec2(2,3),0).rgb/150.0;

	smallCumulus = vec2(data1.x,data1.y);
	largeCumulus = vec2(data1.z,data2.x);
	altostratus = vec2(data2.y,data2.z);
	fog = vec2(0.0);
}