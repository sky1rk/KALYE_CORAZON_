// File: box_blur.gdshader
shader_type canvas_item;

// The strength of the blur. Larger values mean a wider sample area.
uniform float blur_amount : hint_range(0.0, 5.0) = 1.0;

// The built-in screen texture. filter_linear helps smooth the result slightly.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear;

void fragment() {
    // The size of a single pixel in UV coordinates.
    // We'll use this to step to neighboring pixels.
    vec2 pixel_uv = SCREEN_PIXEL_SIZE;

    vec4 accumulated_color = vec4(0.0);
    int sample_count = 0;

    // This is the "box". A 5x5 grid.
    // We loop from -2 to +2 in both X and Y directions.
    for (int x = -2; x <= 2; x++) {
        for (int y = -2; y <= 2; y++) {
            // Calculate the UV coordinate of the neighboring pixel
            vec2 offset = vec2(float(x), float(y)) * pixel_uv * blur_amount;
            vec2 sample_uv = SCREEN_UV + offset;

            // Add the neighbor's color to our accumulator
            accumulated_color += texture(SCREEN_TEXTURE, sample_uv);
            sample_count++;
        }
    }

    // Divide the total color by the number of samples to get the average.
    COLOR = accumulated_color / float(sample_count);
}