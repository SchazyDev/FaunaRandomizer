shader_type canvas_item;

uniform bool invert = false;

void fragment()
{
    float gradient = invert ? 1.0 - UV.y : 0.0 + UV.y;
    COLOR = vec4(0.0, 0.0, 0.0, gradient);
}