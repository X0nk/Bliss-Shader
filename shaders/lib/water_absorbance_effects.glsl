void underWaterAbsorbance_outsidePOV(
    in vec3 playerPos_depthtex0, in vec3 playerPos_depthtex1, in vec3 playerPos_n,
    in vec3 sunVector,
    in vec3 totEpsilon, 
    inout vec3 absorbance, inout vec3 directLightColor, in float lightLeakFix
){  
    // theres 2 absorbances being done here.
    // absorbance for the cameras POV into the water
    // absorbance for the sunlight itself as it travels through the volume to the point it hits a surface, and then the former absorbance is applied on top of that.
    
	// force the absorbance to start way closer to the water surface in low light areas, so the water is visible in caves and such.
	#if MINIMUM_WATER_ABSORBANCE > -1
		float minimumAbsorbance = MINIMUM_WATER_ABSORBANCE*0.1;
	#else
		float minimumAbsorbance	= 1.0 - lightLeakFix;
	#endif

    // get the difference of playerpos with depthtex0 and depthtex1, to get the distance starting at the water surface. 
    float distanceDiff = distance(playerPos_depthtex1, playerPos_depthtex0);
    
    // fix the gradient to be perfectly vertical in meters.
	float estimatedWaterDepth = distanceDiff * abs(playerPos_n.y);
    
    // the distance the sunlight has travelled through water.
    float travelledWaterDepth = estimatedWaterDepth;

	if (isEyeInWater == 1){
        minimumAbsorbance = 0.0;
        estimatedWaterDepth = 1.0;
		travelledWaterDepth = -(playerPos_depthtex1.y + (cameraPosition.y - waterEnteredAltitude));
    }

	absorbance = exp(-totEpsilon * max(distanceDiff, minimumAbsorbance) * WATER_DEPTH_FREQUENCY_ALL_LIGHT);
    if( nightVision > 0.0 ) absorbance += exp(-totEpsilon * 25.0) * nightVision;

	// things to note about sunlight in water
	// sunlight gets absorbed by water on the way down to the floor, and on the way back up to your eye. im gonna ingore the latter part lol
	// based on the angle of the sun, sunlight will travel through more/less water to reach the same spot. scale absorbtion depth accordingly
    vec3 directLightAbsorbance = exp(-totEpsilon * (max(travelledWaterDepth,0.0)/abs(sunVector.y)) * WATER_DEPTH_FREQUENCY_DIRECTLIGHT);
    
    // this is a quick fix for the water depth offset for projecting caustics. the sides of water have unsable water depth info (its the wrong angle) for this usecase, so fallback to a hardcoded height gradient
    if (isEyeInWater == 0) travelledWaterDepth = -(playerPos_depthtex1.y + (cameraPosition.y - 63.0));

    float waterCaustics = waterCaustics(playerPos_depthtex1 + cameraPosition, sunVector, travelledWaterDepth);
        waterCaustics *= WATER_CAUSTICS_BRIGHTNESS;
        waterCaustics = mix(1.0, waterCaustics, clamp(estimatedWaterDepth,0.0,1.0));
        waterCaustics = pow(waterCaustics, WATER_CAUSTICS_POWER);
    
    directLightColor *= directLightAbsorbance * waterCaustics;
}

void underWaterAbsorbance_insidePOV(
    in float linearDistance,
    inout vec3 sceneColor, inout float bloomyFogMult
){
    vec3 totEpsilon = vec3(Water_Absorb_R, Water_Absorb_G, Water_Absorb_B);
	vec3 scatterCoef = Dirt_Amount * vec3(Dirt_Scatter_R, Dirt_Scatter_G, Dirt_Scatter_B) / 3.14;
    
    vec3 transmittance = exp(-totEpsilon * linearDistance * WATER_DEPTH_FREQUENCY_ALL_LIGHT);
    vec3 transmittance2 = exp(-totEpsilon * 50.0);
    float fogfade = 1.0 - max((1.0 - linearDistance / min(far, 16.0*7.0) ),0);

    sceneColor *= transmittance;
    sceneColor += (transmittance2 * scatterCoef) * fogfade * MINIMUM_UNDERWATER_FOG_BRIGHTNESS;
    
    bloomyFogMult *= dot(transmittance,vec3(0.3333))*0.75 + 0.25;
}