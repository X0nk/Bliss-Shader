vec3 srgbToLinear2(vec3 srgb){
    return mix(
        srgb / 12.92,
        pow(.947867 * srgb + .0521327, vec3(2.4) ),
        step( .04045, srgb )
    );
}
vec3 blackbody2(float Temp)
{
    float t = pow(Temp, -1.5);
    float lt = log(Temp);

    vec3 col = vec3(0.0);
         col.x = 220000.0 * t + 0.58039215686;
         col.y = 0.39231372549 * lt - 2.44549019608;
         col.y = Temp > 6500. ? 138039.215686 * t + 0.72156862745 : col.y;
         col.z = 0.76078431372 * lt - 5.68078431373;
         col = clamp(col,0.0,1.0);
         col = Temp < 1000. ? col * Temp * 0.001 : col;

    return srgbToLinear2(col);
}


// Integer Hash - II
// - Inigo Quilez, Integer Hash - II, 2017
//   https://www.shadertoy.com/view/XlXcW4
uvec3 iqint2(uvec3 x)
{
    const uint k = 1103515245u;

    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;
    x = ((x>>8U)^x.yzx)*k;

    return x;
}

uvec3 hash(vec2 s)
{	

    uvec4 u = uvec4(s, uint(s.x) ^ uint(s.y), uint(s.x) + uint(s.y)); // Play with different values for 3rd and 4th params. Some hashes are okay with constants, most aren't.
    
    return iqint2(u.xyz);
}
vec3 hash31(float p)
{
   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
   p3 += dot(p3, p3.yzx+33.33);
   return fract((p3.xxy+p3.yzz)*p3.zyx); 
}

// uniform float ifEndBoss;
// uniform float isSneaking;

// uniform float EndSequence1;
// uniform float EndSequence2;


// position related stuff
// vec2 SEED = vec2(sin(frameTimeCounter*5) + 1);
// uvec3 HASH = hash(SEED);
// vec3 RandomPosition = clamp(vec3(HASH) * (1.0/float(0xffffffffu)), 0.0, 1.0);
vec3 RandomPosition = hash31(1);


// vec3 ManualLightPos =   vec3(109.25, 128.73, 1189.4) ;
// vec3 ManualLightPos = vec3(307.96, 141.00, 1107.05) - vec3(sin(frameTimeCounter), 0, -cos(frameTimeCounter))*25;
// ManualLightPos -= vec3(sin(frameTimeCounter), 0, -cos(frameTimeCounter))*100;

vec3 ManualLightPos = vec3(ORB_X, ORB_Y, ORB_Z);

///////////////// POSITION
///////////////// POSITION
///////////////// POSITION
vec3 LightSourcePosition(vec3 WorldPos, vec3 CameraPos){
    
    vec3 Origin = WorldPos ;
    vec3 RandomPosition2 = hash31(Origin.y);
    // make the swirl only happen within a radius
    float SwirlBounds = clamp(sqrt(length(vec3(Origin.x,Origin.y-100,Origin.z)) / 150.0 - 1.0)  ,0.0,1.0);

    if( SwirlBounds < 1.0) {
        Origin.y -= 200;
    } else {
        Origin = WorldPos - cameraPosition - ManualLightPos ;
        // Origin -= RandomPosition * 100;
    }

    return Origin;
}

///////////////// COLOR
///////////////// COLOR
///////////////// COLOR
vec3 LightSourceColor(float SwirlBounds){

    vec3 Color = vec3(0.0);

    if( SwirlBounds < 1.0) {

        //////// STAGE 1
        Color = vec3(0.5, 0.5, 1.0);
        
        //////// STAGE 2

        // Color = mix(Color, vec3(1.0,0.3,0.3),  pow(EndSequence1,3.0));
        
        // //////// STAGE 3
        // // yes rico, kaboom 
        // Color = mix(Color, vec3(1.0,0.0,1.0) * (1.0-EndSequence2),  EndSequence2);

    } else {

        // Color = vec3(0.6, 0.8 ,1.0);
        Color = vec3(ORB_R, ORB_G, ORB_B) * ORB_ColMult;

        // float Timing = dot(RandomPosition, vec3(1.0/3.0));

        // float Flash = max(sin(frameTimeCounter*10) * Timing,0.0);
        // Color *= blackbody2(RandomPosition.y*4000 + 1000);
        // Color *= Flash;

    }

    return Color;
}

///////////////// SHAPE
///////////////// SHAPE
///////////////// SHAPE
vec3 LightSourceShape(vec3 WorldPos){

    vec3 Shapes = vec3(0.0);
    vec3 Origin = WorldPos ;

    // make the swirl only happen within a radius
    float SwirlBounds = clamp(sqrt(length(Origin) / 200.0 - 1.0)  ,0.0,1.0);

    if( SwirlBounds < 1.0) {

        // vec3 Origin = WorldPos;
        Origin.y -= 200; 

        vec3 Origin2 = Origin;
        Origin2.y += 100 ;
        Origin2.y *= 0.8;

        float Center = length(Origin);
        float AltCenter = length(Origin2);

        //////// STAGE 1
        // when the ender dragon is alive, restrict the fog in this shape
        // the max of a sphere is another smaller sphere. this creates a hollow sphere.
        Shapes.r = max(1.0 - AltCenter / 75.0, max(AltCenter / 150.0 - 1.0, 0.0));

        float radius = 200.0;
        float thickness = 50.0 * radius;
        Shapes.r =  (thickness - clamp(pow(sqrt(pow(Origin2.x,2) + pow(Origin2.z,2)) - radius,2) + pow(Origin2.y*0.75,2.0) - radius,0,thickness)) / thickness ;
        
        Shapes.r = max(Shapes.r,    max(1.0 - AltCenter / 75.0, 0.0));

        radius = 50.0;
        thickness = 5.0 * radius;
        Shapes.b =  (thickness - clamp(pow(sqrt(pow(Origin2.x,2) + pow(Origin2.y,2)) - radius,2) + pow(Origin2.z*0.75,2.0) - radius,0,thickness)) / thickness ;
    }

    return Shapes;
}


float densityAtPosFog(in vec3 pos){
	pos /= 18.;
	pos.xz *= 0.5;

	vec3 p = floor(pos);
	vec3 f = fract(pos);

	f = (f*f) * (3.-2.*f);
	vec2 uv =  p.xz + f.xz + p.y * vec2(0.0,193.0);
	vec2 coord =  uv / 512.0;
	vec2 xy = texture2D(noisetex, coord).yx;
	return mix(xy.r,xy.g, f.y);
}

float cloudVol(in vec3 pos, int LOD){


    // THE OOOOOOOOOOOOOOOOOOOOOORB
    vec3 Shapes = LightSourceShape(pos);
    
	vec3 samplePos = pos*vec3(1.0,1./32.,1.0);
	vec3 samplePos2 = pos*vec3(1.0,1./48.,1.0);

    // #ifndef THE_ORB
        // ender dragon battle area swirling effect.
        // if(EndSequence2 < 1.0){
	        float radiance = 2.39996 + samplePos.y + frameTimeCounter/10;
	        mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

            // make the swirl only happen within a radius
            float SwirlBounds = clamp(sqrt(length(vec3(pos.x,pos.y-100,pos.z)) / 200.0 - 1.0)  ,0.0,1.0);

            samplePos.xz =  mix(samplePos.xz  * rotationMatrix, samplePos.xz, SwirlBounds);
            samplePos2.xz = mix(samplePos2.xz * rotationMatrix, samplePos2.xz, SwirlBounds);
        // }
    // #endif

    samplePos2.y -= frameTimeCounter/15;

    float finalfog = 0;

	finalfog += max(0.6-densityAtPosFog(samplePos * 16.0) * 2,0.0);
    // finalfog = exp(finalfog*5)-1;

	float smallnoise = max(densityAtPosFog(samplePos2 * (160. - finalfog*3))-0.1,0.0);
	finalfog -= ((1-smallnoise) - max(0.15 - abs(smallnoise * 2.0 - 0.55) * 0.5,0.0)*1.5) * 0.3;
    
    // make the eye of the swirl have no fog, so you can actually see.
    finalfog = max(finalfog - Shapes.r, 0.0);
    
    // dragon death sequence
    // finalfog = Shapes.b;
    

	return finalfog;
}


mat2x3 getVolumetricRays(float dither,vec3 fragpos,float dither2) {
    int SAMPLES = 16;
	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * fragpos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;


	//project view origin into projected shadowmap space
	vec3 start = vec3(0.0);

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = (fragposition-start);
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),32.0 * 12.0)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;

	//apply dither
	vec3 progress = start.xyz;
	vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition;
	vec3 vL = vec3(0.);
	float dL = length(dVWorld);

	vec3 absorbance = vec3(1.0);
	float expFactor = 11.0;

	vec3 fogColor = (gl_Fog.color.rgb / pow(dot(gl_Fog.color.rgb,vec3(0.3333)),1.1)  ) ;


	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		float densityVol = cloudVol(progressW,1);
		float density = min(densityVol,0.1);
        float air = 0.005;

        /// THE OOOOOOOOOOOOOOOOOOOOOORB
        vec3 LightColor = LightSourceColor(clamp(sqrt(length(vec3(progressW.x,progressW.y-100,progressW.z)) / 150.0 - 1.0)  ,0.0,1.0));
        
        vec3 LightPos = LightSourcePosition(progressW, cameraPosition);
        // float OrbMie = exp(length(LightPos) * -0.03) * 64.0;
        
        // float OrbMie = max(exp2(4.0 + length(LightPos) / -20),0.0);
 

        float OrbMie = max(1.0-length(LightPos)/200,0.0);
        float N = 2.50;
		OrbMie = pow(1.0-pow(1.0-OrbMie,1.0/N),N);
		OrbMie *= 10.0;
        // LightColor *= OrbMie;

		float CastLight = 0.0;
		for (int j=0; j < 3; j++){
	        vec3 shadowSamplePos = progressW - LightPos * (pow(j+dither2/3,0.75)*0.3); 
	        // vec3 shadowSamplePos = progressW - LightPos  * (pow(j+dither2,0.75)*0.25); 
			
			float densityVol2 = cloudVol(shadowSamplePos,1);
			CastLight += densityVol2;
		}
        

        vec3 CastedLight = LightColor * OrbMie * exp(CastLight * 15 * (LightColor*(1.0-CastLight/3)-1.50))  ; 
        CastedLight += (LightColor * vec3(1.0,1.3,1.0)) * exp(abs(densityVol*2.0 - 0.3) * 15 * (LightColor*CastLight)) * (max(OrbMie - density*10,0.0)/10);

        // #ifdef THE_ORB
		//     density += clamp((1.0 - length(LightPos) / 10.0) * 10 ,0.0,1.0) ;
        //     InnerLight = vec3(0.0);
        // #endif
        
		vec3 AmbientLight = fogColor * 0.05  * pow(exp(density * -2),20);

		vec3 vL0 =  AmbientLight + CastedLight;
        
		vec3 vL1 = vec3(0.5,0.75,1.0) * 0.05 ;
        // vL1 += (LightColor* vec3(1.0,1.3,1.0)) * max(LightColor  - (exp(CastLight * 5)-OrbMie),0.0) * OrbMie;

		vL += (vL0 - vL0*exp(-density*dd*dL)) * absorbance;
		vL += (vL1 - vL1*exp(-air*dd*dL)) * absorbance;

        absorbance *= exp(-(density+air)*dd*dL);
	}
	return mat2x3(vL,absorbance);
}

float GetCloudShadow(vec3 WorldPos, vec3 LightPos, float noise){
    float Shadow = 0.0;

	for (int i=0; i < 3; i++){

	    vec3 shadowSamplePos = WorldPos - LightPos * (0.25 + pow(i,0.75)*0.25); 
	    float Cast = cloudVol(shadowSamplePos,1);
	    Shadow += Cast;
    }

	return clamp(exp(-Shadow*5),0.0,1.0);
	// return (Shadow);
}
float GetCloudShadow2(vec3 WorldPos){

	float Shadow = cloudVol(WorldPos,1);

	return clamp( exp2(Shadow * -3),0.0,1.0);
}