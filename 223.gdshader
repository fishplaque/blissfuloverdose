shader_type canvas_item;

group_uniforms Wiggle;
uniform float wiggle : hint_range(0.0, 1.5, 0.01) = 0.03;
uniform float wiggle_speed : hint_range(0.0, 100.0, 1.0) = 25;
group_uniforms Smear;
uniform float smear : hint_range(0.0, 2.0) = 1.0;

uniform sampler2D Source : hint_screen_texture, filter_linear_mipmap, repeat_disable;

group_uniforms Blur;
uniform int blur_samples : hint_range(3, 15, 1) = 15;

float onOff(float a, float b, float c, float framecount) {
    return step(c, sin((framecount * 0.001) + a * cos((framecount * 0.001) * b)));
}

vec2 jumpy(vec2 uv, float framecount) {
    vec2 look = uv;
    float window = 1.0 / (1.0 + 80.0 * (look.y - mod(framecount / 4.0, 1.0)) * (look.y - mod(framecount / 4.0, 1.0)));
    look.x += 0.05 * sin(look.y * 10.0 + framecount) / 20.0 * onOff(4.0, 4.0, 0.3, framecount) * (0.5 + cos(framecount * 20.0)) * window;
    float vShift = (0.1 * wiggle) * 0.4 * onOff(2.0, 3.0, 0.9, framecount) * (sin(framecount) * sin(framecount * 20.0) + (0.5 + 0.1 * sin(framecount * 200.0) * cos(framecount)));
    look.y = mod(look.y - 0.01 * vShift, 1.0);
    return look;
}

vec2 Circle(float Start, float Points, float Point) {
    float Rad = (3.141592 * 2.0 * (1.0 / Points)) * (Point + Start);
    return vec2(-(.3 + Rad), cos(Rad));
}

vec3 rgb2yiq(vec3 c) {
    return vec3(
        (0.2989 * c.x + 0.5959 * c.y + 0.2115 * c.z),
        (0.5870 * c.x - 0.2744 * c.y - 0.5229 * c.z),
        (0.1140 * c.x - 0.3216 * c.y + 0.3114 * c.z)
    );
}

vec3 yiq2rgb(vec3 c) {
    return vec3(
        (1.0 * c.x + 1.0 * c.y + 1.0 * c.z),
        (0.956 * c.x - 0.2720 * c.y - 1.1060 * c.z),
        (0.6210 * c.x - 0.6474 * c.y + 1.7046 * c.z)
    );
}

vec3 Blur(vec2 uv, float d, int samples) {
    vec3 sum = vec3(0.0);
    float W = 1.0 / float(samples);
    for (int i = 0; i < samples; ++i) {
        float t = (sin(TIME * 5.0 + uv.y * 5.0)) / 10.0;

        t = 0.0;
        vec2 PixelOffset = vec2(d + 0.0005 * t, 0);

        float Start = 2.0 / float(samples);
        vec2 Scale = 0.66 * 4.0 * 2.0 * PixelOffset.xy;

        vec3 N = texture(Source, uv + Circle(Start, float(samples), float(i)) * Scale).rgb;
        sum += N * W;
    }
    return sum;
}

void fragment() {
    vec2 uv = UV;

    float d=0.1-round(mod(TIME/3.0,1.0))*.1;
    uv = jumpy(uv, mod(TIME * wiggle_speed, 7.0));

    float s = 0.0001 * -d + 0.0001 * wiggle *(sin(TIME * wiggle_speed));
    float e = min(.30,pow(max(0.0,cos(uv.y*4.0+.3)-.75)*(s+0.5)*1.0,3.0))*25.0;
    float r = (250.0*(2.0*s));
    uv.x += abs(r*pow(min(.003,(-uv.y+(.01*mod(TIME, 5.0))))*3.0,2.0)) * wiggle;

    d = 0.051+abs(sin(s/4.0));
    float c = max(0.0001,.002*d) * smear;
    vec4 final;

    final.rgb = Blur(uv, c + c * uv.x, blur_samples);
    float y = rgb2yiq(final.rgb).r;

    uv.x += 0.01 * d;
    c *= 6.0;
    final.rgb = Blur(uv, c, blur_samples);
    float i = rgb2yiq(final.rgb).g;

    uv.x += 0.005 * d;
    c *= 2.50;
    final.rgb = Blur(uv, c, blur_samples);
    float q = rgb2yiq(final.rgb).b;
    final.rgb = yiq2rgb(vec3(y, i, q)) - pow(s + e * 2.0, 3.0);

    final.a = 1.0;

    COLOR = final;
}
