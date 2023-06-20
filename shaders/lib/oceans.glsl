// THIS FILE IS PUBLIC DOMAIN SO USE IT HOWEVER YOU WANT!
// to make it compatible with your shaderpack use:
#define PHYSICS_OCEAN_SUPPORT
// at the top of your file. When used my mod no longer injects code into
// your shaderpack. It replaces this define statement (before compilation) with


#ifdef PhysicsMod_support
// to customize the water for the physics ocean 

// just some basic consts for the wave function based on afl_ext's shader https://www.shadertoy.com/view/Xdlczl
// the overall shape must stay consistent because it is also computed on the CPU side
// to offset entities (though a custom CPU integration of your shader is possible by
// contacting me on my discord server https://discord.gg/VsNs9xP)
const int PHYSICS_ITERATIONS_OFFSET = 13;
const float PHYSICS_DRAG_MULT = 0.048;
const float PHYSICS_XZ_SCALE = 0.035;
const float PHYSICS_TIME_MULTIPLICATOR = 0.45;
const float PHYSICS_W_DETAIL = 0.75;
const float PHYSICS_FREQUENCY = 6.0;
const float PHYSICS_SPEED = 2.0;
const float PHYSICS_WEIGHT = 0.8;
const float PHYSICS_FREQUENCY_MULT = 1.18;
const float PHYSICS_SPEED_MULT = 1.07;
const float PHYSICS_ITER_INC = 12.0;
const float PHYSICS_NORMAL_STRENGTH = 0.6;

// this is the surface detail from the physics options, ranges from 13 to 48 (yeah I know weird)
uniform int physics_iterationsNormal;
// used to offset the 0 point of wave meshes to keep the wave function consistent even
// though the mesh totally changes
uniform vec2 physics_waveOffset;
// used for offsetting the local position to fetch the right pixel of the waviness texture
uniform ivec2 physics_textureOffset;
// time in seconds that can go faster dependent on weather conditions (affected by weather strength
// multiplier in ocean settings
uniform float physics_gameTime;
// base value is 13 and gets multiplied by wave height in ocean settings
uniform float physics_oceanHeight;
// basic texture to determine how shallow/far away from the shore the water is
uniform sampler2D physics_waviness;
// basic scale for the horizontal size of the waves
uniform float physics_oceanWaveHorizontalScale;
// used to offset the model to know the ripple position
uniform vec3 physics_modelOffset;
// used for offsetting the ripple texture
uniform float physics_rippleRange;
// controlling how much foam generates on the ocean
uniform float physics_foamAmount;
// controlling the opacity of the foam
uniform float physics_foamOpacity;
// texture containing the ripples (basic bump map)
uniform sampler2D physics_ripples;
// foam noise
uniform sampler3D physics_foam;
// just the generic minecraft lightmap, you can remove this and use the one supplied by Optifine/Iris
uniform sampler2D physics_lightmap;
#ifdef PHYSICSMOD_VERTEX
    // for the vertex shader stage
    out vec3 physics_localPosition;
    out float physics_localWaviness;
#endif

#ifdef PHYSICSMOD_FRAGMENT
    // for the fragment shader stage
    in vec3 physics_localPosition;
    in float physics_localWaviness;
#endif

float physics_waveHeight(vec2 position, int iterations, float factor, float time) {
    position = (position - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        position -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
}

vec2 physics_waveDirection(vec2 position, int iterations, float time) {
    position = (position - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    vec2 dx = vec2(0.0);
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, position) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL); 
        position -= force * PHYSICS_DRAG_MULT;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    return vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
}

// vec3 physics_waveNormal(vec2 position, float factor, float time) {
//     vec2 wave = -physics_waveDirection(position.xy, physics_iterationsNormal, time);
//     float oceanHeightFactor = physics_oceanHeight / 13.0;
//     float totalFactor = oceanHeightFactor * factor;
//     return normalize(vec3(wave.x * totalFactor, PHYSICS_NORMAL_STRENGTH, wave.y * totalFactor));
// }

// thank you Null. not sure if this is legal though lmfao 
vec3 physics_waveNormal_ripples(vec2 position, float factor, float time) {
    vec2 wave = -physics_waveDirection(position.xy, physics_iterationsNormal, time);
    float oceanHeightFactor = physics_oceanHeight / 13.0;
    float totalFactor = oceanHeightFactor * factor;
    vec3 waveNormal = normalize(vec3(wave.x * totalFactor, PHYSICS_NORMAL_STRENGTH, wave.y * totalFactor));
    
	vec2 eyePosition = position + physics_modelOffset.xz;
    vec2 rippleFetch = (eyePosition + vec2(physics_rippleRange)) / (physics_rippleRange * 2.0);
    vec2 rippleTexelSize = vec2(2.0 / textureSize(physics_ripples, 0).x, 0.0);
    float left = texture(physics_ripples, rippleFetch - rippleTexelSize.xy).r;
    float right = texture(physics_ripples, rippleFetch + rippleTexelSize.xy).r;
    float top = texture(physics_ripples, rippleFetch - rippleTexelSize.yx).r;
    float bottom = texture(physics_ripples, rippleFetch + rippleTexelSize.yx).r;
    float totalEffect = left + right + top + bottom;
    
    float normalx = left - right;
    float normalz = top - bottom;
    vec3 rippleNormal = normalize(vec3(normalx, 1.0, normalz));
    waveNormal = normalize(mix(waveNormal, rippleNormal, pow(totalEffect, 0.5)));

    return waveNormal;
}


struct WavePixelData {
    vec2 direction;
    vec2 worldPos;
    vec3 normal;
    float foam;
    float height;
} wave;

WavePixelData physics_wavePixel(const in vec2 position, const in float factor, const in float iterations, const in float time) {
    vec2 wavePos = (position.xy - physics_waveOffset) * PHYSICS_XZ_SCALE * physics_oceanWaveHorizontalScale;
    float iter = 0.0;
    float frequency = PHYSICS_FREQUENCY;
    float speed = PHYSICS_SPEED;
    float weight = 1.0;
    float height = 0.0;
    float waveSum = 0.0;
    float modifiedTime = time * PHYSICS_TIME_MULTIPLICATOR;
    vec2 dx = vec2(0.0);
    
    for (int i = 0; i < iterations; i++) {
        vec2 direction = vec2(sin(iter), cos(iter));
        float x = dot(direction, wavePos) * frequency + modifiedTime * speed;
        float wave = exp(sin(x) - 1.0);
        float result = wave * cos(x);
        vec2 force = result * weight * direction;
        
        dx += force / pow(weight, PHYSICS_W_DETAIL); 
        wavePos -= force * PHYSICS_DRAG_MULT;
        height += wave * weight;
        iter += PHYSICS_ITER_INC;
        waveSum += weight;
        weight *= PHYSICS_WEIGHT;
        frequency *= PHYSICS_FREQUENCY_MULT;
        speed *= PHYSICS_SPEED_MULT;
    }
    
    
    WavePixelData data;
    data.direction = -vec2(dx / pow(waveSum, 1.0 - PHYSICS_W_DETAIL));
    data.worldPos = wavePos / physics_oceanWaveHorizontalScale / PHYSICS_XZ_SCALE;
    data.height = height / waveSum * physics_oceanHeight * factor - physics_oceanHeight * factor * 0.5;
    data.normal = physics_waveNormal_ripples(position, factor, time);

    float waveAmplitude = data.height * pow(max(data.normal.y, 0.0), 4.0);
    vec2 waterUV = mix(position - physics_waveOffset, data.worldPos, clamp(factor * 2.0, 0.2, 1.0));
    
    vec2 s1 = textureLod(physics_foam, vec3(waterUV * 0.26, vec3(time) / 360.0), 0).rg;
    vec2 s2 = textureLod(physics_foam, vec3(waterUV * 0.02, vec3(time) / 360.0 + 0.5), 0).rg;
    vec2 s3 = textureLod(physics_foam, vec3(waterUV * 0.1,  vec3(time) / 360.0 + 1.0), 0).rg;
    
    float waterSurfaceNoise = s1.r * s2.r * s3.r * 2.8 * physics_foamAmount;
    waveAmplitude = clamp(waveAmplitude * 1.2, 0.0, 1.0);
    waterSurfaceNoise = (1.0 - waveAmplitude) * waterSurfaceNoise + waveAmplitude * physics_foamAmount;
    
    float worleyNoise = 0.2 + 0.8 * s1.g * (1.0 - s2.g);
    float waterFoamMinSmooth = 0.45;
    float waterFoamMaxSmooth = 2.0;
    waterSurfaceNoise = smoothstep(waterFoamMinSmooth, 1.0, waterSurfaceNoise) * worleyNoise;
    
    data.foam = clamp(waterFoamMaxSmooth * waterSurfaceNoise * physics_foamOpacity, 0.0, 1.0);
    
    return data;
}
#endif