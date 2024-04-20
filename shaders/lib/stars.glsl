//Original star code : https://www.shadertoy.com/view/Md2SR3 , optimised



// Return random noise in the range [0.0, 1.0], as a function of x.
float hash12(vec2 p)
{
	vec3 p3  = fract(vec3(p.xyx) * 0.1031);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}
// Convert Noise2d() into a "star field" by stomping everthing below fThreshhold to zero.
float NoisyStarField( in vec2 vSamplePos, float fThreshhold )
{
    float StarVal = hash12( vSamplePos );
        StarVal = clamp(StarVal/(1.0 - fThreshhold) - fThreshhold/(1.0 - fThreshhold),0.0,1.0);

    return StarVal;
}

// Stabilize NoisyStarField() by only sampling at integer values.
float StableStarField( in vec2 vSamplePos, float fThreshhold )
{
    // Linear interpolation between four samples.
    // Note: This approach has some visual artifacts.
    // There must be a better way to "anti alias" the star field.
    float fractX = fract( vSamplePos.x );
    float fractY = fract( vSamplePos.y );
    vec2 floorSample = floor( vSamplePos );
    float v1 = NoisyStarField( floorSample, fThreshhold );
    float v2 = NoisyStarField( floorSample + vec2( 0.0, 1.0 ), fThreshhold );
    float v3 = NoisyStarField( floorSample + vec2( 1.0, 0.0 ), fThreshhold );
    float v4 = NoisyStarField( floorSample + vec2( 1.0, 1.0 ), fThreshhold );

    float StarVal =   v1 * ( 1.0 - fractX ) * ( 1.0 - fractY )
        			+ v2 * ( 1.0 - fractX ) * fractY
        			+ v3 * fractX * ( 1.0 - fractY )
        			+ v4 * fractX * fractY;
	return StarVal;
}

float stars(vec3 viewPos){

	//6 "faces" in 3 axis
	vec2 uv = abs(viewPos.x) > abs(viewPos.y) && abs(viewPos.x) > abs(viewPos.z) ? viewPos.yz : abs(viewPos.y) > abs(viewPos.z) ? viewPos.xz + vec2(1,0) : viewPos.xy + vec2(0,1);
	//together with offsets make sure that every face is unique
	uv = viewPos.x > 0 ? uv : uv + vec2(1,1);
	//scale it down to stars are not too small and too dense
	uv *= 0.5;

	return exp((1.0-StableStarField(uv*1000.,0.999))  * -10) * 3;
	// return StableStarField(uv*1000.,0.999)*0.5*0.3;
}
