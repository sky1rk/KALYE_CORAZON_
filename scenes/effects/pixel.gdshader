// File: pixelate.gdshader
shader_type canvas_item;

// The uniform 'pixel_size' will appear in the Inspector, allowing you to change
// the size of the pixel blocks in real-time.
// A hint_range makes it a convenient slider.
uniform float pixel_size : hint_range(1.0, 50.0) = 4.0;

// Godot provides the last rendered frame in the SCREEN_TEXTURE built-in.
// We use filter_nearest to keep the pixels sharp and blocky.
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;

void fragment() {
    // SCREEN_PIXEL_SIZE is the size of one pixel in UV coordinates (a vec2).
    // To get the full resolution of the screen in pixels, we take its inverse.
    vec2 screen_resolution = 1.0 / SCREEN_PIXEL_SIZE;

    // 1. Scale the UV coordinates up by the screen resolution. Now they go from (0,0) to (width, height).
    // 2. Divide by our desired pixel_size to get coordinates in our "big pixel" grid.
    // 3. Use floor() to snap the coordinate to the top-left corner of the current "big pixel" cell.
    // 4. Multiply back by pixel_size and divide by screen_resolution to convert the coordinate
    //    back into the 0-1 UV space.
    vec2 blocky_uv = floor(SCREEN_UV * screen_resolution / pixel_size) * pixel_size / screen_resolution;

    // Sample the screen texture using this new, blocky UV coordinate.
    // Every pixel within the same "big pixel" block will now sample the same color,
    // creating the pixelation effect.
    vec4 screen_color = texture(SCREEN_TEXTURE, blocky_uv);

    // Set the output color for this fragment.
    COLOR = screen_color;
}