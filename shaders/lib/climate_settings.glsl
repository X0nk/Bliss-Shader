// this file contains all things for seasons, weather, and biome specific settings.
// i gotta start centralizing shit someday. 


// uniform float Day;

// // it's so symmetrical~

// float day0 = clamp(clamp(Day,   0.0,1.0)*clamp(2-Day, 0.0,1.0),0.0,1.0);
// float day1 = clamp(clamp(Day-1, 0.0,1.0)*clamp(3-Day, 0.0,1.0),0.0,1.0);
// float day2 = clamp(clamp(Day-2, 0.0,1.0)*clamp(4-Day, 0.0,1.0),0.0,1.0);
// float day3 = clamp(clamp(Day-3, 0.0,1.0)*clamp(5-Day, 0.0,1.0),0.0,1.0);
// float day4 = clamp(clamp(Day-4, 0.0,1.0)*clamp(6-Day, 0.0,1.0),0.0,1.0);
// float day5 = clamp(clamp(Day-5, 0.0,1.0)*clamp(7-Day, 0.0,1.0),0.0,1.0);
// float day6 = clamp(clamp(Day-6, 0.0,1.0)*clamp(8-Day, 0.0,1.0),0.0,1.0);
// float day7 = clamp(clamp(Day-7, 0.0,1.0)*clamp(9-Day, 0.0,1.0),0.0,1.0);

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////// SEASONS /////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////// VERTEX SHADER
#ifdef Seasons
	#ifdef SEASONS_VSH

	    varying vec4 seasonColor;

	    void YearCycleColor (
	        inout vec3 FinalColor,
	        vec3 glcolor
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
	    	float YearLoop = mod(worldDay, SeasonLength * 4); 

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
	    	FinalColor = SpringToSummer;
	    }
	#endif
#endif

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
			Coverage += mix(Cumulus_coverage, Rain_coverage, rainStrength);
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
			Coverage = Alto_coverage;
			Density  = Alto_density;
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

#ifdef Biome_specific_environment
	uniform float isJungles;
	uniform float isSwamps;
	uniform float isLush;
	uniform float isDeserts;
	
	void BiomeFogColor(
		inout vec3 FinalFogColor
	){	
		// this is a little complicated? lmao
		vec3 BiomeColors;
		BiomeColors.r = isSwamps*0.7  + isJungles*0.5;
		BiomeColors.g = isSwamps*1.0  + isJungles*1.0;
		BiomeColors.b = isSwamps*0.35 + isJungles*0.8;

		// insure the biome colors are locked to the fog shape and lighting, but not its orignal color.
		BiomeColors *= dot(FinalFogColor,vec3(0.21, 0.72, 0.07)); 
		
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps;

		// interpoloate between normal fog colors and biome colors. the transition speeds are conrolled by the biome uniforms.
		FinalFogColor = mix(FinalFogColor, BiomeColors, Inbiome);
	}

	void BiomeFogDensity(
		inout vec4 UniformDensity,
		inout vec4 CloudyDensity
	){	
		// these range 0.0-1.0. they will never overlap.
		float Inbiome = isJungles+isSwamps;

		vec2 BiomeFogDensity; // x = uniform  ||  y = cloudy
		BiomeFogDensity.x = isSwamps*1  + isJungles*5;
		BiomeFogDensity.y = isSwamps*5 + isJungles*2;

		UniformDensity = mix(UniformDensity, vec4(BiomeFogDensity.x), Inbiome);
		CloudyDensity  = mix(CloudyDensity,  vec4(BiomeFogDensity.y), Inbiome);
	}
#endif

///////////////////////////////////////////////////////////////////////////////
////////////////////////////// FOG CONTROLLER /////////////////////////////////
///////////////////////////////////////////////////////////////////////////////

#ifdef TIMEOFDAYFOG
	uniform int worldTime;
	void TimeOfDayFog(inout float Uniform, inout float Cloudy) {
	
	    float Time = (worldTime%24000)*1.0; 

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

		#ifdef Biome_specific_environment
			BiomeFogDensity(UniformDensity, CloudyDensity); // let biome fog hijack to control densities, and overrride any other density controller...
		#endif

		Uniform *= Morning*UniformDensity.r + Noon*UniformDensity.g + Evening*UniformDensity.b + Night*UniformDensity.a;
		Cloudy *= Morning*CloudyDensity.r + Noon*CloudyDensity.g + Evening*CloudyDensity.b + Night*CloudyDensity.a;
	}
#endif
