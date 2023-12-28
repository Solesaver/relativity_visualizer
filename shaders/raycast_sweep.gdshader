shader_type spatial;

// ----- Uniforms ----- //
// Physics Stuff 
uniform float time;			// current time at camera
uniform float light_speed;
uniform float lorentz;		// cpu must pre-calculate gamma
uniform float speed;		// of reference frame, relative to where everything was authored
uniform vec3 velocity;		// of reference frame, just the direction

// Performance
uniform uint iterations;
uniform float epsilon;

// Set the scene
uniform float bounce_height;
const float annulus_period = 0.5f;
const float bounce_period = 5.0f;
uniform float annulus_radius;
uniform float ball_radius;
uniform vec3 ball_color;
uniform vec3 bg_color;
uniform vec3 floor_color;
uniform vec3 light_pos;		// omni-light
uniform vec3 annulus_pos;

// ----- Helpers ----- //
vec4 get_ball_pos(float t) {
	// Up and down in a circle around the origin
	return vec4(
		sin(t * annulus_period) * annulus_radius + annulus_pos.x,
		sin(t * bounce_period) * bounce_height + annulus_pos.y,
		-cos(t * annulus_period) * annulus_radius + annulus_pos.z,
		t
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
	vec4 camerat = get_transformed_pos(camera, camera);
	
	// get the direction from the camera to the pixel being rendered
	vec3 world_vert = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0f)).xyz;
	vec4 dir = vec4(normalize(world_vert - camera.xyz), -1.0f / light_speed);
	// 1 unit away in space is 1 / c back in time        ^^^^^^^^^^^^^^^^^^^ 
	vec4 dirt = get_transformed_dir(dir);
	
	// initialize colors to background
	vec3 albedo = bg_color;
	vec3 emission = vec3(0.0f);
	
	// ----- Ground ----- //
	if (dirt.y < 0.0f) {
		vec4 hit = camerat - dirt * camerat.y / dirt.y;
		// Hash Pattern
		float scale = 1.0f;
		if (mod(hit.x, 2.0f) < 1.0f)
			scale *= .6f;
		if (mod(hit.z, 2.0f) < 1.0f)
			scale *= .6f;
		
		scale *= dot(normalize(light_pos - hit.xyz), vec3(0.0f, 1.0f, 0.0f));
		albedo = floor_color * max(scale, .1f);
		emission = floor_color * min(scale / 10.0f, .1f);
	}

	// ----- Real Ball ----- //
	bool done = false;
	float t = 0.0f;
	uint i = 0u;
	for (;i < iterations / 10u && !done; ++i) {
		vec4 test = camerat + t * dirt;
		vec4 ball_pos = get_ball_pos(test.w);
		vec3 to_ball = ball_pos.xyz - test.xyz;
		float ball_dp = dot(to_ball, dirt.xyz);
		float dist = length(to_ball);
		if (dist < ball_radius + annulus_radius / 2.0f) {
			done = true;
		}
		else
			t += max(abs(ball_dp) / annulus_radius, 1.0f);
	}
	if (done) {
		done = false;
		for (;i < iterations / 5u && !done; ++i) {
			vec4 test = camerat + t * dirt;
			vec4 ball_pos = get_ball_pos(test.w);
			vec3 to_ball = ball_pos.xyz - test.xyz;
			float ball_dp = dot(to_ball, dirt.xyz);
			float dist = length(to_ball);
			if (dist < ball_radius + bounce_height) {
				done = true;
			}
			else
				t += max(ball_dp / (annulus_radius * bounce_height), .1f);
		}
	}
	if (done) {
		done = false;
		for (; i < iterations && !done; ++i) {
			vec4 test = camerat + t * dirt;
			vec4 ball_pos = get_ball_pos(test.w);
			vec3 to_ball = ball_pos.xyz - test.xyz;
			float ball_dp = dot(to_ball, dirt.xyz);
			float d = sqrt(dot(to_ball, to_ball) - pow(ball_dp,2));
			float dist = length(to_ball);
			if (abs(dist - ball_radius) < epsilon) {
				done = true;
			}
			else
				t += .005;
		}
	}
	if(done) {
		vec4 hit = camerat + t * dirt;
		vec4 ball_pos = get_ball_pos(hit.w);
		float light = dot(normalize(light_pos - hit.xyz), normalize(hit.xyz - ball_pos.xyz));
		albedo = ball_color;
		emission = ball_color * max(min(light, 0.9f),0.01f);
	}
	
	// ----- Ghost Ball ----- //
	vec4 ball_pos_0 = get_transformed_pos(get_ball_pos(camerat.w), camerat);
	vec3 to_ball_0 = ball_pos_0.xyz - camerat.xyz;
	float ball_dp_0 = dot(to_ball_0, normalize(dirt.xyz));
	if (ball_dp_0 > 0.0f) {
		float d = sqrt(dot(to_ball_0, to_ball_0) - pow(ball_dp_0, 2));
		if (d < ball_radius) {
			vec3 hit = camerat.xyz + (ball_dp_0 - sqrt(pow(ball_radius, 2) - pow(d, 2))) * dirt.xyz;
			float light = dot(normalize(light_pos - hit), normalize(hit - ball_pos_0.xyz));
			// It's additive so you can see through it
			albedo += ball_color * max(light, .1f);
			emission += ball_color * max(light, .05f) * .1f;
		}
	}
	
	// Actually set the colors we've been calculating
	ALBEDO = albedo;
	EMISSION = emission;
}
