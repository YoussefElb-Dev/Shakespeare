#version 460 core
#include <flutter/runtime_effect.glsl>
// Float slots: size(0..1), time(2), energy(3), touch(4..5), hue(6),
// reveal(7), pressure(8). Keep in sync with _OrbPainter in liquid_orb.dart.
uniform vec2 uSize;
uniform float uTime;
uniform float uEnergy;
uniform vec2 uTouch;
uniform float uHue;
uniform float uReveal;
uniform float uPressure;
out vec4 fragColor;

vec3 spectrum(float t) {
  return 0.53 + 0.43 * cos(6.28318 * (t + vec3(0.02, 0.22, 0.43)));
}

float gaussian(float x) {
  return exp(-x * x);
}

void main() {
  vec2 p = (FlutterFragCoord().xy - 0.5 * uSize) / min(uSize.x, uSize.y) * 2.6;
  // Time already integrates the smoothed energy-dependent speed in Dart.
  float t = uTime;
  float energy = clamp(uEnergy, 0.0, 1.0);
  float reveal = clamp(uReveal, 0.0, 1.0);
  // Release early: peak at ~230 ms of a 1600 ms parent-driven reveal,
  // mostly dissipated by 600 ms and completely gone before the text settles.
  float emergence = clamp(reveal / 0.58, 0.0, 1.0);
  float rest = 1.0 - emergence;
  float bloom = 9.48148 * emergence * rest * rest * rest;
  p -= vec2(sin(t * 0.47), cos(t * 0.39)) * 0.012;
  p -= uTouch * uPressure * 0.055;
  float a = atan(p.y, p.x + 0.00001);
  float r = length(p);
  float pulse = (0.015 + energy * 0.008) * sin(t * 1.45);
  float warp = (0.048 + energy * 0.026)
                 * sin(3.0 * a + t * 0.86 + 0.45 * sin(2.0 * a - t * 0.42))
             + (0.027 + energy * 0.020) * sin(5.0 * a - t * 0.73)
             + (0.020 + energy * 0.012) * cos(2.0 * a + t * 0.51)
             + (0.008 + energy * 0.012) * sin(7.0 * a + t * 1.16);
  float touchPull = dot(vec2(cos(a), sin(a)), uTouch) * uPressure;
  float radius = 0.86 - energy * 0.055 + warp + pulse
               + bloom * 0.028 + touchPull * 0.025;
  float d = r - radius;
  float aa = 2.6 / min(uSize.x, uSize.y);
  float inside = 1.0 - smoothstep(-aa, aa, d);
  float radial = r / radius;
  float z = sqrt(max(0.0, 1.0 - radial * radial));
  vec3 normal = normalize(vec3(p / radius, z + 0.06));
  float light = max(0.0, dot(normal, normalize(vec3(-0.45, -0.65, 0.7))));
  float fresnel = pow(1.0 - z, 1.85);
  float flow = a + 0.15 * sin(3.0 * a - t * 0.43)
             + (0.08 + energy * 0.07) * sin(p.y * 4.0 + t * 0.67);
  vec3 blue = vec3(0.25, 0.43, 0.92);
  vec3 pink = vec3(0.82, 0.43, 0.66);
  vec3 peach = vec3(1.0, 0.72, 0.58);
  vec3 rim = mix(blue, pink, 0.5 + 0.5 * sin(flow * 2.0 + t * 0.52 + uHue));
  rim = mix(rim, peach, pow(max(0.0, sin(flow - t * 0.31)), 5.0) * 0.8);
  // Keep the center quiet and dark so the parent's quote remains readable.
  float outer = smoothstep(0.42, 0.80, radial);
  vec3 color = vec3(0.023, 0.028, 0.045) + light * vec3(0.015, 0.020, 0.032);
  color += rim * fresnel * (0.80 + energy * 0.28 + bloom * 0.35);
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float fold = 0.70 + fi * 0.085
               + (0.065 + energy * 0.02) * sin(flow * 2.0 + t * (0.60 + fi * 0.08) + fi * 1.8)
               + 0.03 * sin(flow * 3.0 - t * 0.7 + fi);
    float separation = radial - fold;
    float width = 0.023 + 0.009 * fi + energy * 0.007;
    float line = gaussian(separation / width);
    float veil = gaussian(separation / (width * 3.0));
    float shine = pow(0.5 + 0.5 * sin(flow * 2.0 - t * 0.85 + fi * 2.0), 3.0);
    vec3 iridescence = mix(rim, spectrum(flow * 0.16 + fi * 0.18 + t * 0.035 + uHue * 0.08), 0.28);
    color += outer * shine * iridescence * (line * (0.42 + fi * 0.10 + energy * 0.18)
             + veil * (0.055 + energy * 0.045));
    color += outer * exp(-abs(separation) * 160.0) * shine * iridescence * 0.20;
  }
  float edge = exp(-abs(d) * 125.0);
  float glint = pow(0.5 + 0.5 * sin(flow * 3.0 - t * 1.1), 4.0);
  color += edge * rim * (0.50 + glint * 0.32 + energy * 0.24 + bloom * 0.4);
  float spec = pow(max(0.0, dot(normal, normalize(vec3(-0.45, -0.72, 0.5)))), 80.0);
  color += vec3(0.75, 0.83, 1.0) * spec * outer * (0.65 + energy * 0.25);
  color += rim * outer * uPressure * max(0.0, touchPull) * 0.18;
  float ripple = gaussian((r - (0.54 + emergence * 0.58))
                           / (0.035 + emergence * 0.018)) * bloom;
  color += mix(rim, vec3(0.85, 0.83, 1.0), 0.45) * ripple * outer * 0.48;
  float glow = exp(-abs(d) * (17.0 - energy * 2.0 - bloom * 4.0))
             * (0.17 + energy * 0.12 + bloom * 0.18) + ripple * 0.18;
  float alpha = max(inside * 0.97, glow);
  color = mix(rim * (0.40 + energy * 0.10 + bloom * 0.25), color, inside);
  fragColor = vec4(color * alpha, alpha);
}
