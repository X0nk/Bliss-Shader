/*
--------------------------------------
// hello
// this file is meant to be an interface for map makers (or whoever really do whatever you want) to control the shader in a handfull of ways depending on the circumstances surrounding the player.
// one usage example would be like: When the player is within a specific area within the world coordinates, make it super foggy there.
// this file is specifically made to be drop-in ready inside the shaderpack expected at the file path: shaderpacks/<bliss_vN.N.N>/shaders/CUSTOM_SCENE_PARAMETERS.glsl
--------------------------------------

--------------------------------------
// these are all the parameters you can freely set. you can do it any amount of times in any amount of profiles.
// if a parameter is not written below, it does not exist. writing new parameters will not create anything but a shader compile error.
--------------------------------------

--------------------------------------
// for cloud coverage input numerical values within the range of 0.0 - 2.0
--------------------------------------

    altostratusCoverage = 0.0;
    largeCumulusCoverage = 0.0;
    smallCumulusCoverage = 0.0;

--------------------------------------
// for cloud density input numerical values within the range of 0.0 - 1.0
--------------------------------------

    altostratusDensity = 0.0;
    largeCumulusDensity = 0.0;
    smallCumulusDensity = 0.0;

--------------------------------------
// for fog density input numerical values within the range of 0.0 - 1.0
--------------------------------------

    uniformFogDensity = 0.0;
    clumpyFogDensity = 0.0;
    LocalUniformFogDensity = 0.0;
    LocalClumpyFogDensity = 0.0;

--------------------------------------
// for fog colors, input the numerical color values of red, green and blue, within the range of 0.0 - 1.0 or N/255.0
// this website is extremely helpful, just copy its RGB values https://rgbcolorpicker.com/0-1
--------------------------------------

    localFogColor = vec3(R, G, B);

--------------------------------------
// here are some pre-made functions to make creating profiles more user friendly.
// these are used the same way as the /fill command in-game. i recommend finding world coordinates to use with that command.
// the left most input is the first set of coordinates, the right most input is the second set of coordinates
--------------------------------------

    playerIsInsideArea(vec3(X, Y, Z), vec3(X, Y, Z))

    playerIsOutsideArea(vec3(X, Y, Z), vec3(X, Y, Z))

--------------------------------------
// HOW TO USE: first start with your condition (this code writing formatting is arbitrary)
--------------------------------------

    if(
        conditionIsTrue 
    ){
        thenDoStuff
    }

--------------------------------------
// input some sort of condition to check if its true or false, and then to set the parameters to specific values when it is true.
// these are functional examples of usage
--------------------------------------

    if(
        playerIsWithinArea(vec3(-5, -5, -3), vec3(5, 1, 100))
    ){
        uniformFogDensity = 0.5;
        smallCumulusCoverage = 1.5;
    }
    if(
        playerIsOutsideArea(vec3(-5, -5, -3), vec3(5, 1, 100))
    ){
        uniformFogDensity = 1.5;
        smallCumulusCoverage = 0.0;
        LocalClumpyFogDensity = 0.0;
    }

--------------------------------------
// IMPORTANT INFORMATION
//
// ALL VARIABLE NAMES, UNIFORM NAMES, AND FUNCTION NAMES ARE CASE SENSITIVE
//
// IF THIS FILE IS DELETED, MISSING, NAMED INCORRECTLY, OR IN THE WRONG FILEPATH, THE SHADERPACK WILL THROW AN ERROR: "failed to resolve #include directive --> /lib/scene_controller.glsl"
//
// the code is executed in a very specific order, think top-to-bottom, or the order of operations that math dictates.
// you CAN have multiple profiles alter the same parameters at the same time!
// BUT, the code executed last will be the final result! meaning if many profiles are true at once, the bottom most true one will be the one actually used.
// So dont worry about overlapping profiles! just be aware of the order of operations!
//
// when a custom profile is active, it will overwrite any of bliss's pre-existing profiles
// That includes daily weather, rainy weather, and biome specific enviornments
--------------------------------------
*/

#ifdef DECLARE_UNIFORMS_OR_WRITE_FUNCTIONS_FOR_CUSTOM_SCENE_CONTROLLER_PROFILES
// DECLARE UNIFORMS PROVIDED BY IRIS HERE. if they are already declared elsewhere in the shaderpack, there will be an error. not all uniforms are viable to be used.
// read the iris documentation for a complete list of uniforms to call https://shaders.properties/current/reference/uniforms/overview/

// you can also write functions here if you want. you must follow the syntax of the programming language "GLSL"
// go google that i aint helping you https://wikis.khronos.org/opengl/OpenGL_Shading_Language | https://www.shadertoy.com/
#endif

#ifdef WRITE_CUSTOM_SCENE_CONTROLLER_PROFILES

// WRITE YOUR PROFILES HERE WITHIN THE #ifdef --- DO NOT WRITE ABOVE THE #ifdef OR BELOW THE #endif --- YOU CAN SAFELY REMOVE THIS TEXT AND HAVE NOTHING WRITTEN HERE AT ALL

#endif