// this file contains all things for seasons, weather, and biome specific settings.
// i gotta start centralizing shit someday. 

#include "/lib/aurora.glsl"

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////// SEASONS //////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////// VERTEX SHADER
#ifdef Seasons
	#ifdef SEASONS_VSH

		uniform int worldDay;  
		uniform float noPuddleAreas;

		void YearCycleColor (
			inout vec3 FinalColor,
			vec3 glcolor,

			bool isLeaves,
			bool isPlants
		){
			// colors for things that arent leaves and using the tint index.
			vec3 SummerCol = vec3(Summer_R, Summer_G, Summer_B);
			vec3 AutumnCol = vec3(Fall_R, Fall_G, Fall_B);
			vec3 WinterCol = vec3(Winter_R, Winter_G, Winter_B) ;
			vec3 SpringCol = vec3(Spring_R, Spring_G, Spring_B);

			// decide if you want to replace biome colors or tint them.
			SummerCol *= glcolor;
			AutumnCol *= glcolor;
			WinterCol *= glcolor;
			SpringCol *= glcolor;

			// do leaf colors different because thats cool and i like it
			if(isLeaves) {
				SummerCol = vec3(Summer_Leaf_R, Summer_Leaf_G, Summer_Leaf_B);
				AutumnCol = vec3(Fall_Leaf_R, Fall_Leaf_G, Fall_Leaf_B);
				WinterCol = vec3(Winter_Leaf_R, Winter_Leaf_G, Winter_Leaf_B);
				SpringCol = vec3(Spring_Leaf_R, Spring_Leaf_G, Spring_Leaf_B);

				SummerCol *= glcolor;
				AutumnCol *= glcolor;
				WinterCol *= glcolor;
				SpringCol *= glcolor;
	    		}

			// length of each season in minecraft days
			int SeasonLength = Season_Length; 

			// loop the year. multiply the season length by the 4 seasons to create a years time.
			float YearLoop = mod(worldDay + Start_Season * SeasonLength, SeasonLength * 4);

			// the time schedule for each season
			float SummerTime = clamp(YearLoop, 0, SeasonLength) / SeasonLength;
			float AutumnTime = clamp(YearLoop - SeasonLength, 0, SeasonLength) / SeasonLength;
			float WinterTime = clamp(YearLoop - SeasonLength*2, 0, SeasonLength) / SeasonLength;
			float SpringTime = clamp(YearLoop - SeasonLength*3, 0, SeasonLength) / SeasonLength;

			// lerp all season colors together
			vec3 SummerToFall = mix(SummerCol, AutumnCol, SummerTime);
			vec3 FallToWinter = mix(SummerToFall, WinterCol, AutumnTime);
			vec3 WinterToSpring = mix(FallToWinter, SpringCol, WinterTime);
			vec3 SpringToSummer = mix(WinterToSpring, SummerCol, SpringTime);

			// make it so that you only have access to parts of the texture that use the tint index
			#ifdef DH_SEASONS
				bool IsTintIndex = isPlants || isLeaves;
			#else
				bool IsTintIndex = floor(dot(glcolor,vec3(0.5))) < 1.0;  
			#endif

			// multiply final color by the final lerped color, because it contains all the other colors.
			if(IsTintIndex) FinalColor = SpringToSummer;
		}
	#endif
#endif

vec3 getSeasonColor(int worldDay) {

	// length of each season in minecraft days
	// for example, at 1, a season is 1 day long
	int SeasonLength = 1; 

	// loop the year. multiply the season length by the 4 seasons to create a years time.
	float YearLoop = mod(worldDay + SeasonLength, SeasonLength * 4);

    	// the time schedule for each season
	float SummerTime = clamp(YearLoop, 0, SeasonLength) / SeasonLength;
	float AutumnTime = clamp(YearLoop - SeasonLength, 0, SeasonLength) / SeasonLength;
	float WinterTime = clamp(YearLoop - SeasonLength*2, 0, SeasonLength) / SeasonLength;
	float SpringTime = clamp(YearLoop - SeasonLength*3, 0, SeasonLength) / SeasonLength;

	// colors for things
	vec3 SummerCol = vec3(Summer_R, Summer_G, Summer_B);
	vec3 AutumnCol = vec3(Fall_R, Fall_G, Fall_B);
	vec3 WinterCol = vec3(Winter_R, Winter_G, Winter_B);
	vec3 SpringCol = vec3(Spring_R, Spring_G, Spring_B);

	// lerp all season colors together
	vec3 SummerToFall =   mix(SummerCol, AutumnCol, SummerTime);
	vec3 FallToWinter =   mix(SummerToFall, WinterCol, AutumnTime);
	vec3 WinterToSpring = mix(FallToWinter, SpringCol, WinterTime);
	vec3 SpringToSummer = mix(WinterToSpring, SummerCol, SpringTime);

	// return the final color of the year, because it contains all the other colors, at some point.
	return SpringToSummer;
}

///////////////////////////////////////////////////////////////////////////////
///////////////////////////// BIOME SPECIFICS /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

uniform float isJungles;
uniform float isSwamps;
uniform float isDarkForests;
uniform float isSnowy;
uniform float sandStorm;
uniform float snowStorm;

#ifdef PER_BIOME_ENVIRONMENT

	void BiomeFogColor(
		inout vec3 FinalFogColor
	){		

		// this is a little complicated? lmao
		vec3 BiomeColors = vec3(0.0);
		BiomeColors.r = isSwamps*SWAMP_R + isJungles*JUNGLE_R + isDarkForests*DARKFOREST_R + isSnowy*SNOWY_R + sandStorm*0.8 + snowStorm*0.6;
		BiomeColors.g = isSwamps*SWAMP_G + isJungles*JUNGLE_G + isDarkForests*DARKFOREST_G + isSnowy*SNOWY_G + sandStorm*0.7 + snowStorm*0.8;
		BiomeColors.b = isSwamps*SWAMP_B + isJungles*JUNGLE_B + isDarkForests*DARKFOREST_B + isSnowy*SNOWY_B + sandStorm*0.3 + snowStorm*1.0;

		// insure the biome colors are locked to the fog shape and lighting, but not its orignal color.
		BiomeColors *= max(dot(FinalFogColor,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025); 
		
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+isSnowy+sandStorm+snowStorm;

		// interpoloate between normal fog colors and biome colors. the transition speeds are conrolled by the biome uniforms.
		FinalFogColor = mix(FinalFogColor, BiomeColors, Inbiome);
	}

	void BiomeFogDensity(
		inout vec4 UniformDensity,
		inout vec4 CloudyDensity,
		float maxDistance
	){	
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+sandStorm+snowStorm;

		vec2 BiomeFogDensity = vec2(0.0); // x = uniform  ||  y = cloudy
		// BiomeFogDensity.x = isSwamps*SWAMP_UNIFORM_DENSITY + isJungles*JUNGLE_UNIFORM_DENSITY + isDarkForests*DARKFOREST_UNIFORM_DENSITY + sandStorm*15  + snowStorm*150;
		// BiomeFogDensity.y = isSwamps*SWAMP_CLOUDY_DENSITY + isJungles*JUNGLE_CLOUDY_DENSITY + isDarkForests*DARKFOREST_CLOUDY_DENSITY + sandStorm*255 + snowStorm*255;

		BiomeFogDensity.x = isSwamps*SWAMP_UNIFORM_DENSITY + isJungles*JUNGLE_UNIFORM_DENSITY + isDarkForests*DARKFOREST_UNIFORM_DENSITY + isSnowy*SNOWY_UNIFORM_DENSITY + sandStorm*0.0 + snowStorm*0.01;
		BiomeFogDensity.y = isSwamps*SWAMP_CLOUDY_DENSITY + isJungles*JUNGLE_CLOUDY_DENSITY + isDarkForests*DARKFOREST_CLOUDY_DENSITY + isSnowy*SNOWY_CLOUDY_DENSITY + sandStorm*0.5 + snowStorm*0.5;
		
		UniformDensity = mix(UniformDensity, vec4(BiomeFogDensity.x), Inbiome*maxDistance);
		CloudyDensity  = mix(CloudyDensity,  vec4(BiomeFogDensity.y), Inbiome*maxDistance);
	}

	float BiomeVLFogColors(inout vec3 DirectLightCol, inout vec3 IndirectLightCol){
		
		// this is a little complicated? lmao
		vec3 BiomeColors = vec3(0.0);
		BiomeColors.r = isSwamps*SWAMP_R + isJungles*JUNGLE_R + isDarkForests*DARKFOREST_R + isSnowy*SNOWY_R + sandStorm*0.8 + snowStorm*0.6;
		BiomeColors.g = isSwamps*SWAMP_G + isJungles*JUNGLE_G + isDarkForests*DARKFOREST_G + isSnowy*SNOWY_G + sandStorm*0.5 + snowStorm*0.8;
		BiomeColors.b = isSwamps*SWAMP_B + isJungles*JUNGLE_B + isDarkForests*DARKFOREST_B + isSnowy*SNOWY_B + sandStorm*0.2 + snowStorm*1.0;

		// insure the biome colors are locked to the fog shape and lighting, but not its orignal color.
		// DirectLightCol = BiomeColors * max(dot(DirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 + nightVision*0.2); 
		// IndirectLightCol = BiomeColors * max(dot(IndirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 + nightVision*0.2); 
		
		DirectLightCol = BiomeColors * max(dot(DirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 ); 
		IndirectLightCol = BiomeColors * max(dot(IndirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 ); 
		
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+isSnowy+sandStorm+snowStorm;

		return Inbiome;
	}

#endif

// Get aurora amount
#ifdef AURORA_SNOWY
	float aurMult = Night * isSnowy;
#else
	float aurMult = Night;
#endif

// Get aurora color
vec3 aurCol = mix(vec3(AURORA_UPPER_R, AURORA_UPPER_G, AURORA_UPPER_B), vec3(AURORA_LOWER_R, AURORA_LOWER_G, AURORA_LOWER_B), 0.25);

// Aurora emission offset
vec3 aurOffset = aurMult * aurCol * AURORA_BRIGHTNESS * AUR_ENV_OFFSET;

///////////////////////////////////////////////////////////////////////////////
////////////////////////////// FOG CONTROLLER ////////////////////////////
///////////////////////////////////////////////////////////////////////////////

#ifdef TIMEOFDAYFOG
	// uniform int worldTime;
	void FogDensities(
		inout float Uniform, inout float Cloudy, inout float Rainy, float maxDistance, float DailyWeather_UniformFogDensity, float DailyWeather_CloudyFogDensity
	) {

		// set schedules for fog to appear at specific ranges of time in the day.

		// set densities.		   morn, noon, even, night
		vec4 UniformDensity = TOD_Fog_mult * vec4(Morning_Uniform_Fog, Noon_Uniform_Fog, Evening_Uniform_Fog, Night_Uniform_Fog);
		vec4 CloudyDensity =  TOD_Fog_mult * vec4(Morning_Cloudy_Fog, Noon_Cloudy_Fog, Evening_Cloudy_Fog, Night_Cloudy_Fog);
		
		Rainy = Rainy*RainFog_amount;
		
		#ifdef Daily_Weather
			// let daily weather influence fog densities.
			UniformDensity = max(UniformDensity, DailyWeather_UniformFogDensity);
			CloudyDensity = max(CloudyDensity, DailyWeather_CloudyFogDensity);
		#endif

		#ifdef PER_BIOME_ENVIRONMENT
			BiomeFogDensity(UniformDensity, CloudyDensity, maxDistance); // let biome fog hijack to control densities, and overrride any other density controller...
		#endif

		Uniform *= Morning*UniformDensity.r + Noon*UniformDensity.g + Evening*UniformDensity.b + Night*UniformDensity.a;
		Cloudy *= Morning*CloudyDensity.r + Noon*CloudyDensity.g + Evening*CloudyDensity.b + Night*CloudyDensity.a;
	}
#endif