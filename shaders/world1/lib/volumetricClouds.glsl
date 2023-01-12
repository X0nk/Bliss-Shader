#define VOLUMETRIC_CLOUDS// if you don't like the noise on the default cloud settings, turn up the cloud samples. if that hurts performance too much, turn down the clouds quality.

#define cloud_LevelOfDetail 1		// Number of fbm noise iterations for on-screen clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_ShadowLevelOfDetail 0	// Number of fbm noise iterations for the shadowing of on-screen clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_LevelOfDetailLQ 1	// Number of fbm noise iterations for reflected clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define cloud_ShadowLevelOfDetailLQ 0	// Number of fbm noise iterations for the shadowing of reflected clouds (-1 is no fbm)	[-1 0 1 2 3 4 5 6 7 8]
#define minRayMarchSteps 20		// Number of ray march steps towards zenith for on-screen clouds	[20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150 155 160 165 170 175 180 185 190 195 200]
#define maxRayMarchSteps 30		// Number of ray march steps towards horizon for on-screen clouds	[5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100 105 110 115 120 125 130 135 140 145 150 155 160 165 170 175 180 185 190 195 200]
#define minRayMarchStepsLQ 10	// Number of ray march steps towards zenith for reflected clouds	[5  10  15  20  25  30  35  40  45  50  55  60  65  70  75  80  85  90 95 100]
#define maxRayMarchStepsLQ 30		// Number of ray march steps towards horizon for reflected clouds	[  5  10  15  20  25  30  35  40  45  50  55  60  65  70  75  80  85  90 95 100]
#define cloudMieG 0.5 // Values close to 1 will create a strong peak of luminance around the sun and weak elsewhere, values close to 0 means uniform fog. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define cloudMieG2 0.9 // Multiple scattering approximation. Values close to 1 will create a strong peak of luminance around the sun and weak elsewhere, values close to 0 means uniform fog. [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]
#define cloudMie2Multiplier 0.7 // Multiplier for multiple scattering approximation  [0.01 0.02 0.03 0.04 0.05 0.06 0.07 0.08 0.09 0.1 0.11 0.12 0.13 0.14 0.15 0.16 0.17 0.18 0.19 0.2 0.21 0.22 0.23 0.24 0.25 0.26 0.27 0.28 0.29 0.3 0.31 0.32 0.33 0.34 0.35 0.36 0.37 0.38 0.39 0.4 0.41 0.42 0.43 0.44 0.45 0.46 0.47 0.48 0.49 0.5 0.51 0.52 0.53 0.54 0.55 0.56 0.57 0.58 0.59 0.6 0.61 0.62 0.63 0.64 0.65 0.66 0.67 0.68 0.69 0.7 0.71 0.72 0.73 0.74 0.75 0.76 0.77 0.78 0.79 0.8 0.81 0.82 0.83 0.84 0.85 0.86 0.87 0.88 0.89 0.9 0.91 0.92 0.93 0.94 0.95 0.96 0.97 0.98 0.99 ]

#define Cloud_top_cutoff 1.0  // the cutoff point on the top part of the cloud. [ 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 2.5 3.0 4 5 6 7 8 9] 
#define Cloud_base_cutoff 5.0 // the cutoff point on the base of the cloud. [0.1 1 2 4 6 8 10 12 14 16 18 20]


#ifdef HQ_CLOUDS
int maxIT_clouds = minRayMarchSteps;
int maxIT = maxRayMarchSteps;
#else
int maxIT_clouds = minRayMarchStepsLQ;
int maxIT = maxRayMarchStepsLQ;
#endif



uniform vec3 sunPosition;


#define cloudCoverage 0.4 // Cloud coverage	[ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define Rain_coverage 0.6 // how much the coverage of the clouds change during rain [ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0]

///////  shape
#define cloudDensity 0.0514	// Cloud Density, 0.04-0.06 is around irl values	[0.0010 0.0011 0.0013 0.0015 0.0017 0.0020 0.0023 0.0026 0.0030 0.0034 0.0039 0.0045 0.0051 0.0058 0.0067 0.0077 0.0088 0.0101 0.0115 0.0132 0.0151 0.0173 0.0199 0.0228 0.0261 0.0299 0.0342 0.0392 0.0449 0.0514 0.0589 0.0675 0.0773 0.0885 0.1014 0.1162 0.1331 0.1524 0.1746 0.2000 0.3 0.35 0.4 0.45 0.5 0.6 0.7 0.8 0.9 1.0]
#define fbmAmount2 1 		// Amount of noise added to the cloud shape	[0.00 0.02 0.04 0.06 0.08 0.10 0.12 0.14 0.16 0.18 0.20 0.22 0.24 0.26 0.28 0.30 0.32 0.34 0.36 0.38 0.40 0.42 0.44 0.46 0.48 0.50 0.52 0.54 0.56 0.58 0.60 0.62 0.64 0.66 0.68 0.70 0.72 0.74 0.76 0.78 0.80 0.82 0.84 0.86 0.88 0.90 0.92 0.94 0.96 0.98 1.00 1.02 1.04 1.06 1.08 1.10 1.12 1.14 1.16 1.18 1.20 1.22 1.24 1.26 1.28 1.30 1.32 1.34 1.36 1.38 1.40 1.42 1.44 1.46 1.48 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00]
#define fbmPower1 3.00	// Higher values increases high frequency details of the cloud shape	[1.0 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00 3.02 3.04 3.06 3.08 3.10 3.12 3.14 3.16 3.18 3.20 3.22 3.24 3.26 3.28 3.30 3.32 3.34 3.36 3.38 3.40 3.42 3.44 3.46 3.48 3.50 3.52 3.54 3.56 3.58 3.60 3.62 3.64 3.66 3.68 3.70 3.72 3.74 3.76 3.78 3.80 3.82 3.84 3.86 3.88 3.90 3.92 3.94 3.96 3.98 4.00 5. 6. 7. 8. 9. 10.]
#define fbmPower2 1.50	// Lower values increases high frequency details of the cloud shape	[1.00 1.50 1.52 1.54 1.56 1.58 1.60 1.62 1.64 1.66 1.68 1.70 1.72 1.74 1.76 1.78 1.80 1.82 1.84 1.86 1.88 1.90 1.92 1.94 1.96 1.98 2.00 2.02 2.04 2.06 2.08 2.10 2.12 2.14 2.16 2.18 2.20 2.22 2.24 2.26 2.28 2.30 2.32 2.34 2.36 2.38 2.40 2.42 2.44 2.46 2.48 2.50 2.52 2.54 2.56 2.58 2.60 2.62 2.64 2.66 2.68 2.70 2.72 2.74 2.76 2.78 2.80 2.82 2.84 2.86 2.88 2.90 2.92 2.94 2.96 2.98 3.00 3.02 3.04 3.06 3.08 3.10 3.12 3.14 3.16 3.18 3.20 3.22 3.24 3.26 3.28 3.30 3.32 3.34 3.36 3.38 3.40 3.42 3.44 3.46 3.48 3.50 3.52 3.54 3.56 3.58 3.60 3.62 3.64 3.66 3.68 3.70 3.72 3.74 3.76 3.78 3.80 3.82 3.84 3.86 3.88 3.90 3.92 3.94 3.96 3.98 4.00 5. 6. 7. 8. 9. 10.]

///////  lighting
#define Shadow_brightness 0.5 // how dark / bright you want the shadowed part of the clouds to be. low values can look weird. [ 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0 3.0 4.0 5.0 6.0]
#define self_shadow_samples 3.0 // amount of interations for cloud self shadows. longer/shorter cloud self shadows. [ 2.0 3.0 4.0 5.0 6.0 7.0 8.0 9.0 10.0]

#define Cloud_Size 35 // [1 5 10 15 20 25 30 35 40 45 50 55 60 65 70 75 80 85 90 95 100]
#define Cloud_Height 319 // [-300 -290 -280 -270 -260 -250 -240 -230 -220 -210 -200 -190 -180 -170 -160 -150 -140 -130 -120 -110 -100 -90 -80 -70 -60 -50 -40 -30 -20 -10 0 10 20 30 40 50 60 70 80 90 100 110 120 130 140 150 160 170 180 190 200 210 220 230 240 250 260 270 280 290 300 310 319 320]

// #define Dynamic_weather // a

#define Dynamic_sky_day -1 // -1 MEANS THIS IS OFF. select which day of the 8 to the clouds should take shape in [0 1 2 3 4 5 6 7 ]

#define Dynamic_Sky // day 1: partly cloudy. day 2: really cloudy, misty. day 3: mostly clear. day 4: cloudy. day 5: cloudy again. day 6: scattered clouds. day 7: partly cloudy. day 8: clear
#define High_Altitude_Clouds // a layer of clouds way up yonder

///////  other
#define Puddle_size 5 // size of puddles [1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 191 20 21 22 23 24 25] 
#define Puddle_Coverage 0.7 // the amount of cround the puddles cover [ 0.50 0.49 0.48 0.47 0.46 0.45 0.44 0.44 0.43 0.42 0.41 0.40 0.39 0.38 0.37 0.36 0.35 0.34 0.33 0.32 0.31 0.30 0.29 0.28 0.27 0.26 0.25 0.24 0.23 0.22 0.21 0.20 0.19 0.18 0.17 0.16 0.15 0.14 0.13 0.12 0.11 0.10 0.09 0.08 0.07 0.06 0.05 0.04 0.03 0.02 0.01 0.0]
#define flip_the_clouds 1 // what was once above is now below [1 -1] 
#define cloud_speed 1 // how 	[ 0.0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0 2.0 3.0 5.0 10.0 25.0 50.0 100.0 200.0]


#ifdef HQ_CLOUDS
const int cloudLoD = cloud_LevelOfDetail;
const int cloudShadowLoD = cloud_ShadowLevelOfDetail;
#else
const int cloudLoD = cloud_LevelOfDetailLQ;
const int cloudShadowLoD = cloud_ShadowLevelOfDetailLQ;
#endif



uniform sampler2D colortex4;//Skybox

uniform float wetness;

uniform vec4 Moon_Weather_properties;



// David Hoskins' Hash without Sine  https://www.shadertoy.com/view/4djSRW
vec3 hash31(float p)
{
   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
   p3 += dot(p3, p3.yzx+33.33);
   return fract((p3.xxy+p3.yzz)*p3.zyx); 
}


float speed = floor(frameTimeCounter);
vec3 rand_pos = hash31(speed) * 6.28;

vec3 lighting_pos =  vec3(sin(1.57 + rand_pos.x), sin(rand_pos.y), sin(rand_pos.z));
// vec3 lighting_pos = vec3(1,3 , 1);

vec3 lightSource = normalize(lighting_pos);
vec3 viewspace_sunvec = mat3(gbufferModelView) * lightSource;
vec3 WsunVec = normalize(mat3(gbufferModelViewInverse) * viewspace_sunvec);


float timing = dot(lighting_pos, vec3(1.0));
float flash = max(sin(frameTimeCounter*5) * timing,0.0);

vec3 srgbToLinear(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}


vec3 blackbody(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp(col,0,1);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear(col);
}
// vec3 SunCol =  	vec3(1 ,0.3 ,0.8)   ;
vec3 SunCol =  	vec3(0.25 ,0.5 ,1.0)*flash   * blackbody( rand_pos.y* 2000);
// vec3 SunCol = vec3(0.0);




float cloud_height = 1500.;
float maxHeight = 4000.;

//3D noise from 2d texture
float densityAtPos(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;
	vec3 p = floor(pos);
	vec3 f = fract(pos);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	
	//Te y channel has an offset to avoid using two textures fetches
	vec2 xy = texture2D(noisetex, coord).yx;

	return mix(xy.r,xy.g, f.y);
}

float CloudLarge = 1.0;
float CloudSmall = 1.0;
float coverage = 1.0;
float cloudshape = 0;

// vec2 cloud_movement = vec2(	sin(frameTimeCounter/2000)*2	,-cos(frameTimeCounter/2000)*2) * MOVEMENT;
vec3 cloud_movement1 =  vec3(frameTimeCounter)*0.1 ;

//Cloud without 3D noise, is used to exit early lighting calculations if there is no cloud
float cloudCov(in vec3 pos,vec3 samplePos){
	
	CloudLarge = texture2D(noisetex, samplePos.xz/22500    + frameTimeCounter/500. ).b*2.0;

	coverage = CloudLarge +0.5;
	float mult = max( (4000.0-pos.y) / 1000, 0);

	cloudshape = coverage - mult ;

	return cloudshape;
}


//Erode cloud with 3d Perlin-worley noise, actual cloud value
float cloudVol(in vec3 pos,in vec3 samplePos,in float cov, in int LoD){
	float noise = 0.0 ;
	float totalWeights = 0.0;
	float pw =  log(fbmPower1);
	float pw2 = log(fbmPower2);

	float swirl = (1-texture2D(noisetex, samplePos.xz/5000   ).b)*8;

	for (int i = 0; i <= LoD; i++){
		float weight = exp(-i*pw2);

		noise += weight - densityAtPos(samplePos *(8. )* exp(i*pw) )*weight  ;
		totalWeights += weight ;
	}

	noise /= totalWeights;
	noise = noise*noise;
	noise *= clamp(1.0 - cloudshape,0.0,1.0);
	float cloud = max(cov-noise*noise*(1.)*fbmAmount2,0.0);

	return cloud;
}

float getCloudDensity(in vec3 pos, in int LoD){
	vec3 samplePos = pos*vec3(1.0,1./48.,1.0)/4  - frameTimeCounter/2;
	float coverageSP = cloudCov(pos,samplePos);
	if (coverageSP > 0.001) {
		if (LoD < 0) return max(coverageSP - 0.27*fbmAmount2,0.0);
		return cloudVol(pos,samplePos,coverageSP, LoD);
	} else return 0.0;
}
//Mie phase function
float phaseg(float x, float g){
    float gg = g * g;
    return (gg * -0.25 + 0.25) * pow(-2.0 * (g * x) + (gg + 1.0), -1.5) /3.14;
}


vec3 startOffset = vec3(0);
vec4 renderClouds(vec3 fragpositi, vec3 color,float dither,vec3 sunColor,vec3 moonColor,vec3 avgAmbient,float dither2) {
	

	#ifndef VOLUMETRIC_CLOUDS
		return vec4(0.0,0.0,0.0,1.0);
	#endif

	//project pixel position into projected shadowmap space
	vec4 fragposition = gbufferModelViewInverse*vec4(fragpositi,1.0);

	vec3 worldV = normalize(fragposition.rgb);
	float VdotU = worldV.y;

	// worldV.y += 0.1	;

	
	//project view origin into projected shadowmap space
	vec4 start = (gbufferModelViewInverse*vec4(0.0,0.0,0.,1.));
	vec3 dV_view = worldV;

	vec3 progress_view = dV_view*dither+cameraPosition;

	float testdither = dither ;
	float vL = 0.0;
	float total_extinction = 1.0;

	maxIT_clouds = int(clamp( maxIT_clouds /sqrt(exp2(VdotU)),0.0, maxIT*1.0));
	float distW = length(worldV);
	worldV = normalize(worldV)*100000. + cameraPosition; //makes max cloud distance not dependant of render distance
	dV_view = normalize(dV_view);
	// maxHeight = maxHeight * (1+testCloudheight_variation);

	int Flip_clouds = 1;
	if (worldV.y < cloud_height) Flip_clouds = -1;
	//setup ray to start at the start of the cloud plane and end at the end of the cloud plane
	dV_view *= max(maxHeight - cloud_height, 0.0)/dV_view.y/(maxIT_clouds);
	startOffset = dV_view*testdither;

	vec3 camPos = Flip_clouds*(cameraPosition);

	progress_view = (startOffset)  + camPos + dV_view*((cloud_height)-camPos.y)/dV_view.y ;
	



	

	float shadowStep = 240.;
	vec3 dV_Sun = Flip_clouds * normalize( mat3(gbufferModelViewInverse) * viewspace_sunvec ) * shadowStep;


	float mult = length(dV_view);


	color = vec3(0.0);

	total_extinction = 1.0;
	float SdotV = dot(normalize(viewspace_sunvec), normalize(fragpositi));

	float mieDay = phaseg(SdotV, 0.8);
	float mie2 = phaseg(SdotV, 0.5);


	// vec3 SunCol = vec3(1.0,0.5,0.5) * flashing ;

	vec3 sunContribution = mieDay*SunCol*3.14;


	// float darkness = texture2D(noisetex, progress_view.xz/120500).b;
	// vec3 skyCol0 = (avgAmbient*4.0*3.1415*8/3.0 ) ;
	vec3 skyCol0 = gl_Fog.color.rgb * 0.01;

	for(int i=0;i<maxIT_clouds;i++) {

		float cloud = getCloudDensity(progress_view, cloudLoD);
		float densityofclouds = max(cloudDensity,0.) ;


		if(cloud > 0.0001){
			float muS = cloud*densityofclouds;
			float muE =	cloud*densityofclouds;

			float muEshD = 0.0;
			if (sunContribution.g > 1e-5){
				for (int j=0; j < 3; j++){

					vec3 shadowSamplePos =  progress_view + dV_Sun * ((j+0.5) + (j *2))     ;
					// get the cloud density and apply it
					if (shadowSamplePos.y < maxHeight){
						float cloudS = getCloudDensity(shadowSamplePos, cloudShadowLoD);
						muEshD += cloudS*densityofclouds*shadowStep;
					}
				}
			}

			float powder = muE * 100; // powder....  

			float sunShadow = exp(-muEshD*0.25);  // this simulates the direct light, and the scattering of it

			float front_lit = sunShadow;
			float back_lit =	pow(muS*(cloud+muE),		max(1-cloud*2,0.0)*2);

			float innerSeams = mix(front_lit, back_lit*0.5, clamp(mie2,0.,1.) )  ;

			vec3 SunCloud_lighting = sunContribution * innerSeams * mie2;
			vec3 AmbientCloud_Lighting = skyCol0 * powder  ;



			vec3 S = SunCloud_lighting + AmbientCloud_Lighting ; // combine all the combined

			vec3 Sint= (S - S * exp(-mult*muE)) / muE;
			color += max(muS*Sint*total_extinction,0.0);
			total_extinction *= max(exp(-muE*mult),0);

			if (total_extinction < 1e-5) break;
		}
		progress_view += dV_view;
	}

	// vec3 normView = normalize(dV_view);
	// // Assume fog color = sky gradient at long distance
	// vec3 fogColor = skyFromTex(normView, colortex4)/150.;
	// float dist = (cloud_height - cameraPosition.y)/normalize(dV_view).y;
	// float fog = exp(-dist/15000.0*(1.0+rainCloudwetness*8.));
	
		float cosY = normalize(dV_view).y;
		return mix(vec4(color,clamp(total_extinction*(1.0+1/250.)-1/250.,0.0,1.0)),vec4(0.0,0.0,0.0,1.0), 1-smoothstep(0.02,0.15,cosY));
}
