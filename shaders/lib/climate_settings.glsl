// this file contains all things for seasons, weather, and biome specific settings.
// i gotta start centralizing shit someday. 

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////// SEASONS /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////// VERTEX SHADER
#ifdef Seasons
	#ifdef SEASONS_VSH

		uniform int worldDay;  
		uniform float noPuddleAreas;

	    void YearCycleColor (
	        inout vec3 FinalColor,
	        vec3 glcolor,
			inout float SnowySeason
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
	    	if(mc_Entity.x == 10003){
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
	    	float SummerTime = clamp(YearLoop                  ,0, SeasonLength) / SeasonLength;
	    	float AutumnTime = clamp(YearLoop - SeasonLength   ,0, SeasonLength) / SeasonLength;
	    	float WinterTime = clamp(YearLoop - SeasonLength*2 ,0, SeasonLength) / SeasonLength;
	    	float SpringTime = clamp(YearLoop - SeasonLength*3 ,0, SeasonLength) / SeasonLength;

	    	// lerp all season colors together
	    	vec3 SummerToFall =   mix(SummerCol,      AutumnCol, SummerTime);
	    	vec3 FallToWinter =   mix(SummerToFall,   WinterCol, AutumnTime);
	    	vec3 WinterToSpring = mix(FallToWinter,   SpringCol, WinterTime);
	    	vec3 SpringToSummer = mix(WinterToSpring, SummerCol, SpringTime);

			// make it so that you only have access to parts of the texture that use the tint index
			bool IsTintIndex = floor(dot(glcolor,vec3(0.5))) < 1.0;  

	    	// multiply final color by the final lerped color, because it contains all the other colors.
	    	if(IsTintIndex) FinalColor = SpringToSummer;

			#ifdef Snowy_Winter
				// this is to make snow only exist in winter
	    		float FallToWinter_snowfall = mix(0.0, 1.0, AutumnTime);
	    		float WinterToSpring_snowfall = mix(FallToWinter_snowfall, 0.0, WinterTime);
				SnowySeason = clamp(pow(sin(WinterToSpring_snowfall*SeasonLength)*0.5+0.5,5),0,1)  * WinterToSpring_snowfall * noPuddleAreas;
			#else
				SnowySeason = 0.0;
			#endif
	    }
	#endif
#endif

	    vec3 getSeasonColor( int worldDay ){

			// length of each season in minecraft days
			// for example, at 1, a season is 1 day long
	    	int SeasonLength = 1; 

			// loop the year. multiply the season length by the 4 seasons to create a years time.
	    	float YearLoop = mod(worldDay + SeasonLength, SeasonLength * 4);

	    	// the time schedule for each season
	    	float SummerTime = clamp(YearLoop                  ,0, SeasonLength) / SeasonLength;
	    	float AutumnTime = clamp(YearLoop - SeasonLength   ,0, SeasonLength) / SeasonLength;
	    	float WinterTime = clamp(YearLoop - SeasonLength*2 ,0, SeasonLength) / SeasonLength;
	    	float SpringTime = clamp(YearLoop - SeasonLength*3 ,0, SeasonLength) / SeasonLength;

	    	// colors for things
	    	vec3 SummerCol = vec3(Summer_R, Summer_G, Summer_B);
	    	vec3 AutumnCol = vec3(Fall_R, Fall_G, Fall_B);
	    	vec3 WinterCol = vec3(Winter_R, Winter_G, Winter_B);
	    	vec3 SpringCol = vec3(Spring_R, Spring_G, Spring_B);

	    	// lerp all season colors together
	    	vec3 SummerToFall =   mix(SummerCol,      AutumnCol, SummerTime);
	    	vec3 FallToWinter =   mix(SummerToFall,   WinterCol, AutumnTime);
	    	vec3 WinterToSpring = mix(FallToWinter,   SpringCol, WinterTime);
	    	vec3 SpringToSummer = mix(WinterToSpring, SummerCol, SpringTime);

	    	// return the final color of the year, because it contains all the other colors, at some point.
	    	return SpringToSummer;
	    }
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
////////////////////////////// DAILY WEATHER //////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////


#ifdef WEATHERCLOUDS

	uniform float Cumulus_Cov;

	float DailyWeather_Cumulus(
		float Coverage
	){

		#ifdef Daily_Weather
			Coverage += mix(Cumulus_Cov, Rain_coverage, rainStrength);
		#else
			Coverage += mix(CloudLayer0_coverage, Rain_coverage, rainStrength);
		#endif

		return Coverage;
	}

	uniform float Alto_Cov;
	uniform float Alto_Den;

	void DailyWeather_Alto(
		inout float Coverage,
		inout float Density
	){
		#ifdef Daily_Weather
			Coverage = Alto_Cov;
			Density  = Alto_Den;
		#else
			Coverage = CloudLayer2_coverage;
			Density  = CloudLayer2_density;
		#endif
	}

#endif

#ifdef Daily_Weather
	uniform float Uniform_Den;
	uniform float Cloudy_Den;

	void DailyWeather_FogDensity(
		inout vec4 UniformDensity,
		inout vec4 CloudyDensity
	){

		// set fog Profiles for each of the 8 days in the cycle.
		// U = uniform fog  ||  C = cloudy fog
		// vec4( morning, noon, evening, night )

		UniformDensity.rgb += vec3(Uniform_Den);
		CloudyDensity.rgb  += vec3(Cloudy_Den);
	}
#endif

///////////////////////////////////////////////////////////////////////////////
///////////////////////////// BIOME SPECIFICS /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

	uniform float nightVision;

	uniform float isJungles;
	uniform float isSwamps;
	uniform float isDarkForests;
	uniform float sandStorm;
	uniform float snowStorm;

#ifdef PER_BIOME_ENVIRONMENT

	void BiomeFogColor(
		inout vec3 FinalFogColor
	){
		

		// this is a little complicated? lmao
		vec3 BiomeColors = vec3(0.0);
		BiomeColors.r = isSwamps*SWAMP_R + isJungles*JUNGLE_R + isDarkForests*DARKFOREST_R + sandStorm*1.0 + snowStorm*0.6;
		BiomeColors.g = isSwamps*SWAMP_G + isJungles*JUNGLE_G + isDarkForests*DARKFOREST_G + sandStorm*0.5 + snowStorm*0.8;
		BiomeColors.b = isSwamps*SWAMP_B + isJungles*JUNGLE_B + isDarkForests*DARKFOREST_B + sandStorm*0.3 + snowStorm*1.0;

		// insure the biome colors are locked to the fog shape and lighting, but not its orignal color.
		BiomeColors *= max(dot(FinalFogColor,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 + nightVision*0.2); 
		
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+sandStorm+snowStorm;

		// interpoloate between normal fog colors and biome colors. the transition speeds are conrolled by the biome uniforms.
		FinalFogColor = mix(FinalFogColor, BiomeColors, Inbiome);
	}

	// void BiomeSunlightColor(
	// 	inout vec3 FinalSunlightColor
	// ){	
	// 	// this is a little complicated? lmao
	// 	vec3 BiomeColors = vec3(0.0);
	// 	BiomeColors.r = isSwamps*SWAMP_R + isJungles*JUNGLE_R + isDarkForests*DARKFOREST_R + sandStorm*1.0 + snowStorm*0.6;
	// 	BiomeColors.g = isSwamps*SWAMP_G + isJungles*JUNGLE_G + isDarkForests*DARKFOREST_G + sandStorm*0.5 + snowStorm*0.8;
	// 	BiomeColors.b = isSwamps*SWAMP_B + isJungles*JUNGLE_B + isDarkForests*DARKFOREST_B + sandStorm*0.3 + snowStorm*1.0;

	// 	// these range 0.0-1.0. they will never overlap.
	// 	float Inbiome = isJungles+isSwamps+isDarkForests+sandStorm+snowStorm;

	// 	// interpoloate between normal fog colors and biome colors. the transition speeds are conrolled by the biome uniforms.
	// 	FinalSunlightColor = mix(FinalSunlightColor, FinalSunlightColor * (BiomeColors*0.8+0.2), Inbiome);
	// }

	void BiomeFogDensity(
		inout vec4 UniformDensity,
		inout vec4 CloudyDensity,
		float maxDistance
	){	
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+sandStorm+snowStorm;

		vec2 BiomeFogDensity = vec2(0.0); // x = uniform  ||  y = cloudy
		BiomeFogDensity.x = isSwamps*SWAMP_UNIFORM_DENSITY + isJungles*JUNGLE_UNIFORM_DENSITY + isDarkForests*DARKFOREST_UNIFORM_DENSITY + sandStorm*15  + snowStorm*150;
		BiomeFogDensity.y = isSwamps*SWAMP_CLOUDY_DENSITY + isJungles*JUNGLE_CLOUDY_DENSITY + isDarkForests*DARKFOREST_CLOUDY_DENSITY + sandStorm*255 + snowStorm*255;
		
		UniformDensity = mix(UniformDensity, vec4(BiomeFogDensity.x), Inbiome*maxDistance);
		CloudyDensity  = mix(CloudyDensity,  vec4(BiomeFogDensity.y), Inbiome*maxDistance);
	}

	float BiomeVLFogColors(inout vec3 DirectLightCol, inout vec3 IndirectLightCol){
		
		// this is a little complicated? lmao
		vec3 BiomeColors = vec3(0.0);
		BiomeColors.r = isSwamps*SWAMP_R + isJungles*JUNGLE_R + isDarkForests*DARKFOREST_R + sandStorm*1.0 + snowStorm*0.6;
		BiomeColors.g = isSwamps*SWAMP_G + isJungles*JUNGLE_G + isDarkForests*DARKFOREST_G + sandStorm*0.5 + snowStorm*0.8;
		BiomeColors.b = isSwamps*SWAMP_B + isJungles*JUNGLE_B + isDarkForests*DARKFOREST_B + sandStorm*0.3 + snowStorm*1.0;

		// insure the biome colors are locked to the fog shape and lighting, but not its orignal color.
		DirectLightCol = BiomeColors * max(dot(DirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 + nightVision*0.2); 
		
		IndirectLightCol = BiomeColors * max(dot(IndirectLightCol,vec3(0.33333)), MIN_LIGHT_AMOUNT*0.025 + nightVision*0.2); 
		
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps+isDarkForests+sandStorm+snowStorm;

		return Inbiome;
	}

#endif

///////////////////////////////////////////////////////////////////////////////
////////////////////////////// FOG CONTROLLER /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

#ifdef TIMEOFDAYFOG
	// uniform int worldTime;
	void TimeOfDayFog(
		inout float Uniform, inout float Cloudy, float maxDistance
	) {
	
	    float Time = worldTime%24000; 

		// set schedules for fog to appear at specific ranges of time in the day.
		float Morning = clamp((Time-22000)/2000,0,1) + clamp((2000-Time)/2000,0,1);
		float Noon 	  = clamp(Time/2000,0,1) * clamp((12000-Time)/2000,0,1);
		float Evening = clamp((Time-10000)/2000,0,1) * clamp((14000-Time)/2000,0,1) ;
		float Night   = clamp((Time-13000)/2000,0,1) * clamp((23000-Time)/2000,0,1) ;

		// set densities.		   morn, noon, even, night
		vec4 UniformDensity = TOD_Fog_mult * vec4(Morning_Uniform_Fog, Noon_Uniform_Fog, Evening_Uniform_Fog, Night_Uniform_Fog);
		vec4 CloudyDensity =  TOD_Fog_mult * vec4(Morning_Cloudy_Fog, Noon_Cloudy_Fog, Evening_Cloudy_Fog, Night_Cloudy_Fog);


		#ifdef Daily_Weather
			DailyWeather_FogDensity(UniformDensity, CloudyDensity); // let daily weather influence fog densities.
		#endif

		#ifdef PER_BIOME_ENVIRONMENT
			BiomeFogDensity(UniformDensity, CloudyDensity, maxDistance); // let biome fog hijack to control densities, and overrride any other density controller...
		#endif

		Uniform *= Morning*UniformDensity.r + Noon*UniformDensity.g + Evening*UniformDensity.b + Night*UniformDensity.a;
		Cloudy *= Morning*CloudyDensity.r + Noon*CloudyDensity.g + Evening*CloudyDensity.b + Night*CloudyDensity.a;
	}
#endif
