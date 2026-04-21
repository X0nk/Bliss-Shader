/*
const int colortex0Format = RGBA16F;				// low res clouds (deferred->composite2) + low res VL (composite5->composite15)
const int colortex1Format = RGBA16;					// ENCODE albedo + rp normals + lightmaps + pixel masks (gbuffer->composite2)
const int colortex2Format = RGBA16F;				// forward + transparencies (gbuffer->composite4)
const int colortex3Format = R11F_G11F_B10F;			// frame buffer + bloom (deferred6->final)
const int colortex4Format = RGBA16F;				// LUT - light values and skyboxes (everything)
const int colortex6Format = R11F_G11F_B10F;			// additional buffer for bloom (composite3->final)
const int colortex7Format = RGBA8;					// Final output, transparencies id (gbuffer->composite4)
const int colortex8Format = RGBA16;					// ENCODE Specular + geonormal + vanilla AO
const int colortex9Format = RGBA16F;				// resourcepack sky -> cleared in deferred -> rain in alpha
const int colortex10Format = RGBA16F;				// history buffer for volumetric fog and clouds
const int colortex11Format = RGBA16; 				// unchanged translucents albedo, alpha and tangent normals
const int colortex12Format = RGBA16F;				// DISTANT HORIZONS + VANILLA MIXED DEPTHs
const int colortex13Format = RGBA16F;				// low res VL (composite5->composite15)
const int colortex14Format = RGBA16F;				// alpha = lightmaps from translucents -> (composite) .xy = SSAO/SS -> (composite2)
const int colortex15Format = RGBA8;
*/

#ifdef SCREENSHOT_MODE
	/*
	const int colortex5Format = RGBA32F;			//TAA history buffer
	*/
#else
	/*
	const int colortex5Format = RGBA16F;			//TAA history buffer
	*/
#endif

const bool colortex0Clear = false;
const bool colortex1Clear = false;
const bool colortex2Clear = true;
const bool colortex3Clear = false;
const bool colortex4Clear = false;
const bool colortex5Clear = false;
const bool colortex6Clear = false;
const bool colortex7Clear = false;
const bool colortex8Clear = false;
const bool colortex9Clear = true;
const bool colortex10Clear = false;
const bool colortex11Clear = true;
const bool colortex12Clear = false;
const bool colortex13Clear = false;
const bool colortex14Clear = true;
const bool colortex15Clear = false;