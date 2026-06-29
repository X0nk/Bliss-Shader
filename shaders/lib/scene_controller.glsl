#if !defined READ_SCENE_CONTROLLER_PARAMETERS
#if defined USE_SCENE_CONTROLLER_SETTINGS

uniform int worldDay;
uniform ivec3 cameraPositionInt;

uniform bool isInColdArea;
uniform bool isInHotArea;
uniform bool isInJungleBiomes;
uniform bool isInSwampBiomes;
uniform bool isInPaleGardenBiomes;
uniform bool isInSpecialEnviornment;
uniform bool isInSnowFallEnviornment;
uniform bool isInRainFallEnviornment;
uniform bool isInNoRainFallEnviornment;

uniform int worldTime;

#define DECLARE_UNIFORMS_OR_WRITE_FUNCTIONS_FOR_CUSTOM_SCENE_CONTROLLER_PROFILES
#include "/CUSTOM_SCENE_PARAMETERS.glsl"

// https://www.shadertoy.com/view/llGSzw
float hash11( uint n ) 
{
    // integer hash copied from Hugo Elias
	n = (n << 13U) ^ n;
    n = n * (n * n * 15731U + 789221U) + 1376312589U;
    return float( n & uint(0x7fffffffU))/float(0x7fffffff);
}
bool playerIsWithinArea(in vec3 positionA, in vec3 positionB){
    return cameraPositionInt.x > positionA.x && cameraPositionInt.y > positionA.y && cameraPositionInt.z > positionA.z && cameraPositionInt.x < positionB.x && cameraPositionInt.y < positionB.y && cameraPositionInt.z < positionB.z; 
}
bool playerIsOutsideArea(in vec3 positionA, in vec3 positionB){
    return !(cameraPositionInt.x > positionA.x && cameraPositionInt.y > positionA.y && cameraPositionInt.z > positionA.z && cameraPositionInt.x < positionB.x && cameraPositionInt.y < positionB.y && cameraPositionInt.z < positionB.z); 
}
vec4 timesOfDay(){

	float time = float(worldTime%24000);

	// set schedules for fog to appear at specific ranges of time in the day.
	float morning = clamp((time-22000.0)/2000.0,0.0,1.0) + clamp((2000.0-time)/2000.0,0.0,1.0);
	float noon 	  = clamp(time/2000.0,0.0,1.0) * clamp((12000.0-time)/2000.0,0.0,1.0);
	float evening = clamp((time-10000.0)/2000.0,0.0,1.0) * clamp((14000.0-time)/2000.0,0.0,1.0);
	float night   = clamp((time-13000.0)/2000.0,0.0,1.0) * clamp((23000.0-time)/2000.0,0.0,1.0);

    return (float(TOD_FOG_AMOUNT) / 100.0) * vec4(morning, noon, evening, night);
}
void applySceneControllerParameters(
	out float smallCumulusCoverage, out float smallCumulusDensity,
	out float largeCumulusCoverage, out float largeCumulusDensity,
	out float altostratusCoverage, out float altostratusDensity,
	out float uniformFogDensity, out float clumpyFogDensity,
    out float LocalUniformFogDensity, out float LocalClumpyFogDensity, out vec3 localFogColor
){
    // these are the default parameters if no "trigger" or custom uniform is being used.
    // do not remove them
    smallCumulusCoverage = 0.0;
	smallCumulusDensity = 0.0;
	largeCumulusCoverage = 0.0;
    largeCumulusDensity = 0.0;
	altostratusCoverage = 0.0;
    altostratusDensity = 0.0;
	uniformFogDensity = 0.0;
    clumpyFogDensity = 0.0;
    LocalUniformFogDensity = 0.0;
    LocalClumpyFogDensity = 0.0;
    localFogColor = vec3(1.0);

#if TOD_FOG_AMOUNT > 0
    vec4 timesOfDay = timesOfDay();
    uniformFogDensity = dot(timesOfDay, vec4(Morning_Uniform_Fog, Noon_Uniform_Fog, Evening_Uniform_Fog, Night_Uniform_Fog));
    clumpyFogDensity = dot(timesOfDay, vec4(Morning_Cloudy_Fog, Noon_Cloudy_Fog, Evening_Cloudy_Fog, Night_Cloudy_Fog));
#endif

// the seed is the in-game day counter. 
// give a random value within the range 0.0-1.0 which is scaled up to the wanted range, and then quantized to choose a profile
float RNG = hash11(worldDay + 0.2);

#if USE_CUSTOM_DAILY_WEATHER_PROFILE == 0
    int dailyWeatherProfile = int(RNG * 11.0);
    switch (dailyWeatherProfile){
        default : {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.0;
            smallCumulusDensity = 0.0;
            break;
        }
        case 1: {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 1.0;
            smallCumulusCoverage = 1.0;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.5;
            smallCumulusDensity = 0.25;
            break;
        }
        case 2: {
            altostratusCoverage = 1.0;
            largeCumulusCoverage = 1.0;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.5;
            largeCumulusDensity = 0.5;
            smallCumulusDensity = 0.0;
            break;
        }
        case 3: {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 1.1;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.5;
            smallCumulusDensity = 0.0;
            break;
        }
        case 4: {
            altostratusCoverage = 1.5;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 1.0;

            altostratusDensity = 0.25;
            largeCumulusDensity = 0.1;
            smallCumulusDensity = 0.1;
            break;
        }
        case 5 : {
            altostratusCoverage = 1.0;
            largeCumulusCoverage = 0.1;
            smallCumulusCoverage = 1.0;

            altostratusDensity = 0.1;
            largeCumulusDensity = 0.5;
            smallCumulusDensity = 0.5;
            break;
        }
        case 6: {
            altostratusCoverage = 1.0;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.5;
            largeCumulusDensity = 0.0;
            smallCumulusDensity = 0.0;
            break;
        }
        case 7: {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 1.9;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.2;
            smallCumulusDensity = 0.0;
            break;
        }
        case 8: {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 1.4;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.0;
            smallCumulusDensity = 0.5;
            break;
        }
        case 9: {
            altostratusCoverage = 2.0;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 0.0;

            altostratusDensity = 0.3;
            largeCumulusDensity = 0.0;
            smallCumulusDensity = 0.0;
            break;
        }
        case 10: {
            altostratusCoverage = 0.0;
            largeCumulusCoverage = 0.0;
            smallCumulusCoverage = 1.0;

            altostratusDensity = 0.0;
            largeCumulusDensity = 0.0;
            smallCumulusDensity = 0.5;
            break;
        }
    }
#endif
#if USE_CUSTOM_DAILY_WEATHER_PROFILE > 0
    int customDailyWeatherProfile = int(RNG * float(USE_CUSTOM_DAILY_WEATHER_PROFILE));
    switch (customDailyWeatherProfile){
        default : {
            smallCumulusCoverage = DAILY_PROFILE_1_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_1_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_1_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_1_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_1_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_1_LAYER2_DENSITY;
            break;
        }
    #if USE_CUSTOM_DAILY_WEATHER_PROFILE >= 2
        case 1: {
            smallCumulusCoverage = DAILY_PROFILE_2_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_2_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_2_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_2_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_2_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_2_LAYER2_DENSITY;
            break;
        }
    #endif
    #if USE_CUSTOM_DAILY_WEATHER_PROFILE >= 3
        case 2: {
            smallCumulusCoverage = DAILY_PROFILE_3_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_3_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_3_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_3_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_3_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_3_LAYER2_DENSITY;
            break;
        }
    #endif
    #if USE_CUSTOM_DAILY_WEATHER_PROFILE >= 4
        case 3: {
            smallCumulusCoverage = DAILY_PROFILE_4_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_4_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_4_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_4_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_4_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_4_LAYER2_DENSITY;
            break;
        }
    #endif
    #if USE_CUSTOM_DAILY_WEATHER_PROFILE >= 5
        case 4: {
            smallCumulusCoverage = DAILY_PROFILE_5_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_5_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_5_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_5_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_5_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_5_LAYER2_DENSITY;
            break;
        }
    #endif
    #if USE_CUSTOM_DAILY_WEATHER_PROFILE >= 6
        case 5 : {
            smallCumulusCoverage = DAILY_PROFILE_6_LAYER0_COVERAGE;
            largeCumulusCoverage = DAILY_PROFILE_6_LAYER1_COVERAGE;
            altostratusCoverage =  DAILY_PROFILE_6_LAYER2_COVERAGE;
            smallCumulusDensity =  DAILY_PROFILE_6_LAYER0_DENSITY;
            largeCumulusDensity =  DAILY_PROFILE_6_LAYER1_DENSITY;
            altostratusDensity =   DAILY_PROFILE_6_LAYER2_DENSITY;
            break;
        }
    #endif
    }
#endif

if(rainStrength > 0.0001){
    #if USE_CUSTOM_DAILY_RAIN_PROFILE == 0
        int rainyWeatherProfile = int(RNG * 6.0);

        switch (rainyWeatherProfile){
            ///////////////////////// TEMPERATE WEATHER PROFILES
            default : { // light rain
                smallCumulusCoverage = 1.5;
                smallCumulusDensity = 0.25;
	            largeCumulusCoverage = 0.0;
	            altostratusCoverage = 2.0;
	            altostratusDensity = 0.1;

	            uniformFogDensity = 0.1;
                clumpyFogDensity = 0.2;
                break;
            }
            case 1: { // medium rain
                smallCumulusCoverage = 0.0;
	            largeCumulusCoverage = 1.5;
                largeCumulusDensity = 0.25;
	            altostratusCoverage = 1.5;
	            altostratusDensity = 0.5;

	            uniformFogDensity = 0.2;
                clumpyFogDensity = 0.4;
                break;
            }
            case 2: { // heavy rain
                smallCumulusCoverage = 1.5;
                smallCumulusDensity = 0.25;
	            largeCumulusCoverage = 1.5;
                largeCumulusDensity = 0.25;
	            altostratusCoverage = 1.3;
	            altostratusDensity = 0.5;

	            uniformFogDensity = 0.3;
                clumpyFogDensity = 0.2;
                break;
            }
            case 3: { // heavy rain
                smallCumulusCoverage = 1.5;
                smallCumulusDensity = 0.25;
	            largeCumulusCoverage = 1.5;
                largeCumulusDensity = 0.25;
	            altostratusCoverage = 1.3;
	            altostratusDensity = 0.5;

	            uniformFogDensity = 0.1;
                clumpyFogDensity = 0.2;
                break;
            }
            case 4: { // medium rain
                smallCumulusCoverage = 0.0;
	            largeCumulusCoverage = 1.5;
                largeCumulusDensity = 0.25;
	            altostratusCoverage = 2.0;
	            altostratusDensity = 0.3;

	            uniformFogDensity = 0.1;
                clumpyFogDensity = 0.2;
                break;
            }
            case 5: { // light rain
                smallCumulusCoverage = 0.0;
	            largeCumulusCoverage = 1.8;
                largeCumulusDensity = 0.1;
	            altostratusCoverage = 0.0;

	            uniformFogDensity = 0.1;
                clumpyFogDensity = 0.2;
                break;
            }
        }
    #endif
    #if USE_CUSTOM_DAILY_RAIN_PROFILE > 0
        int customRainyWeatherProfile = int(RNG * USE_CUSTOM_DAILY_RAIN_PROFILE);

        switch (customRainyWeatherProfile){
            default : {
                smallCumulusCoverage = RAINY_PROFILE_1_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_1_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_1_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_1_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_1_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_1_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_1_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_1_CLUMPY_FOG_DENSITY;
                break;
            }
        #if USE_CUSTOM_DAILY_RAIN_PROFILE >= 2
            case 1: {
                smallCumulusCoverage = RAINY_PROFILE_2_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_2_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_2_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_2_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_2_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_2_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_2_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_2_CLUMPY_FOG_DENSITY;
                break;
            }
        #endif
        #if USE_CUSTOM_DAILY_RAIN_PROFILE >= 3
            case 2: {
                smallCumulusCoverage = RAINY_PROFILE_3_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_3_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_3_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_3_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_3_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_3_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_3_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_3_CLUMPY_FOG_DENSITY;
                break;
            }
        #endif
        #if USE_CUSTOM_DAILY_RAIN_PROFILE >= 4
            case 3: {
                smallCumulusCoverage = RAINY_PROFILE_4_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_4_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_4_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_4_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_4_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_4_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_4_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_4_CLUMPY_FOG_DENSITY;
                break;
            }
        #endif
        #if USE_CUSTOM_DAILY_RAIN_PROFILE >= 5
            case 4: {
                smallCumulusCoverage = RAINY_PROFILE_5_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_5_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_5_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_5_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_5_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_5_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_5_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_5_CLUMPY_FOG_DENSITY;
                break;
            }
        #endif
        #if USE_CUSTOM_DAILY_RAIN_PROFILE >= 6
            case 5 : {
                smallCumulusCoverage = RAINY_PROFILE_6_LAYER0_COVERAGE;
                largeCumulusCoverage = RAINY_PROFILE_6_LAYER1_COVERAGE;
                altostratusCoverage =  RAINY_PROFILE_6_LAYER2_COVERAGE;
                smallCumulusDensity =  RAINY_PROFILE_6_LAYER0_DENSITY;
                largeCumulusDensity =  RAINY_PROFILE_6_LAYER1_DENSITY;
                altostratusDensity =   RAINY_PROFILE_6_LAYER2_DENSITY;
	            uniformFogDensity =    RAINY_PROFILE_6_UNIFORM_FOG_DENSITY;
                clumpyFogDensity =     RAINY_PROFILE_6_CLUMPY_FOG_DENSITY;
                break;
            }
        #endif
        }
    #endif

    #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE == 0 || USE_CUSTOM_COLD_BIOME_RAIN_PROFILE == 0
        // simply shift the index ahead for enviornment switching
        int biomeRainyWeatherProfile = int(RNG * 3.0);
        
        #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE == 0
            if(isInHotArea && isInNoRainFallEnviornment) biomeRainyWeatherProfile += 3;
        #endif
        #if USE_CUSTOM_COLD_BIOME_RAIN_PROFILE == 0
            if(isInColdArea && isInSnowFallEnviornment) biomeRainyWeatherProfile += 6;
        #endif

        switch (biomeRainyWeatherProfile){
            default : {
                break;
            }
            #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE == 0
                case 3: {  // clear
	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
                case 4: { // dust storm
                    LocalUniformFogDensity = 0.03;
                    LocalClumpyFogDensity = 0.2;
                    localFogColor = vec3(1.0,0.5,0.3);

	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
                case 5: { // sand storm
                    LocalUniformFogDensity = 0.08;
                    LocalClumpyFogDensity = 0.5;
                    localFogColor = vec3(1.0,0.3,0.1)*2.0;

	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
            #endif
            #if USE_CUSTOM_COLD_BIOME_RAIN_PROFILE == 0
                case 6: { // light snow
                    LocalUniformFogDensity = 0.0085;
                    LocalClumpyFogDensity = 0.0;
                    localFogColor = vec3(0.4,0.6,1.0) * 5.0;

	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
                case 7: { // snow storm
                    LocalUniformFogDensity = 0.03;
                    LocalClumpyFogDensity = 0.2;
                    localFogColor = vec3(0.4,0.6,1.0) * 5.0;

	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
                case 8: { // blizzard
                    LocalUniformFogDensity = 0.07;
                    LocalClumpyFogDensity = 0.3;
                    localFogColor = vec3(0.4,0.6,1.0) * 5.0;

	                uniformFogDensity = 0.0;
                    clumpyFogDensity = 0.0;
                    break;
                }
            #endif
        }
    #endif
    #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE > 0
        if(isInHotArea && isInNoRainFallEnviornment){
	        uniformFogDensity = 0.0;
            clumpyFogDensity = 0.0;

            int customHotBiomeRainyWeatherProfile = int(RNG * USE_CUSTOM_HOT_BIOME_RAIN_PROFILE);

            switch (customHotBiomeRainyWeatherProfile){
                default : {
                    LocalUniformFogDensity = HOT_BIOME_RAINY_PROFILE_1_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = HOT_BIOME_RAINY_PROFILE_1_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(HOT_BIOME_RAINY_PROFILE_1_FOG_COLOR_R, HOT_BIOME_RAINY_PROFILE_1_FOG_COLOR_G, HOT_BIOME_RAINY_PROFILE_1_FOG_COLOR_B);
                    break;
                }
            #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE >= 2
                case 1: {
                    LocalUniformFogDensity = HOT_BIOME_RAINY_PROFILE_2_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = HOT_BIOME_RAINY_PROFILE_2_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(HOT_BIOME_RAINY_PROFILE_2_FOG_COLOR_R, HOT_BIOME_RAINY_PROFILE_2_FOG_COLOR_G, HOT_BIOME_RAINY_PROFILE_2_FOG_COLOR_B);
                    break;
                }
            #endif
            #if USE_CUSTOM_HOT_BIOME_RAIN_PROFILE >= 3
                case 2: {
                    LocalUniformFogDensity = HOT_BIOME_RAINY_PROFILE_3_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = HOT_BIOME_RAINY_PROFILE_3_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(HOT_BIOME_RAINY_PROFILE_3_FOG_COLOR_R, HOT_BIOME_RAINY_PROFILE_3_FOG_COLOR_G, HOT_BIOME_RAINY_PROFILE_3_FOG_COLOR_B);
                    break;
                }
            #endif
            }
        }
    #endif
    #if USE_CUSTOM_COLD_BIOME_RAIN_PROFILE > 0
        if(isInColdArea && isInSnowFallEnviornment){
	        uniformFogDensity = 0.0;
            clumpyFogDensity = 0.0;

            int customHotBiomeRainyWeatherProfile = int(RNG * USE_CUSTOM_COLD_BIOME_RAIN_PROFILE);
            
            switch (customHotBiomeRainyWeatherProfile){
                default : {
                    LocalUniformFogDensity = COLD_BIOME_RAINY_PROFILE_1_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = COLD_BIOME_RAINY_PROFILE_1_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(COLD_BIOME_RAINY_PROFILE_1_FOG_COLOR_R, COLD_BIOME_RAINY_PROFILE_1_FOG_COLOR_G, COLD_BIOME_RAINY_PROFILE_1_FOG_COLOR_B);
                    break;
                }
            #if USE_CUSTOM_COLD_BIOME_RAIN_PROFILE >= 2
                case 1: {
                    LocalUniformFogDensity = COLD_BIOME_RAINY_PROFILE_2_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = COLD_BIOME_RAINY_PROFILE_2_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(COLD_BIOME_RAINY_PROFILE_2_FOG_COLOR_R, COLD_BIOME_RAINY_PROFILE_2_FOG_COLOR_G, HCOLDBIOME_RAINY_PROFILE_2_FOG_COLOR_B);
                    break;
                }
            #endif
            #if USE_CUSTOM_COLD_BIOME_RAIN_PROFILE >= 3
                case 2: {
                    LocalUniformFogDensity = COLD_BIOME_RAINY_PROFILE_3_UNIFORM_FOG_DENSITY;
                    LocalClumpyFogDensity = COLD_BIOME_RAINY_PROFILE_3_CLUMPY_FOG_DENSITY;
                    localFogColor = vec3(HCOLDBIOME_RAINY_PROFILE_3_FOG_COLOR_R, COLD_BIOME_RAINY_PROFILE_3_FOG_COLOR_G, COLD_BIOME_RAINY_PROFILE_3_FOG_COLOR_B);
                    break;
                }
            #endif
            }
        }
    #endif
}
#if USE_CUSTOM_SWAMP_CATEGORY_PROFILE == 0
    if(isInSwampBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;

        LocalUniformFogDensity = 0.01;
        LocalClumpyFogDensity = 0.05;
        localFogColor = vec3(0.9,1.0,0.3);
    }
#endif
#if USE_CUSTOM_SWAMP_CATEGORY_PROFILE == 1
    if(isInSwampBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;

        LocalUniformFogDensity = CUSTOM_SWAMP_PROFILE_UNIFORM_FOG_DENSITY;
        LocalClumpyFogDensity = CUSTOM_SWAMP_PROFILE_CLUMPY_FOG_DENSITY;
        localFogColor = vec3(CUSTOM_SWAMP_PROFILE_FOG_COLOR_R, CUSTOM_SWAMP_PROFILE_FOG_COLOR_G, CUSTOM_SWAMP_PROFILE_FOG_COLOR_B);
    }
#endif
#if USE_CUSTOM_JUNGLE_CATEGORY_PROFILE == 0
    if(isInJungleBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;
        
        LocalUniformFogDensity = 0.01;
        LocalClumpyFogDensity = 0.0;
        localFogColor = vec3(0.5,1.0,0.8);
    }
#endif
#if USE_CUSTOM_JUNGLE_CATEGORY_PROFILE == 1
    if(isInJungleBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;

        LocalUniformFogDensity = CUSTOM_JUNGLE_PROFILE_UNIFORM_FOG_DENSITY;
        LocalClumpyFogDensity = CUSTOM_JUNGLE_PROFILE_CLUMPY_FOG_DENSITY;
        localFogColor = vec3(CUSTOM_JUNGLE_PROFILE_FOG_COLOR_R, CUSTOM_JUNGLE_PROFILE_FOG_COLOR_G, CUSTOM_JUNGLE_PROFILE_FOG_COLOR_B);
    }
#endif
#if USE_CUSTOM_PALE_GARDEN_PROFILE == 0
    if(isInPaleGardenBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;
        
        LocalUniformFogDensity = 0.07;
        LocalClumpyFogDensity = 0.0;
        localFogColor = vec3(0.9,1.0,0.8)*0.2;
    }
#endif
#if USE_CUSTOM_PALE_GARDEN_PROFILE == 1
    if(isInPaleGardenBiomes){
	    uniformFogDensity = 0.0;
        clumpyFogDensity = 0.0;

        LocalUniformFogDensity = CUSTOM_PALE_GARDEN_PROFILE_UNIFORM_FOG_DENSITY;
        LocalClumpyFogDensity = CUSTOM_PALE_GARDEN_PROFILE_CLUMPY_FOG_DENSITY;
        localFogColor = vec3(CUSTOM_PALE_GARDEN_PROFILE_FOG_COLOR_R, CUSTOM_PALE_GARDEN_PROFILE_FOG_COLOR_G, CUSTOM_PALE_GARDEN_PROFILE_FOG_COLOR_B);
    }
#endif


#define WRITE_CUSTOM_SCENE_CONTROLLER_PROFILES
#undef DECLARE_UNIFORMS_OR_WRITE_FUNCTIONS_FOR_CUSTOM_SCENE_CONTROLLER_PROFILES
#include "/CUSTOM_SCENE_PARAMETERS.glsl"

}
#endif

flat varying struct sceneController {
  vec2 smallCumulus;
  vec2 largeCumulus;
  vec2 altostratus;
  vec2 fog;
  vec2 localFog;
  vec3 localFogColor;
} parameters;

vec3 writeSceneControllerParameters(
	vec2 uv,
    vec2 smallCumulus,
	vec2 largeCumulus,
	vec2 altostratus,
	vec2 fog,
    vec2 localFog,
    vec3 localFogColor
){

    // in colortex4, data is written in a 3x3 pixel area from (1,1) to (3,3)
    // avoiding use of any variation of (0,0) to avoid weird textture wrapping issues
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
    
    /* (1,3) */ bool topLeft = uv.x > 1 && uv.x < 2 && uv.y > 3 && uv.y < 4;
    /* (2,3) */ bool topMiddle = uv.x > 2 && uv.x < 3 && uv.y > 3 && uv.y < 4;
    /* (3,3) */ bool topRight = uv.x > 3 && uv.x < 5 && uv.y > 3 && uv.y < 4;
    /* (1,2) */ bool middleLeft = uv.x > 1 && uv.x < 2 && uv.y > 2 && uv.y < 3;
    /* (2,2) */ bool middleMiddle = uv.x > 2 && uv.x < 3 && uv.y > 2 && uv.y < 3;
    // /* (3,2) */ bool middleRight = uv.x > 3 && uv.x < 5 && uv.y > 2 && uv.y < 3;
    // /* (1,1) */ bool bottomLeft = uv.x > 1 && uv.x < 2 && uv.y > 1 && uv.y < 2;
    // /* (2,1) */ bool bottomMiddle = uv.x > 2 && uv.x < 3 && uv.y > 1 && uv.y < 2;
    // /* (3,1) */ bool bottomRight = uv.x > 3 && uv.x < 5 && uv.y > 1 && uv.y < 2;

    vec3 data = vec3(0.0,0.0,0.0);

    if(topLeft) data = vec3(smallCumulus.xy, largeCumulus.x);
    if(topMiddle) data = vec3(largeCumulus.y, altostratus.xy);
    if(topRight) data = vec3(fog.xy, localFog.x);
    if(middleLeft) data = vec3(localFog.y, 0.0, 0.0);
    if(middleMiddle) data = vec3(localFogColor.rgb);
    

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
	out vec2 fog,
    out vec2 localFog,
    out vec3 localFogColor
){
    
    // in colortex4, read the data stored within the 3 components of the sampled pixels, and pass it to the fragment stage
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
	vec3 data1 = texelFetch(colortex,ivec2(1,3),0).rgb/150.0;
	vec3 data2 = texelFetch(colortex,ivec2(2,3),0).rgb/150.0;
	vec3 data3 = texelFetch(colortex,ivec2(3,3),0).rgb/150.0;
	float data4 = texelFetch(colortex,ivec2(1,2),0).r/150.0;
	vec3 data5 = texelFetch(colortex,ivec2(2,2),0).rgb/150.0; // this samples a color

	smallCumulus = vec2(data1.x,data1.y);
	largeCumulus = vec2(data1.z,data2.x);
	altostratus = vec2(data2.y,data2.z);
	fog = vec2(data3.x, data3.y);
    localFog = vec2(data3.z, data4);
    localFogColor = vec3(data5.r,data5.g,data5.b);
}
#endif



// call the reading function within the main function
// this is so i dont have to edit the function call across every file :)))))))))))))

#if defined READ_SCENE_CONTROLLER_PARAMETERS
readSceneControllerParameters(
    colortex4, 
    parameters.smallCumulus, 
    parameters.largeCumulus, 
    parameters.altostratus, 
    parameters.fog,
    parameters.localFog,
    parameters.localFogColor
);
#endif