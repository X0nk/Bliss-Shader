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
float vortexBoundRange = 300.0;
vec3 ManualLightPos = vec3(ORB_X, ORB_Y, ORB_Z);

vec3 LightSourcePosition(vec3 worldPos, vec3 cameraPos, float vortexBounds){

	// this is static so it can just sit in one place
	vec3 vortexPos = worldPos - vec3(0.0,200.0,0.0);

    vec3 lightningPos = worldPos - cameraPos - ManualLightPos;
    
	// snap-to coordinates in worldspace.
	float cellSize = 200.0;
    lightningPos += fract(cameraPos/cellSize)*cellSize - cellSize*0.5;

	// make the position offset to random places (RNG.xyz from non-clearing buffer).
	vec3 randomOffset = (texelFetch2D(colortex4,ivec2(2,1),0).xyz / 150.0) * 2.0 - 1.0;
	lightningPos -= randomOffset * 2.5;
	
	#ifdef THE_ORB
		cellSize = 200.0;
    	vec3 orbpos = worldPos - cameraPos - ManualLightPos;// - vec3(sin(frameTimeCounter), cos(frameTimeCounter), cos(frameTimeCounter))*100;
    	orbpos += fract(cameraPos/cellSize)*cellSize - cellSize*0.5;

		return orbpos;
	#else
		return mix(lightningPos, vortexPos, vortexBounds);
	#endif
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
	
	Origin2.xz *= 0.5;
	Origin2.y -= 100;

	float orb = clamp((1.0 - length(Origin2) / 15.0) * 1.0,0.0,1.0);
    Volume = max(Volume - Bounds - Torus, 0);
	
}

// create the volume shape
float fogShape(in vec3 pos){
	float vortexBounds = clamp(vortexBoundRange - length(pos), 0.0,1.0);
	vec3 samplePos = pos*vec3(1.0,1.0/48.0,1.0);
	float fogYstart = -60;

    
	// this is below down where you fall to your death.
	float voidZone = max(exp2(-1.0 * sqrt(max(pos.y - -60,0.0))) ,0.0) ;

	// swirly swirly :DDDDDDDDDDD
    SwirlAroundOrigin(samplePos, pos);
	
	float noise = densityAtPosFog(samplePos * 12.0);
    float erosion = 1.0-densityAtPosFog((samplePos - frameTimeCounter/20) * (124 + (1-noise)*7));
    

	float clumpyFog = max(exp(noise * -mix(10,4,vortexBounds))*mix(2,1,vortexBounds) - erosion*0.3, 0.0);
    
	// apply limts
    VolumeBounds(clumpyFog, pos);


	return clumpyFog + voidZone;
}

float endFogPhase(vec3 LightPos){

    float mie = exp(length(LightPos) / -150);
    mie *= mie;
    mie *= mie;
    mie *= 100;

    return mie;
}

vec3 LightSourceColors(float vortexBounds, float lightningflash){

    // vec3 vortexColor = vec3(0.7,0.88,1.0); 
    // vec3 lightningColor = vec3(ORB_R,ORB_G,ORB_B);

    vec3 vortexColor = vec3(0.5,0.68,1.0);
    vec3 lightningColor = vec3(1.0,0.3,0.2) * lightningflash;

	#ifdef THE_ORB
		return vec3(ORB_R, ORB_G, ORB_B) * ORB_ColMult;
	#else
		return mix(lightningColor, vortexColor, vortexBounds);
	#endif
}

vec3 LightSourceLighting(vec3 startPos, vec3 lightPos, float noise, float density, vec3 lightColor, float vortexBound){

    float phase = endFogPhase(lightPos);
	float shadow = 0.0;

	for (int j = 0; j < 3; j++){
		vec3 shadowSamplePos = startPos - lightPos * (0.05 + j * (0.25 + noise*0.15));
		shadow += fogShape(shadowSamplePos);
	}

    vec3 finalLighting = lightColor * phase * exp(shadow * -10.0);

	finalLighting += lightColor * phase*phase * (1.0-exp((shadow*shadow*shadow) * vec3(0.6,2.0,2) * -1)) * (1.0 - exp(-density*density)); 

	return finalLighting;
}

vec4 GetVolumetricFog(
	vec3 viewPosition,
	float dither,
	float dither2
){
	#ifndef TOGGLE_VL_FOG
		return vec4(0.0,0.0,0.0,1.0);
	#endif
	/// -------------  RAYMARCHING STUFF ------------- \\\

	int SAMPLES = 16;

	//project pixel position into projected shadowmap space
	vec3 wpos = mat3(gbufferModelViewInverse) * viewPosition + gbufferModelViewInverse[3].xyz;
	vec3 fragposition = mat3(shadowModelView) * wpos + shadowModelView[3].xyz;
	fragposition = diagonal3(shadowProjection) * fragposition + shadowProjection[3].xyz;

	//project view origin into projected shadowmap space
	vec3 start = vec3(0.0);

	//rayvector into projected shadow map space
	//we can use a projected vector because its orthographic projection
	//however we still have to send it to curved shadow map space every step
	vec3 dV = fragposition - start;
	vec3 dVWorld = (wpos-gbufferModelViewInverse[3].xyz);

	float maxLength = min(length(dVWorld),32.0 * 12.0)/length(dVWorld);
	dV *= maxLength;
	dVWorld *= maxLength;
	float dL = length(dVWorld);

	vec3 progressW = gbufferModelViewInverse[3].xyz + cameraPosition;
	
	/// -------------  COLOR/LIGHTING STUFF ------------- \\\

	vec3 color = vec3(0.0);
	vec3 absorbance = vec3(1.0);

	vec3 fogcolor = (gl_Fog.color.rgb / max(dot(gl_Fog.color.rgb,vec3(0.3333)),0.05)) ;
    
	float lightningflash = texelFetch2D(colortex4,ivec2(1,1),0).x/150.0;

	float expFactor = 11.0;
	for (int i=0;i<SAMPLES;i++) {
		float d = (pow(expFactor, float(i+dither)/float(SAMPLES))/expFactor - 1.0/expFactor)/(1-1.0/expFactor);
		float dd = pow(expFactor, float(i+dither)/float(SAMPLES)) * log(expFactor) / float(SAMPLES)/(expFactor-1.0);

		vec3 progressW = gbufferModelViewInverse[3].xyz+cameraPosition + d*dVWorld;
		
		// determine where the vortex area ends and chaotic lightning area begins.
		float vortexBounds = clamp(vortexBoundRange - length(progressW), 0.0,1.0);

        vec3 lightPosition = LightSourcePosition(progressW, cameraPosition, vortexBounds);
		vec3 lightColors = LightSourceColors(vortexBounds, lightningflash);

		float volumeDensity = fogShape(progressW);
		// volumeDensity += max(1.0 - length(vec3(lightPosition.x,lightPosition.y*2,lightPosition.z))/50,0.0) * vortexBounds;
		
		float clearArea =  1.0-min(max(1.0 - length(progressW - cameraPosition) / 100,0.0),1.0);
		float density = min(volumeDensity * clearArea, END_STORM_DENSTIY);

		///// ----- air lighting, the haze
			float distanceFog =  max(1.0 - length(progressW - cameraPosition) / max(far, 32.0 * 13.0),0.0);
			float hazeDensity = min(exp2(distanceFog * -25)+0.0005,1.0);
			vec3 hazeColor = vec3(0.3,0.75,1.0) * 0.3;
			color += (hazeColor - hazeColor*exp(-hazeDensity*dd*dL)) * absorbance;

		///// ----- main lighting
			vec3 voidLighting = vec3(1.0,0.0,0.8) * 0.1 * (1-exp(volumeDensity * -25)) * max(exp2(-1 * sqrt(max(progressW.y - -60,0.0))),0.0) ;

			vec3 ambient = vec3(0.5,0.75,1.0) * 0.2  * (exp((volumeDensity*volumeDensity) * -50) * 0.9 + 0.1);
			float shadows = 0;
			vec3 lightsources = LightSourceLighting(progressW, lightPosition, dither2, volumeDensity, lightColors, vortexBounds);
			vec3 lighting = lightsources + ambient + voidLighting;

			#ifdef THE_ORB
				density += min(50.0*max(1.0 - length(lightPosition)/10,0.0),1.0);
			#endif

		///// ----- blend
			color += (lighting - lighting*exp(-(density)*dd*dL)) * absorbance;
        	absorbance *= exp(-max(density,hazeDensity)*dd*dL);
	}
	// return vec4(0.0,0.0,0.0,1.0);
	return vec4(color, absorbance);
}

float GetCloudShadow(vec3 WorldPos, vec3 LightPos){
    float Shadow = 0.0;

	for (int i=0; i < 3; i++){

	    // vec3 shadowSamplePos = WorldPos - LightPos * (pow(i,0.75)*0.25); 
	    vec3 shadowSamplePos = WorldPos - LightPos * (0.01 + pow(i,0.75)*0.25); 
	    Shadow += fogShape(shadowSamplePos)*END_STORM_DENSTIY;
    }

	return clamp(exp2(Shadow * -5.0),0.0,1.0);
}