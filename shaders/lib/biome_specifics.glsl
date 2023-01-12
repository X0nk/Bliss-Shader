// #define Biome_specific_environment // makes the fog density and color look unique in certain biomes. (swamps, jungles, lush caves, giant pines, dark forests)
// #define Jungle_fog_strength 1.0 // how strong the fog gets there. set to zero to have normal fog [0.0 0.25 0.50 0.75 1.0]
// #define Swamp_fog_strength  1.0 // how strong the fog gets there. set to zero to have normal fog [0.0 0.25 0.50 0.75 1.0]
// #define Lush_fog_strength   1.0 // how strong the fog gets there. set to zero to have normal fog [0.0 0.25 0.50 0.75 1.0]

// #define Time_of_day_fog // fog starts closer to you at sunrise/sunset + night
// #define Rain_fog // rain fog.
// #define Lightmap_based_fog // fog that changes lighting based on the light from the sky. so if you're in a cave, it changes. if you go to the surface, its mostly normal

// #define Swamp_R 0.9 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0] 
// #define Swamp_G 1.0 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0] 
// #define Swamp_B 0.35 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0] 

// #define Jungle_R 0.5 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]  
// #define Jungle_G 1.0 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]  
// #define Jungle_B 0.8 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0] 

// #define override_R 0.5 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]  
// #define override_G 1.0 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0]  
// #define override_B 0.8 // the color of the fog. only effects this specific biome [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 1.0] 

// #define Swamp_cloudyfog_Density 25. //  how dense or thick the cloudy fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]
// #define Jungle_Cloudy_Fog_Density 10. // how dense or thick the cloudy fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]
// #define override_Cloudy_Fog_Density 1. // how dense or thick the cloudy fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]

// #define Swamp_UniformFog_Density 15. // how dense or thick the uniform fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]
// #define Jungle_Uniform_Fog_Density 10. //how dense or thick the uniform fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]
// #define override_Uniform_Fog_Density 1. //how dense or thick the uniform fog is. only effects this specific biome [0. 5. 10. 15. 20. 25. 30. 35. 40. 45. 50. 55. 60. 65. 70. 75. 80. 85. 90. 95. 100.]

// #define Swamp_Mie 0.75  // control the size of the peak of light around the sun in the fog. only effects this specific biome [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
// #define Jungle_Mie 0.75 // control the size of the peak of light around the sun in the fog. only effects this specific biome [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]
// #define override_Mie 1.0 // control the size of the peak of light around the sun in the fog. only effects this specific biome [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.75 0.8 0.85 0.9 0.95 1.0]

// #define Swamp_Sun_Strength  1.0 // control how strong the sun shines through fog. only effects this specific biome [0.0 0.25 0.50 0.75 1.0 1.25 1.50 1.75 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
// #define Jungle_Sun_Strength 1.0 // control how strong the sun shines through fog. only effects this specific biome [0.0 0.25 0.50 0.75 1.0 1.25 1.50 1.75 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
// #define override_Sun_Strength 1.0 // control how strong the sun shines through fog. only effects this specific biome [0.0 0.25 0.50 0.75 1.0 1.25 1.50 1.75 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

// #define Swamp_Bloomy_Fog 2.0  // control how bloomy the fog looks. only effects this specific biome [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
// #define Jungle_Bloomy_Fog 3.0 // control how bloomy the fog looks. only effects this specific biome [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]
// #define override_Bloomy_Fog 1.0 // control how bloomy the fog looks. only effects this specific biome [0.0 1.0 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

// #define Swamp_cloudyfog_height  30 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]
// #define Jungle_cloudyfog_fade 30 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]
// #define override_cloudyfog_fade 50 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]

// #define Swamp_uniformfog_height  10 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]
// #define Jungle_uniformfog_fade 10 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]
// #define override_uniformfog_fade 50 // controll the fade away at the top of the fog [5 10 20 30 40 50 60 70 80  90 100]


// #define override_fog 0 // override the fog that exists everywhere with your own [0 1]

// // uniform int isEyeInWater;  
// // uniform float blindness;
// // uniform float rainStrength;
// // uniform ivec2 eyeBrightnessSmooth; 
// // uniform float eyeAltitude;
// // uniform int worldTime;

// uniform float isJungles;
// uniform float isSwamps;
// uniform float isLush;
// uniform float isDeserts;

// // float timething = (worldTime%24000)*1.0;
// // float TimeOfDayFog = clamp((1.0 - clamp( timething-11000,0.0,2000.0)/2000.) * (clamp(timething,0.0,2000.0)/2000.)   ,0.0,1.0);

// // fuck you
// #ifdef Biome_specific_environment
//     float SWAMPS  =  isSwamps;
//     float JUNGLES =  isJungles;
//     float LUSHCAVE = isLush;
//     float DESERTS =  isDeserts;
//     float OVERRIDE  = max(override_fog - (SWAMPS + JUNGLES),0);
// #else
//     float OVERRIDE  = 0;
//     float SWAMPS  = 0;
//     float JUNGLES = 0;
//     float LUSHCAVE = 0;
//     float DESERTS = 0; 
// #endif

// // all the fog settings that do various things.
// float[8] Biome_Fog_Properties = float[8](
// /*[0] biome check*/          SWAMPS*Swamp_fog_strength + JUNGLES*Jungle_fog_strength + OVERRIDE
// /*[1] cloudy fog density*/  ,SWAMPS*Swamp_cloudyfog_Density + JUNGLES*Jungle_Cloudy_Fog_Density + OVERRIDE*override_cloudyfog_fade
// /*[2] uniform fog density*/ ,SWAMPS*Swamp_UniformFog_Density + JUNGLES*Jungle_Uniform_Fog_Density + OVERRIDE*override_Uniform_Fog_Density
// /*[3] sunlight strength*/   ,SWAMPS*Swamp_Sun_Strength + JUNGLES*Jungle_Sun_Strength + OVERRIDE*override_Sun_Strength
// /*[4] bloomy fog strength*/ ,SWAMPS*Swamp_Bloomy_Fog + JUNGLES*Jungle_Bloomy_Fog + OVERRIDE*override_Bloomy_Fog
// /*[5] fog mie size */       ,SWAMPS*Swamp_Mie + JUNGLES*Jungle_Mie + OVERRIDE*override_Mie
// /*[6] cloudy fog fade */    ,SWAMPS*Swamp_cloudyfog_height + JUNGLES*Jungle_cloudyfog_fade + OVERRIDE*override_Cloudy_Fog_Density
// /*[7] uniform fog fade */   ,SWAMPS*Swamp_uniformfog_height + JUNGLES*Jungle_uniformfog_fade + OVERRIDE*override_uniformfog_fade
// );

// // ??? ive no clue what this one does ngl
// vec3 Biome_FogColor = vec3(
//      SWAMPS*Swamp_R + JUNGLES*Jungle_R + OVERRIDE*override_R
//     ,SWAMPS*Swamp_G + JUNGLES*Jungle_G + OVERRIDE*override_G
//     ,SWAMPS*Swamp_B + JUNGLES*Jungle_B + OVERRIDE*override_B
// );