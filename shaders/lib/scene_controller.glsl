#if defined USE_SCENE_CONTROLLER_SETTINGS
/*===============================================================================================================================================================
=============== HOW TO MAKE FUNCTIONAL CUSTOM SCENE CONTROLLER PARAMETERS ===============

THERE ARE 2 FILES YOU NEED TO OPEN INSIDE OF THE SHADERPACK FOLDER AS TO OPERATE WITHIN
- the "shaders.properties" file located in shaderpacks/bliss/shaders/shaders.properties
- the "scene_controller.glsl" file located in shaderpacks/bliss/shaders/lib/scene_controller.glsl (you are already in it reading its contents)

you can create a custom configuration of parameters that appear in specific circumstances within minecraft.
to do this, you first need to know when you are in a specific circumstance.
you need to create "triggers", which have 2 states, a true and a false state. these are known as "boolean" variables
here is a step by step process of how to create and use your own custom uniform "trigger", and use it to activate your own parameters in the scene controller.

------------- STEP 1 -------------
create a "custom uniform". it should be a boolean value that returns as true or false.
these are created and named in the "shaders.properties" file
take note of writing style and syntax or errors will happen

examples:

blank slates for syntax clarity
uniform.bool.blankBool = if(VALUE <is greater/less than, or equal to> ANOTHER_VALUE)
uniform.bool.blankBool = if(VALUE > ANOTHE_RVALUE)
uniform.bool.blankBool = if(VALUE < ANOTHER_VALUE)
uniform.bool.blankBool = if(VALUE == ANOTHER_VALUE)
uniform.bool.blankBool = in(biome, BIOME_A, BIOME_B, BIOME_C)
uniform.bool.blankBool = in(biome, BIOME_A)

uniform.bool.nameWhateverYouWant_isExampleBool1 = in(biome, BIOME_DARK_FOREST, BIOME_DESERT, BIOME_PLAINS)
uniform.bool.nameWhateverYouWant_isExampleBool2 = if(nightvision > 0.0)
uniform.bool.nameWhateverYouWant_isExampleBool3 = if(cameraPosition.x < 40.0 && cameraPosition.y > -100.0)
uniform.bool.nameWhateverYouWant_isExampleBool4 = if(rainStrength > 0.0)
uniform.bool.nameWhateverYouWant_isExampleBool5 = if(eyeBrightness.x/240.0 > 0.0)

there are many things you can detect (this is by no means a complete list, links to the iris documentation of what you can detect are linked below)
-if it is raining/thunderstorming (snowing and raining are one in the same here sadly)
-what biome the player is standing in
-the torch/sky light level the player is standing in
-the position in world coordinates the player is standing in
-if the player is above or under water/lava/powderedsnow
-if the player has above or below specific health/armor/hunger values
-if the player has nightvision/darkness/blindness/invisibility (theres only a few potion status effects you can detect)
-if the player is on fire or not

documentation for creating custom uniforms in shaders.properties https://shaders.properties/current/reference/shadersproperties/custom_uniforms/
documentation for player status related uniforms https://shaders.properties/current/reference/uniforms/status/
documentation for player position/camera related uniforms https://shaders.properties/current/reference/uniforms/camera/

------------- STEP 2 -------------
declare/call the variable in the "scene_controller.glsl" file
this is required to make use of the custom uniform you made in the shader.properties file
take note of writing style and syntax or errors will happen

example:

uniform bool nameWhateverYouWant_isExampleBool1;
uniform bool nameWhateverYouWant_isExampleBool2;
uniform bool nameWhateverYouWant_isExampleBool3;

------------- STEP 3 -------------
use the custom uniform
in the scene_controller.glsl file, within the applySceneControllerParameters() function, there is a designated area.
in that area, you will check if the custom uniforms you have made are true or false or "triggered", and if any are true, make the parameters equal whatever values you want.
take note of writing style and syntax or errors will happen

example:

blank slate for syntax clarity
if( <arguements go here> ){
 <what runs does when the arguement is true>;
}

if( nameWhateverYouWant_isExampleBool1 ){
    smallCumulusCoverage = 1.0;
	smallCumulusDensity = 0.5;
    fogColor = vec3(1.0, 0.0, 0.0);
}
if( nameWhateverYouWant_isExampleBool2 ){
    smallCumulusCoverage = 0.0;
	smallCumulusDensity = 0.2;
    fogColor = vec3(1.0, 1.0, 1.0);
}
if( nameWhateverYouWant_isExampleBool3 ){
    smallCumulusCoverage = 0.0;
	smallCumulusDensity = 0.2;
    fogColor = vec3(1.0, 1.0, 1.0);
}


for color picking, the shader is mixing RGB values together. the values are in the 0.0 to 1.0 range instead of 0.0 to 255.0

example:
vec3 exampleColor1 = vec3(RedValue, GreenValue, BlueValue);
vec3 exampleColor2 = vec3(1.0, 0.724, 0.1114);

this is a handy tool for colorpicking in the correct number range: https://rgbcolorpicker.com/0-1

------------- STEP 4 -------------
save both files, and reload the shaderpack (you can click R or just enable/disable it).
that is the end of the guide.

=============== DEBUGGING ===============
for debugging shaders.properties, you will need to
1. look at the game's latest.log, it will spit errors out, while nothing apparent will be wrong in-game when reloading the shader

for debugging scene_controller.glsl,you will need to
1. open the shaderpacks selection menu
2. click the key combination CTRL + D and enable debug mode
3. if errors happen it will tell you whats wrong, kind of.

if you follow syntax it should not error, if it does, check for incorrect:
-spelling (capitalization, incorrect variable names)
-use of semicolons ; (they should be a stopper at the end-point of EVERY line of code but only in scene_controller.glsl. DO NOT use them like that in shaders.propertes, or it will error)
-use of brackets ()
-use of other brackets {}

=============== IMPORTANT NOTES ===============
different custom uniforms SHOULD NOT be allowed to return true at the same times, otherwise they will overwrite eachother in order of what is done last, reading from the top of the file to the bottom.

example:

if you make a custom uniform that returns true if the player is in the swamp, and a second different custom uniform that returns true when a player is above the Y coord of 40

if( isInSwampBiome ){
    smallCumulusCoverage = 1.0;
	smallCumulusDensity = 0.5;
}
if( isAboveYCoord ){
    smallCumulusCoverage = 0.2;
	smallCumulusDensity = 0.1;
}

THIS WILL CONFLICT if you are at the same time in a swamp, and above Y coord 40.
in this case, isAboveYCoord's settings wins and will overwrite isInSwampBiome's settings.
this will not cause an error or warning, its just how the math works and how the shader compiler reads the code.

YOU CANNOT ADD NEW PARAMETERS TO CONTROL, YOU ARE ONLY ABLE TO CONTROL PRE-EXISTING ONES
BECAUSE ADDING NEW ONES IS ALOT MORE COMPLEX AND REQUIRES KNOWING HOW TO CODE IN GLSL AND KNOWLEDGE OF HOW THE SHADER IS DESIGNED
===============================================================================================================================================================*/



//=============== DECLARE UNIFORMS BELOW HERE ===============
uniform int worldDay;
//=============== DECLARE UNIFORMS ABOVE HERE ===============

void applySceneControllerParameters(
	out float smallCumulusCoverage, out float smallCumulusDensity,
	out float largeCumulusCoverage, out float largeCumulusDensity,
	out float altostratusCoverage, out float altostratusDensity,
	out float fogA, out float fogB
){
    // these are the default parameters if no "trigger" or custom uniform is being used.
    // do not remove them
    smallCumulusCoverage = CloudLayer0_coverage;
	smallCumulusDensity = CloudLayer0_density;
	largeCumulusCoverage = CloudLayer1_coverage;
    largeCumulusDensity = CloudLayer1_density;
	altostratusCoverage = CloudLayer2_coverage;
    altostratusDensity = CloudLayer2_density;
	fogA = 1.0;
    fogB = 1.0;

//=============== CONFIGURE CUSTOM SCENE PARAMETERS BELOW HERE ===============

//=============== CONFIGURE CUSTOM SCENE PARAMETERS ABOVE HERE ===============
}
#endif



//====================================================================================================================================================================
//=============== EVERYTHING BELOW HERE IS NOT FOR CUSTOM SCENE CONTROLLER STUFF AND SHOULD NOT BE MODIFIED UNLESS YOU KNOW EXACTLY WHAT YOU ARE DOING ===============
//====================================================================================================================================================================


// write various parameters within singular pixels of a texture, which is a non-clearing buffer reprojecting the previous frame of itself, onto itself.
// this allows smooth interpolation over time from any old parameter value, to any new parameter value.

// read in vertex stage of post processing passes (deferred, composite), so it only runs on 4 vertices
// pass to fragment stage for use.

// the parameters are stored as such:
// smallCumulus = (coverage, density)
// largeCumulus = (coverage, density)
// altostratus = (coverage, density)
// fog = (uniform fog density, cloudy fog density)
// ... and more, eventually

flat varying struct sceneController {
  vec2 smallCumulus;
  vec2 largeCumulus;
  vec2 altostratus;
  vec2 fog;
} parameters;

vec3 writeSceneControllerParameters(
	vec2 uv,
    vec2 smallCumulus,
	vec2 largeCumulus,
	vec2 altostratus,
	vec2 fog
){

    // in colortex4, data is written in a 3x3 pixel area from (1,1) to (3,3)
    // avoiding use of any variation of (0,0) to avoid weird textture wrapping issues
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
    
    /* (1,3) */ bool topLeft = uv.x > 1 && uv.x < 2 && uv.y > 3 && uv.y < 4;
    /* (2,3) */ bool topMiddle = uv.x > 2 && uv.x < 3 && uv.y > 3 && uv.y < 4;
    // /* (3,3) */ bool topRight = uv.x > 3 && uv.x < 5 && uv.y > 3 && uv.y < 4;
    // /* (1,2) */ bool middleLeft = uv.x > 1 && uv.x < 2 && uv.y > 2 && uv.y < 3;
    // /* (2,2) */ bool middleMiddle = uv.x > 2 && uv.x < 3 && uv.y > 2 && uv.y < 3;
    // /* (3,2) */ bool middleRight = uv.x > 3 && uv.x < 5 && uv.y > 2 && uv.y < 3;
    // /* (1,1) */ bool bottomLeft = uv.x > 1 && uv.x < 2 && uv.y > 1 && uv.y < 2;
    // /* (2,1) */ bool bottomMiddle = uv.x > 2 && uv.x < 3 && uv.y > 1 && uv.y < 2;
    // /* (3,1) */ bool bottomRight = uv.x > 3 && uv.x < 5 && uv.y > 1 && uv.y < 2;

    vec3 data = vec3(0.0,0.0,0.0);

    if(topLeft) data = vec3(smallCumulus.xy, largeCumulus.x);
    if(topMiddle) data = vec3(largeCumulus.y, altostratus.xy);

    // if(topRight)  	 data = vec4(groundSunColor,fogSunColor.r);
    // if(middleLeft)   data = vec4(groundAmbientColor,fogSunColor.g);
    // if(middleMiddle) data = vec4(fogAmbientColor,fogSunColor.b);
    // if(middleRight)  data = vec4(cloudSunColor,cloudAmbientColor.r);
    // if(bottomLeft)   data = vec4(cloudAmbientColor.gb,0.0,0.0);
    // if(bottomMiddle) data = vec4(0.0);
    // if(bottomRight)  data = vec4(0.0);

    return data;
}

void readSceneControllerParameters(
	sampler2D colortex,
	out vec2 smallCumulus,
	out vec2 largeCumulus,
	out vec2 altostratus,
	out vec2 fog
){
    
    // in colortex4, read the data stored within the 3 components of the sampled pixels, and pass it to the fragment stage
    // 4th compnent/alpha is storing 1/4 res depth so i cant store there lol
	vec3 data1 = texelFetch2D(colortex,ivec2(1,3),0).rgb/150.0;
	vec3 data2 = texelFetch2D(colortex,ivec2(2,3),0).rgb/150.0;

	smallCumulus = vec2(data1.x,data1.y);
	largeCumulus = vec2(data1.z,data2.x);
	altostratus = vec2(data2.y,data2.z);
	fog = vec2(0.0);
}
