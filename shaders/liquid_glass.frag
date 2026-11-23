#include <flutter/runtime_effect.glsl>

uniform vec2 u_size;
uniform float u_round;
uniform sampler2D u_texture;

out vec4 frag_color;

vec4 glassSample(vec2 uv) {
  vec2 safe = clamp(uv, vec2(0.001), vec2(0.999));
  vec4 sampleColor = texture(u_texture, safe);
  vec3 onWhite = mix(vec3(0.97), sampleColor.rgb, sampleColor.a);
  return vec4(onWhite, 1.0);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / u_size;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif

  vec2 centered = uv * 2.0 - 1.0;
  float radius = length(centered);
  vec2 direction = centered / max(radius, 0.001);

  // u_round is 1 for a circle and 0 for a pill. A circular lens on a wide
  // chip pulls the bottom-right corner out of the rounded outline.
  float bulge = u_round * smoothstep(0.2, 1.0, radius);
  vec2 bent = clamp(uv - direction * bulge * 0.04, vec2(0.001), vec2(0.999));

  float split = u_round * 0.003 * bulge;
  vec3 color;
  color.r = glassSample(bent + direction * split).r;
  color.g = glassSample(bent).g;
  color.b = glassSample(bent - direction * split).b;

  float fresnel = u_round * pow(clamp(radius, 0.0, 1.0), 3.0);
  vec3 rim = vec3(1.0) * fresnel * 0.22;
  vec2 specUv = (uv - vec2(0.5, 0.18)) * vec2(1.2, 2.2);
  float spec = pow(clamp(1.0 - length(specUv), 0.0, 1.0), 4.0);

  frag_color = vec4(color + rim + vec3(spec) * 0.22, 1.0);
}
