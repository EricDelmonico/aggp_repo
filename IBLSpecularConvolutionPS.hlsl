#include "Lighting.hlsli"

cbuffer data : register(b0)
{
    float roughness;
    int faceIndex;
    int mipLevel;
}

struct VertexToPixel
{
    float4 position : SV_POSITION;
    float2 uv       : TEXCOORD0;
};

TextureCube EnvironmentMap : register(t0);
SamplerState BasicSampler : register(s0);

float3 ConvolveTextureCube(float roughness, float3 R) 
{
    // Assume N == V == R, a common assumption that simplifies the approximation
    float3 N = R;
    float3 V = R;
    float3 finalColor = float3(0, 0, 0);
    float totalWeight = 0;

    // Sample the texture cube MANY times
    for (uint i = 0; i < MAX_IBL_SAMPLES; i++)
    {
        // Grab this sample
        float2 Xi = Hammersley2d(i, MAX_IBL_SAMPLES);
        float3 H = ImportanceSampleGGX(Xi, roughness, N);
        float3 L = 2 * dot(V, H) * H - V;

        // Check N dot L result
        float nDotL = saturate(dot(N, L));
        if (nDotL > 0)
        {
            float3 thisColor = (EnvironmentMap.SampleLevel(BasicSampler, L, 0).rgb);
            thisColor = pow(abs(thisColor), 2.2f);
            finalColor += thisColor * nDotL;
            totalWeight += nDotL;
        }
    }

    // Divide and return result
    return pow(abs(finalColor / totalWeight), 1.0f / 2.2f);
}

float4 main(VertexToPixel input) : SV_TARGET
{
    float2 o = input.uv * 2 - 1; // 1 to -1 range
    float3 xDir, yDir, zDir; // Tangent basis

    // Figure out the z ("normal" of this pixel)
    switch (faceIndex)
    {
    default:
    case 0: zDir = float3(+1, -o.y, -o.x); break;
    case 1: zDir = float3(-1, -o.y, +o.x); break;
    case 2: zDir = float3(+o.x, +1, +o.y); break;
    case 3: zDir = float3(+o.x, -1, -o.y); break;
    case 4: zDir = float3(+o.x, -o.y, +1); break;
    case 5: zDir = float3(-o.x, -o.y, -1); break;
    }
    zDir = normalize(zDir);

    // Process the convolution for the direction of this pixel
    float3 c = ConvolveTextureCube(roughness, zDir);
    return float4(c, 1);
}