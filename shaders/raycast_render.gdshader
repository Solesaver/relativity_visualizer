shader_type spatial;

// ----- Uniforms ----- //
// Physics Stuff 
uniform float time;			// current time at camera
uniform float light_speed;
uniform float lorentz;		// cpu must pre-calculate gamma
uniform float speed;		// of reference frame, relative to where everything was authored
uniform vec3 velocity;		// of reference frame, just the direction

// Fine tune cost
uniform uint resolution;	// max number of intervals per ray
uniform uint max_refine;	// max number of successive refinement rays
uniform float refinement;	// factor for each successive ray
uniform float draw_dist;
uniform float epsilon;

// Set the scene
uniform float ball_radius;
uniform vec3 ball_color;
uniform vec3 bg_color;
uniform vec3 floor_color;
uniform vec3 light_pos;		// omni-light

// ----- Helpers ----- //
vec3 get_ball_pos(float t) {
	// Up and down in a circle around the origin
	return vec3(
		sin(t) * 10.0,
		sin(t * 10.0) * 2.0 + 3.0,
		cos(t) * -10.0
	);
}

// Lorentz Tranform!
vec4 get_transformed_dir(vec4 dir) {
	float mag = dot(dir.xyz, velocity);
	return vec4(
		dir.xyz - mag * velocity + lorentz * (mag - dir.w * speed) * velocity,
		// ^^  perpendicular  ^^   ^^               parallel               ^^
		lorentz * (dir.w - speed * mag / exp2(light_speed))
	);
	//return dir; // swap to this when everything breaks to remove Lorentz
}
vec4 get_transformed_pos(vec4 pos, vec4 cam) {
	return get_transformed_dir(pos - cam) + cam;
}

// ----- Shaders ------ //
// A pixel shader!
void fragment() {
	// the current origin event in spacetime
	vec4 camera = vec4(CAMERA_POSITION_WORLD, time);
	
	// get the direction from the camera to the pixel being rendered
	vec3 world_vert = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0f)).xyz;
	vec4 base_dir = vec4(normalize(world_vert - camera.xyz), -1.0f / light_speed);
	// 1 unit away in space is 1 / c back in time            ^^^^^^^^^^^^^^^^^^^ 
	
	// initialize the ghost vars for later
	vec3 ghost_center = vec3(0.0f);
	vec3 ghost_hit = vec3(0.0f);
	bool ghost = false;
	
	// initialize colors to background
	vec3 albedo = bg_color;
	vec3 emission = vec3(0.0f);
	
	// calculate how far each step has to move
	float iter_dist = sqrt(light_speed) * draw_dist / float(resolution);
	base_dir *= iter_dist;
	
	// initilize the refinement variables
	uint refine = 1u;
	uint iter = 0u;
	
	// dir now scaled for stepping
	vec4 dir = base_dir;
	vec4 dirt = get_transformed_dir(dir);	
	float min_time = time - (draw_dist / sqrt(light_speed));
	
	// ray starts at the camera
	vec4 test = camera;
	vec4 testt = get_transformed_pos(test, camera);
	// outer loop over refinement passes
	while (iter < refine && iter < max_refine) {
		// initialize out loop tracking variables
		bool term = false;
		bool again = false;
		// inner loop the ray steps, early outs if we need to refine or bail
		for (uint i = 0u; !again && !term && i < resolution && testt.w > min_time; ++i) {
			// step the ray
			testt += dirt;
			
			vec3 ball_pos = get_ball_pos(testt.w);
			float dist = distance(ball_pos, testt.xyz);
			if (!term && dist < ball_radius + pow(1.0f / refinement, float(refine))) {
				if (dist - ball_radius < epsilon) {
					vec3 toCenter = normalize(testt.xyz - ball_pos);
					vec3 toLight = normalize(light_pos - testt.xyz);
					float light = dot(toLight, toCenter);
					albedo = ball_color;
					emission = ball_color * min(light, 0.9);
					term = true;
					again = false;
				}
				// if we're close, but not close enough, try again
				else
					again = true;
			}
			// ----- Ground ----- //
			else if (!term && testt.y < 0.0f) {
				float ratio = testt.y / dirt.y;
				vec4 hit = testt - dirt * ratio;
				// Hash Pattern
				float scale = 1.0f;
				if (mod(hit.x, 2.0f) < 1.0f)
					scale *= .6f;
				if (mod(hit.z, 2.0f) < 1.0f)
					scale *= .6f;
				
				vec3 toLight = normalize(light_pos - hit.xyz);
				scale *= dot(toLight, vec3(0.0f, 1.0f, 0.0f));
				albedo = floor_color * max(scale, .1f);
				emission = floor_color * min(scale / 10.0f, .1f);
				term = true;
				again = false;
			}
			// Ghost of the ball as if light was instantaneous (still respects Lorentz)
			else if (!ghost) {
				// Need the position at origin time
				ball_pos = get_ball_pos(time);
				dist = distance(testt.xyz, ball_pos);
				// Some buffer for before the refinement
				if (dist < ball_radius + pow(1.0f / refinement, float(refine))) {
					if (abs(dist - ball_radius) < 0.01f) {
						ghost_center = ball_pos;
						ghost_hit = testt.xyz;
						ghost = true;
					}
					// Close, but not close enough
					else
						again = true;
				}
			}
		}
		// Back in the outer loop, update the iterator
		++iter;
		// If someone wanted a closer look
		if (again) {
			// Take a step back
			testt -= dirt;
			// And go slower next time
			dirt /= refinement;
			++refine;
		}
		// This is for when a near miss shortens our render distance
		// Keep going with full steps
		else if (!term && testt.w > -min_time) {
			dirt = get_transformed_dir(base_dir);
			refine = iter + 1u;
		}
	}
	
	// We had to save ghost rendering for the end
	if (ghost) {
		vec3 toCenter = normalize(ghost_hit - ghost_center);
		vec3 toLight = normalize(light_pos - ghost_hit);
		float light = dot(toLight, toCenter);
		// It's additive so you can see through it
		albedo += ball_color * max(light, .1f);
		emission += ball_color * max(light, .05f) * .1f;
	}
	
	// Actually set the colors we've been calculating
	ALBEDO = albedo;
	EMISSION = emission;
}
