shader_type sky;

void sky() {
    float v = SKY_COORDS.g;
    vec3 blueish = vec3(0.3, 0.5, 1.0) / 2.0;
    vec3 grey = vec3(0.37, 0.37, 0.52) / 2.0;
    vec3 black = vec3(0.03, 0.03, 0.05) / 2.0;

	if (v < 0.33) {
    	COLOR = blueish;
	} else {
    	COLOR = mix(blueish, grey, (v - 0.33) / (1.0 - 0.33));
	}
}
