#version 460 core
#include <flutter/runtime_effect.glsl>
uniform vec2 uSize;
uniform float uTime;
uniform float uEnergy;
uniform vec2 uTouch;
uniform float uHue;
out vec4 fragColor;

vec3 spectrum(float t) {
  return 0.53 + 0.43 * cos(6.28318 * (t + vec3(0.02, 0.22, 0.43)));
}

void main() {
  vec2 p = (FlutterFragCoord().xy - 0.5 * uSize) / min(uSize.x, uSize.y) * 2.6;
  p -= uTouch * 0.045;
  float t = uTime * 0.42;
  float a = atan(p.y, p.x);
  float r = length(p);
  float pulse = 0.018 * sin(t * 2.0);
  float warp = (0.038 + uEnergy * 0.018) * sin(3.0 * a + t)
             + 0.024 * sin(5.0 * a - t * 1.3) + 0.018 * cos(2.0 * a + t * 0.7);
  float radius = 0.86 + warp + pulse;
  float d = r - radius;
  float inside = 1.0 - smoothstep(-0.004, 0.006, d);
  float z = sqrt(max(0.0, 1.0 - pow(r / radius, 2.0)));
  vec3 normal = normalize(vec3(p / radius, z + 0.06));
  float light = max(0.0, dot(normal, normalize(vec3(-0.45, -0.65, 0.7))));
  float fresnel = pow(1.0 - z, 1.9);
  vec3 blue = vec3(0.25, 0.43, 0.92);
  vec3 pink = vec3(0.82, 0.43, 0.66);
  vec3 peach = vec3(1.0, 0.72, 0.58);
  vec3 rim = mix(blue, pink, 0.5 + 0.5 * sin(a * 2.0 + t * 0.6 + uHue));
  rim = mix(rim, peach, pow(max(0.0, sin(a + t * 0.3)), 5.0) * 0.8);
  vec3 color = vec3(0.026, 0.03, 0.046) + light * vec3(0.025, 0.035, 0.055);
  color += rim * fresnel * 0.85;
  for (int i = 0; i < 3; i++) {
    float fi = float(i);
    float fold = 0.60 + fi * 0.086 + 0.10 * sin(a * 2.0 + t * (0.55 + fi * 0.12) + fi * 1.8)
               + 0.044 * sin(a * 3.0 - t * 0.6 + fi);
    float line = exp(-pow((r - fold) / (0.035 + 0.012 * fi), 2.0));
    float shine = pow(0.5 + 0.5 * sin(a * 2.0 - t + fi * 2.0), 3.0);
    vec3 iridescence = mix(rim, spectrum(a * 0.16 + fi * 0.18 + t * 0.025 + uHue * 0.08), 0.35);
    color += line * shine * iridescence * (0.38 + fi * 0.10);
    color += exp(-abs(r - fold) * 180.0) * shine * iridescence * 0.25;
  }
  float edge = exp(-abs(d) * 140.0);
  color += edge * rim * 0.75;
  float spec = pow(max(0.0, dot(normal, normalize(vec3(-0.45, -0.72, 0.5)))), 80.0);
  color += vec3(0.75, 0.83, 1.0) * spec * 0.75;
  float glow = exp(-abs(d) * 17.0) * 0.18;
  float alpha = max(inside * 0.97, glow);
  color = mix(rim * 0.45, color, inside);
  fragColor = vec4(color * alpha, alpha);
}
