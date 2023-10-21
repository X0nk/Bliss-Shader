// Hash without Sine
// MIT License...
/* Copyright (c)2014 David Hoskins.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.*/
//----------------------------------------------------------------------------------------
		vec3 hash31(float p)
		{
		   vec3 p3 = fract(vec3(p) * vec3(.1031, .1030, .0973));
		   p3 += dot(p3, p3.yzx+33.33);
		   return fract((p3.xxy+p3.yzz)*p3.zyx); 
		}

		float hash11(float p)
		{
		    p = fract(p * .1031);
		    p *= p + 33.33;
		    p *= p + p;
		    return fract(p);
		}

//----------------------------------------------------------------------------------------

// Integer Hash - II
// - Inigo Quilez, Integer Hash - II, 2017
//   https://www.shadertoy.com/view/XlXcW4
//----------------------------------------------------------------------------------------

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

//----------------------------------------------------------------------------------------

// vec3 RandomPosition = hash31(frameTimeCounter);
vec3 ManualLightPos = vec3(ORB_X, ORB_Y, ORB_Z);

void LightSourcePosition(vec3 WorldPos, vec3 CameraPos, inout vec3 Pos1, inout vec3 Pos2){
	
	Pos1 = WorldPos - vec3(0,200,0);

    vec3 Origin = WorldPos - CameraPos - ManualLightPos;

    
    float cellSize = 200;
    vec3 cellPos = CameraPos ;

    Origin += fract(cellPos/cellSize)*cellSize - cellSize*0.5;
	// Origin -= vec3(sin(frameTimeCounter),0,-cos(frameTimeCounter)) * 20;

	vec3 randomPos = texelFetch2D(colortex4,ivec2(2,1),0).xyz / 150.0;

	Origin -= (randomPos * 2.0 - 1.0);


    Pos2 = Origin;
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

// Create a rising swirl centered around some origin.
void SwirlAroundOrigin(inout vec3 alteredOrigin, vec3 origin){

	float radiance = 2.39996 + alteredOrigin.y/1.5 + frameTimeCounter/50;
	mat2 rotationMatrix  = mat2(vec2(cos(radiance),  -sin(radiance)),  vec2(sin(radiance),  cos(radiance)));

    // make the swirl only happen within a radius
    float SwirlBounds = clamp(sqrt(length(vec3(origin.x, origin.y-100,origin.z)) / 200.0 - 1.0)  ,0.0,1.0);
    
    alteredOrigin.xz = mix(alteredOrigin.xz * rotationMatrix, alteredOrigin.xz, SwirlBounds);
}

// control where the fog volume should and should not be using a sphere.
void VolumeBounds(inout float Volume, vec3 Origin){

    vec3 Origin2 = (Origin - vec3(0,100,0));
	Origin2.y *= 0.8;
    float Center1 = length(Origin2);

    float Bounds = max(1.0 - Center1 / 75.0, 0.0) * 5.0;


    float radius = 150.0;
    float thickness = 50.0 * radius;
    float Torus =  (thickness - clamp( pow( length( vec2(length(Origin.xz) - radius, Origin2.y) ),2.0) - radius, 0.0, thickness) ) / thickness;
	
	Origin2.xz *= 0.3;
	Origin2.y -= 100;

	float orb = clamp((1.0 - length(Origin2) / 15.0) * 1.5,0.0,1.0);
    Volume = max(Volume - Bounds - Torus, orb);
	
}

// create the volume shape
float cloudVol(in vec3 pos){

	float Output = 0.0;
	vec3 samplePos = pos*vec3(1.0,1./48.,1.0);

    // swirly swirly :DDDDDDDDDDD
    SwirlAroundOrigin(samplePos, pos);

	float NoisePlane = texture2D(noisetex, samplePos.xz/1024 ).b;

    float MainShape = clamp(max(0.5 - densityAtPosFog(samplePos * 16),0.0) * 2,0.0,1.0);
    float Erosion = abs(0.6 - densityAtPosFog(samplePos * (160. - MainShape*50) - vec3(0,frameTimeCounter*3,0) 	));
    

    Output = MainShape;
    Output = max(Output - Erosion*0.5,0.0);
    // apply limts
    VolumeBounds(Output, pos);

    // Output = max(max(100 - pos.y,0.0) - NoisePlane * 50        ,0.0);
	return Output;
}

float EndLightMie(vec3 LightPos){

    float mie = exp(length(LightPos) / -150);
    mie *= mie;
    mie *= mie;
    mie *= 100;

    return mie;
}

void LightSourceColors(inout vec3 Color1, inout vec3 Color2){
    Color1 = vec3(0.7,0.88,1.0); 
    Color2 = vec3(ORB_R,ORB_G,ORB_B);
}

vec3 LightSourceLighting( vec3 WorldPos, vec3 LightPos, float Dither, float VolumeDensity, vec3 LightColor, float Phase ){

    float Mie = EndLightMie(LightPos);
	float Shadow = 0.0;

	for (int j=0; j < 3; j++){
		vec3 shadowSamplePos = WorldPos - LightPos * (0.05 + j * (0.25 + Dither*0.15));
		Shadow += cloudVol(shadowSamplePos);
	}

    vec3 FinalLighting = LightColor * Mie * exp(Shadow * -5.0) ;

	FinalLighting += LightColor * exp2(-5 * max(2.5-Shadow,0.0) * vec3(1.2,1.0,0.8+VolumeDensity*0.4)) * (Mie*Mie)  * clamp((1.0 - length(LightPos) / 100.0),0.0,1.0); 

	return FinalLighting;
}


#define lightsourceCount 2 // [1 2]

vec4 GetVolumetricFog(
	vec3 viewPos,
	float dither,
	float dither2
){
	int SAMPLES = 16;
	vec3 vL = vec3(0.0);
	float absorbance = 1.0;

  	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * viewPos + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = vec3(0.0);

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition-start;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),32.0 * 12.0)/length(dVWorld);

	dV *= maxLength;
	dVWorld *= maxLength;

	float dL = length(dVWorld);
	vec3 fogcolor = (gl_Fog.color.rgb / max(dot(gl_Fog.color.rgb,vec3(0.3333)),0.05)) ;
    
	vec3 LightCol1 = vec3(0); vec3 LightCol2 = vec3(0);
	LightSourceColors(LightCol1, LightCol2);

	float Flashing = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;
	// LightCol1 *= Flashing; 
	LightCol2 *= Flashing;


	vec3 LightPos1 = vec3(0); vec3 LightPos2 = vec3(0);

    LightSourcePosition(cameraPosition, cameraPosition, LightPos1, LightPos2);

	float Phase1 = sqrt(1.0 - clamp( dot(normalize(dVWorld), normalize(-LightPos1)),0.0,1.0));
	Phase1 = exp(Phase1 * -5.0) * 10;
	
	float Phase2 = sqrt(1.0 - clamp( dot(normalize(dVWorld), normalize(-LightPos2)),0.0,1.0));
	Phase2 = exp(Phase2 * -5.0) * 10;


	float expFactor = 11.0;
	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);
		vec3 progress = start.xyz + d*dV;
		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;

		// vec3 LightPos1 = vec3(0); vec3 LightPos2 = vec3(0);
        LightSourcePosition(progressW, cameraPosition, LightPos1, LightPos2);

		float VolumeDensity = max(cloudVol(progressW),0.0);
		float Density = max(VolumeDensity,0.0);


        ////////////////////////////////////////////////////////////////
        ///////////////////////// AMBIENT LIGHT ////////////////////////
        ////////////////////////////////////////////////////////////////

		vec3 vL0 = fogcolor * exp2(VolumeDensity * -25) * 0.1 ;

        ////////////////////////////////////////////////////////////////
        /////////////////////// MAIN LIGHTSOURCE ///////////////////////
        ////////////////////////////////////////////////////////////////
		vec3 Light1 = vec3(0); vec3 Light2 = vec3(0);


		// Density += clamp((1.0 - length(LightPos1) / 10.0) * 10 ,0.0,1.0); // THE ORRRRRRRRRRRRRRRRRRRRRRRRRRB
		Light1 = LightSourceLighting(progressW, LightPos1, dither2, VolumeDensity, LightCol1, Phase1);

		#if lightsourceCount == 2
			Density += clamp((1.0 - length(LightPos2) / 10.0) * 10 ,0.0,1.0); // THE ORRRRRRRRRRRRRRRRRRRRRRRRRRB

			Light2 += LightSourceLighting(progressW, LightPos2, dither2, VolumeDensity, LightCol2, Phase2);
		#endif

		vL0 += Light1 + Light2;

        ////////////////////////////////////////////////////////////////
        /////////////////////////// FINALIZE ///////////////////////////
        ////////////////////////////////////////////////////////////////

		float AirDensity = 0.002;
		// AirDensity = 0.0;
		vec3 vL1 = vec3(0.5,0.75,1.0) * 0.5;
		// vL1 += Light1 + Light2;

		vL += (vL1 - vL1*exp2(-AirDensity*dd*dL)) * absorbance;
		vL += (vL0 - vL0*exp(-Density*dd*dL)) * absorbance;

        absorbance *= exp2(-(AirDensity+Density)*dd*dL);

		if (absorbance < 1e-5) break;
	}
	return vec4(vL, absorbance);
}

float GetCloudShadow(vec3 WorldPos, vec3 LightPos){
    float Shadow = 0.0;

	for (int i=0; i < 3; i++){

	    vec3 shadowSamplePos = WorldPos - LightPos * (0.1 + pow(i,0.75)*0.25); 
		// vec3 shadowSamplePos = WorldPos - LightPos * i * 0.5;
	    float Cast = cloudVol(shadowSamplePos);
	    Shadow += Cast;
    }

	return clamp(exp(-Shadow*5.0),0.0,1.0);
}