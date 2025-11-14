uniform vec3 lightningEffect;

#ifdef IS_IRIS
    uniform vec4 lightningBoltPosition;
#else
    vec4 lightningBoltPosition = vec4(0.0, 100.0, 0.0, lightningEffect.x);
#endif

vec3 createLightningPointLight(
	vec3 playerPos, vec3 lightningBoltPos

	#if defined LIGHTNINGFLASH_DIFFUSE
		, vec3 normal
	#endif
	#if defined LIGHTNINGFLASH_VL
		,float cloudDensity
		,float gradient
	#endif
){
	if(lightningBoltPosition.w > 0.0){ 
		// make it only get 5x brighter than 1.0 as that is default emissive brightness.
		vec3 flashColor = lightningEffect.rgb * 1.0;
		// flashy flashy
		flashColor *= (sin(lightningEffect.r*10.0)*0.5+0.5)*0.8+0.2;

		vec3 boltPos = playerPos - lightningBoltPos;

		// stretch the vertical component to cover the upper part of the bolt.
		vec3 boltPos_stretched = playerPos - vec3(lightningBoltPos.x, clamp(playerPos.y, lightningBoltPos.y, lightningBoltPos.y+150.0), lightningBoltPos.z);
		float flashDistance = length(boltPos_stretched);
		
		#if defined LIGHTNINGFLASH_DIFFUSE
			// lerp between 2 points for ndotl, for the lower and upper part of the bolt.
			float NdotL = clamp(dot(normalize(boltPos - vec3(0,10,0)), -normal), 0, 1);
			float NdotL2 = clamp(dot(normalize(boltPos - vec3(0,100,0)), -normal),0,1);
			flashColor *= NdotL * (1.0 - NdotL2) + NdotL2;
		
			flashColor *= exp(sqrt(flashDistance) * -0.5) * 15.0 * 3.0 * clamp(1.0-flashDistance/500.,0,1);
		#endif

		#if defined LIGHTNINGFLASH_VL
			flashColor *= (1.0-exp(-3.0*cloudDensity)) * exp(-3.0*(1.0-gradient));
			flashColor *= exp(sqrt(flashDistance) * -0.5) * 15.0 * clamp(1.0-flashDistance/500.,0,1);
		#endif

		return flashColor;
	
	}else return vec3(0.0);
}