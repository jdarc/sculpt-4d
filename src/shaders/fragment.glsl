#version 300 es
#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

const float EPSILON = 0.001;
const float HUGE = 10000.0;

const float ARC3 = radians(65.0);
const float ARC1 = radians(65.0 + 45.0);
const float ARC4 = radians(65.0 + 90.0);
const float ARC2 = radians(65.0 + 45.0 + 90.0);
const mat3 ROT1 = inverse(mat3(cos(ARC1), 0.0, sin(ARC1), 0.0, 1.0, 0.0, -sin(ARC1), 0.0, cos(ARC1)));
const mat3 ROT2 = inverse(mat3(cos(ARC2), 0.0, sin(ARC2), 0.0, 1.0, 0.0, -sin(ARC2), 0.0, cos(ARC2)));
const mat3 ROT3 = inverse(mat3(cos(ARC3), 0.0, sin(ARC3), 0.0, 1.0, 0.0, -sin(ARC3), 0.0, cos(ARC3)));
const mat3 ROT4 = inverse(mat3(cos(ARC4), 0.0, sin(ARC4), 0.0, 1.0, 0.0, -sin(ARC4), 0.0, cos(ARC4)));

const vec3 ENV_COLOR = vec3(0.7, 0.6, 0.9);
const vec3 LIGHT_COLOR = vec3(0.93, 0.92, 0.94);
const vec3 LIGHT_POS = vec3(200.0, 500.0, 200.0);

const int DIFFUSE = 0;
const int METAL = 1;
const int GLASS = 2;

uniform int uTime;
uniform vec2 uResolution;
uniform mat4 uCameraMatrix;

out vec4 fragColor;

struct Ray { vec3 origin; vec3 direction; };
struct Material { int type; vec3 diffuse; vec3 specular; };
struct Intersection { float distance; vec3 position; vec3 normal; Material material; };

float saturate(float v) {
    return clamp(v, 0.0, 1.0);
}

float sdSphere(vec3 p, float s) {
    return length(p) - s;
}

float sdBox(vec3 p, vec3 b) {
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sdTorus(vec3 p) {
    return length(vec2(length(p.xy) - 0.5, p.z)) - 0.15;
}

float map(vec3 p) {
    float t = min(sdTorus(ROT1 * p - vec3(0.0, 1.1, 0.0)), sdTorus(ROT2 * p.xyz - vec3(0.0, 1.1, 0.0)));
    float g = min(sdTorus(ROT3 * p - vec3(0.0, 0.1, 0.0)), sdTorus(ROT4 * p.xyz - vec3(0.0, 0.1, 0.0)));
    float s = sdSphere(p - vec3(0.0, 1.6, 0.0), 0.5);
    float b = sdBox(p - vec3(0.0, -1.0, 0.0), vec3(1.0, 1.0, 1.0));
    return max(-b, max(min(g, t), -s));
}

Intersection intersectTorus(Ray ray) {
    Intersection result; result.distance = HUGE;
    float t = 0.0;
    for (int i = 0; i < 300; ++i) {
        float h = map(ray.origin + t * ray.direction);
        if (h < EPSILON) {
            vec3 p = ray.origin + ray.direction * t;
            const float eps = EPSILON;
            const vec2 e = vec2(eps, 0.0);
            float nx = map(p + e.xyy) - map(p - e.xyy);
            float ny = map(p + e.yxy) - map(p - e.yxy);
            float nz = map(p + e.yyx) - map(p - e.yyx);
            result.distance = t;
            result.normal = normalize(vec3(nx, ny, nz));
            result.position = p + result.normal * EPSILON;
            return result;
        }
        t += h;
        if (t >= 6.0) break;
    }
    return result;
}

Intersection intersectPlane(Ray ray, vec4 plane) {
    Intersection result; result.distance = HUGE;
    float vd = dot(plane.xyz, ray.direction);
    float t = -(dot(plane.xyz, ray.origin) + plane.w) / vd;
    if (t > EPSILON) {
        result.distance = t;
        result.position = ray.origin + ray.direction * t;
        result.normal = plane.xyz;
    }
    return result;
}

Intersection intersectSphere(Ray ray, vec4 sphere) {
    Intersection result; result.distance = HUGE;
    vec3 oc = ray.origin - sphere.xyz;
    float a = dot(ray.direction, ray.direction);
    float b = 2.0 * dot(oc, ray.direction);
    float c = dot(oc, oc) - sphere.w * sphere.w;
    float discriminant = b * b - 4.0 * a * c;
    if (discriminant < 0.0) { return result; }
    float t = (-b - sqrt(discriminant)) / (2.0 * a);
    if (t > EPSILON) {
        result.distance = t;
        result.position = ray.origin + ray.direction * t;
        result.normal = (result.position - sphere.xyz) / sphere.w;
    }
    return result;
}

bool trace(Ray ray, inout Intersection hit) {
    float closest = HUGE;
    Intersection result;

    result = intersectTorus(ray);
    if (result.distance < closest) {
        hit = result;
        hit.material.type = METAL;
        hit.material.diffuse = vec3(0.5, 0.15, 0.01);
        hit.material.specular = vec3(0.9);
        closest = hit.distance;
    }

    result = intersectSphere(ray, vec4(0.0, 1.6, 0.0, 0.5));
    if (result.distance < closest) {
        hit = result;
        hit.material.type = GLASS;
        hit.material.diffuse = vec3(0.2, 0.3, 0.9);
        hit.material.specular = vec3(0.9);
        closest = hit.distance;
    }

    result = intersectPlane(ray, vec4(0.0, 1.0, 0.0, 0.0));
    if (result.distance < closest) {
        hit = result;
        float uv = mod(floor(hit.position.z * 2.0) + floor(hit.position.x * 2.0), 2.0);
        hit.material.type = DIFFUSE;
        hit.material.diffuse = mix(vec3(0.95), vec3(0.01), uv);
        closest = hit.distance;
    }

    return closest < HUGE;
}

float fresnel(const in vec3 direction, const in vec3 normal, const in float  n1, const in float  n2) {
    float nr = n1 / n2;
    float cosI = -dot(direction, normal);
    float sinT2 = nr * nr * (1.0 - cosI * cosI);
    if (sinT2 >= 1.0) {
        return 1.0;
    }
    float cosT = sqrt(1.0 - sinT2);
    float rOrth = (n1 * cosI - n2 * cosT) / (n1 * cosI + n2 * cosT);
    float rPar = (n2 * cosI - n1 * cosT) / (n2 * cosI + n1 * cosT);
    return (rOrth * rOrth + rPar * rPar) / 2.0;
}

vec3 trace(Ray ray) {
    vec3 col = vec3(0.0);
    vec3 att = vec3(1.0);
    float fac = 1.0;
    float ray_ior = 1.;

    Intersection hitResult, hitShadow;
    for (int i = 0; i < 8; ++i) {
        if (!trace(ray, hitResult)) {
            col += att * ENV_COLOR;
            break;
        }

        vec3 toLight = normalize(LIGHT_POS - hitResult.position);
        vec3 reflected = normalize(reflect(ray.direction, hitResult.normal));
        Ray shadowRay = Ray(hitResult.position + hitResult.normal * EPSILON, toLight);

        att *= hitResult.material.diffuse;
        col += att * 0.1;
        if (!trace(shadowRay, hitShadow)) {
            col += saturate(dot(hitResult.normal, toLight)) * LIGHT_COLOR * att;
            col += pow(saturate(dot(reflected, toLight)), 40.0) * LIGHT_COLOR * hitResult.material.specular;
        }

        if (hitResult.material.type == DIFFUSE) {
            return col;
        } else if (hitResult.material.type == METAL) {
            float fr = 1.0 - fresnel(ray.direction, hitResult.normal, 1.0003, 1.5);
            att = att * fr + (1.0 - fr) * att;
            ray = Ray(hitResult.position + hitResult.normal * EPSILON, reflected);
        } else {
            vec3 forwardNormal = normalize(faceforward(hitResult.normal, ray.direction, hitResult.normal));
            att *= 1.0 - fresnel(ray.direction, forwardNormal, 1.0003, 1.15);
            vec3 direction = refract(ray.direction, forwardNormal, 1.0003 / 1.15);
            if (direction == vec3(0)) direction = reflect(ray.direction, hitResult.normal);
            ray = Ray(hitResult.position - hitResult.normal * EPSILON, direction);
        }
    }
    return col;
}

void main() {
    vec2 ndc = 2.0 * gl_FragCoord.xy / uResolution - 1.0;
    vec3 xaxis = uCameraMatrix[0].xyz;
    vec3 yaxis = uCameraMatrix[1].xyz;
    vec3 zaxis = uCameraMatrix[2].xyz;
    vec3 origin = uCameraMatrix[3].xyz;

    vec3 acc = vec3(0.0);
    for (int y = 0; y < 2; ++y) {
        float ay = (float(y) - 0.5) / uResolution.y;
        for (int x = 0; x < 2; ++x) {
            float ax = (float(x) - 0.5) / uResolution.x;
            vec3 direction = normalize((ndc.x + ax) * xaxis + (ndc.y + ay) * yaxis - zaxis);
            acc += trace(Ray(origin, direction));
        }
    }

    fragColor = vec4(pow(acc * 0.25, vec3(1.0 / 2.2)), 1.0);
}
