// this file contains all things for seasons, weather, and biome specific settings.
// i gotta start centralizing shit someday. 

#define Seasons
#define Season_Length 24 // how long each season lasts in minecraft days. 91 is roughly how long each season is in reality. 1 will make a year last 4 days [ 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 35 36 37 38 39 40 41 42 43 45 46 47 48 49 50 51 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 86 87 88 89 90 91]
// #define Snowy_Winter // snow in the winter, yes or no?

#define Summer_R 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Summer_G 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Summer_B 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Summer_Leaf_R 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Summer_Leaf_G 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Summer_Leaf_B 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define Fall_R 1.5 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Fall_G 1.0 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Fall_B 1.0 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Fall_Leaf_R 1.8 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Fall_Leaf_G 0.8 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Fall_Leaf_B 0.0 // the color of the plants during this season   [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define Winter_R 1.2 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Winter_G 0.8 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Winter_B 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Winter_Leaf_R 1.2 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Winter_Leaf_G 0.5 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Winter_Leaf_B 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]

#define Spring_R 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Spring_G 0.9 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Spring_B 1.1 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Spring_Leaf_R 1.0 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Spring_Leaf_G 0.8 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]
#define Spring_Leaf_B 0.8 // the color of the plants during this season [0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0]


#define Daily_Weather // different skies for different days, and fog.
#define WeatherDay -1 // [-1 0 1 2 3 4 5 6 7]

#define cloudCoverage 0.4 // Cloud coverage	[ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define Rain_coverage 0.6 // how much the coverage of the clouds change during rain [ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0]

#define Biome_specific_environment // makes the fog density and color look unique in certain biomes. (swamps, jungles, lush caves, giant pines, dark forests)

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
	    	vec3 SummerCol = vec3(Summer_R, Summer_G, Summer_B) * glcolor;
	    	vec3 AutumnCol = vec3(Fall_R, Fall_G, Fall_B) * glcolor;
	    	vec3 WinterCol = vec3(Winter_R, Winter_G, Winter_B) ;
	    	vec3 SpringCol = vec3(Spring_R, Spring_G, Spring_B) * glcolor;

	    	// do leaf colors different because thats cool and i like it
	    	if(mc_Entity.x == 10003){
	    		SummerCol = vec3(Summer_Leaf_R, Summer_Leaf_G, Summer_Leaf_B) * glcolor;
	    	    AutumnCol = vec3(Fall_Leaf_R, Fall_Leaf_G, Fall_Leaf_B) * glcolor;
	    		WinterCol = vec3(Winter_Leaf_R, Winter_Leaf_G, Winter_Leaf_B) ;
	    		SpringCol = vec3(Spring_Leaf_R, Spring_Leaf_G, Spring_Leaf_B)* glcolor;
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
	    	if (IsTintIndex && mc_Entity.x != 200) FinalColor = SpringToSummer;
	    }
	#endif
#endif

///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
////////////////////////////// DAILY WEATHER //////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////
#ifdef WEATHERCLOUDS
	uniform float CumulusCoverage;
	uniform float CirrusCoverage;
	uniform float CirrusThickness;

	float DailyWeather_LowAltitude(
		float Coverage
	){
		
		#ifdef Daily_Weather
			int W_DAY = WeatherDay;

			if(W_DAY > -1)	{
				if(W_DAY == 0) Coverage += 0.1;
				if(W_DAY == 1) Coverage += 0.5;
				if(W_DAY == 2) Coverage += 0.2;
				if(W_DAY == 3) Coverage += 0.8;
				if(W_DAY == 4) Coverage += 0.1;
				if(W_DAY == 5) Coverage += 0.6;
				if(W_DAY == 6) Coverage += 0.0;
				if(W_DAY == 7) Coverage += 1.0;
			}else{
				Coverage += mix(CumulusCoverage, Rain_coverage, rainStrength);
			}
		#else
			Coverage += mix(cloudCoverage, Rain_coverage, rainStrength);
		#endif

		return Coverage;
	}

	void DailyWeather_HighAltitude(
		inout float Coverage,
		inout float Thickness
	){
		
		#ifdef Daily_Weather
			float W_DAY = WeatherDay;

			if(W_DAY > -1)	{
				if(W_DAY == 0){ Coverage = 0.8; Thickness = 0.5; }
				if(W_DAY == 1){ Coverage = 0.8; Thickness = 0.5; }
				if(W_DAY == 2){ Coverage = 0.0; Thickness = 0.5; }
				if(W_DAY == 3){ Coverage = 0.0; Thickness = 0.5; }
				if(W_DAY == 4){ Coverage = 0.0; Thickness = 0.5; }
				if(W_DAY == 5){ Coverage = 0.0; Thickness = 0.5; }
				if(W_DAY == 6){ Coverage = 0.0; Thickness = 0.5; }
				if(W_DAY == 7){ Coverage = 0.0; Thickness = 0.5; }
			}else{
				Coverage  = CirrusCoverage;
				Thickness = CirrusThickness;
			}
		#else
			Coverage  = 0.5;
			Thickness = 0.05;
		#endif

		Coverage = pow(1.0-Coverage,3) * 50;
		Thickness = Thickness * 10;
	}
#endif

#ifdef Daily_Weather
	uniform float Day;

	void DailyWeather_FogDensity(
		inout vec4 UniformDensity,
		inout vec4 CloudyDensity
	){
		// it's so symmetrical~
		float day0 = clamp(clamp(Day,   0.0,1.0)*clamp(2-Day, 0.0,1.0),0.0,1.0);
		float day1 = clamp(clamp(Day-1, 0.0,1.0)*clamp(3-Day, 0.0,1.0),0.0,1.0);
		float day2 = clamp(clamp(Day-2, 0.0,1.0)*clamp(4-Day, 0.0,1.0),0.0,1.0);
		float day3 = clamp(clamp(Day-3, 0.0,1.0)*clamp(5-Day, 0.0,1.0),0.0,1.0);
		float day4 = clamp(clamp(Day-4, 0.0,1.0)*clamp(6-Day, 0.0,1.0),0.0,1.0);
		float day5 = clamp(clamp(Day-5, 0.0,1.0)*clamp(7-Day, 0.0,1.0),0.0,1.0);
		float day6 = clamp(clamp(Day-6, 0.0,1.0)*clamp(8-Day, 0.0,1.0),0.0,1.0);
		float day7 = clamp(clamp(Day-7, 0.0,1.0)*clamp(9-Day, 0.0,1.0),0.0,1.0);

		// set fog Profiles for each of the 8 days in the cycle.
		// U = uniform fog  ||  C = cloudy fog
		vec4 MistyDay_U = vec4(5);

		vec4 FoggyDay_U = vec4(5);
		vec4 FoggyDay_C = vec4(25);


		UniformDensity += FoggyDay_U*day1 + MistyDay_U*day4;
		CloudyDensity  += FoggyDay_C*day1;
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
		BiomeColors *= dot(FinalFogColor,vec3(0.5)); 
		
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
		BiomeFogDensity.x = isSwamps*5  + isJungles*5;
		BiomeFogDensity.y = isSwamps*50 + isJungles*2;

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
		vec4 UniformDensity = vec4(1.0,	 0.0,	   1.0,	 10.0);
		vec4 CloudyDensity =  vec4(5.0,	 0.0,	   5.0,	 25.0);

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
