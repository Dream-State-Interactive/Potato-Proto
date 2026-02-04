shader_type canvas_item;

uniform float speed = 3.0;
uniform float scale_amount = 0.15;

void vertex() {
	// Generates a unique offset based on World Position so they don't all pulse in sync
	float time_offset = MODEL_MATRIX[3].x * 0.01 + MODEL_MATRIX[3].y * 0.01;
	float pulse = sin(TIME * speed + time_offset);
	
	// Scale the vertex positions from the center
	VERTEX *= 1.0 + (pulse * scale_amount);
}