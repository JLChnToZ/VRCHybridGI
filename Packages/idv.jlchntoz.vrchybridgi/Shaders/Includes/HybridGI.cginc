#ifndef HYBRID_GI_INCLUDED
#define HYBRID_GI_INCLUDED

#include "UnityCG.cginc"
#include "UnityImageBasedLighting.cginc"

#ifdef _LTCGI
#include "Packages/at.pimaker.ltcgi/Shaders/LTCGI_structs.cginc"
#define LTCGI_V2_CUSTOM_INPUT UnityIndirect
#define LTCGI_V2_DIFFUSE_CALLBACK(l, o) l.diffuse += o.color * o.intensity
#define LTCGI_V2_SPECULAR_CALLBACK(l, o) l.specular += o.color * o.intensity
#include "Packages/at.pimaker.ltcgi/Shaders/LTCGI.cginc"
#endif

#ifdef _VRCLV
#include "Packages/red.sim.lightvolumes/Shaders/LightVolumes.cginc"
#endif

#if defined(_BAKERY_RNM) || defined(_BAKERY_SH) || defined(_BAKERY_MONOSH)
#include "./BakeryLightmap.cginc"
#endif

#ifdef DIRLIGHTMAP_COMBINED
#define HYBRID_RENDER_DIRLIGHTMAP_COMBINED(color, samplerTex, tex, uv, normalWorld) \
    color = DecodeDirectionalLightmap(color, UNITY_SAMPLE_TEX2D_SAMPLER(samplerTex, tex, uv), normalWorld)
#else
#define HYBRID_RENDER_DIRLIGHTMAP_COMBINED(color, samplerTex, tex, uv, normalWorld) ;
#endif

// Modified from UnityGI_Base
inline UnityGI HybridGI(UnityGIInput data, half occlusion, half3 normalWorld) {
    UnityGI gi;
    ResetUnityGI(gi);

    // Base pass with Lightmap support is responsible for handling ShadowMask / blending here for performance reason
    #ifdef HANDLE_SHADOWS_BLENDING_IN_GI
        half bakedAtten = UnitySampleBakedOcclusion(data.lightmapUV.xy, data.worldPos);
        float zDist = dot(_WorldSpaceCameraPos - data.worldPos, UNITY_MATRIX_V[2].xyz);
        float fadeDist = UnityComputeShadowFadeDistance(data.worldPos, zDist);
        data.atten = UnityMixRealtimeAndBakedShadows(data.atten, bakedAtten, UnityComputeShadowFade(fadeDist));
    #endif

    gi.light = data.light;
    gi.light.color *= data.atten;

    #ifdef _VRCLV
        float3 L0, L1r, L1g, L1b;
        #ifdef LIGHTMAP_ON
            LightVolumeAdditiveSH(data.worldPos, L0, L1r, L1g, L1b);
        #else
            LightVolumeSH(data.worldPos, L0, L1r, L1g, L1b);
        #endif
        gi.indirect.diffuse = LightVolumeEvaluate(normalWorld, L0, L1r, L1g, L1b);
    #elif UNITY_SHOULD_SAMPLE_SH
        gi.indirect.diffuse = ShadeSHPerPixel(normalWorld, data.ambient, data.worldPos);
    #endif

    #ifdef LIGHTMAP_ON
        #ifdef _BAKERY_RNM
            gi.indirect.diffuse += SampleBakeryRNM(data.lightmapUV.xy);
        #else
            const half4 bakedColorTex = UNITY_SAMPLE_TEX2D(unity_Lightmap, data.lightmapUV.xy);
            half3 bakedColor = DecodeLightmap(bakedColorTex);
            #if defined(_BAKERY_SH) || defined(_BAKERY_MONOSH)
                float3 L1x, L1y, L1z;
                SampleBakerySH(data.lightmapUV.xy, bakedColor, L1x, L1y, L1z);
                bakedColor = ShadeBakerySH(bakedColor, L1x, L1y, L1z, normalWorld);
            #else
                HYBRID_RENDER_DIRLIGHTMAP_COMBINED(bakedColor, unity_LightmapInd, unity_Lightmap, data.lightmapUV.xy, normalWorld);
            #endif
            gi.indirect.diffuse += max(bakedColor, 0);
        #endif
        #if defined(LIGHTMAP_SHADOW_MIXING) && !defined(SHADOWS_SHADOWMASK) && defined(SHADOWS_SCREEN)
            ResetUnityLight(gi.light);
            gi.indirect.diffuse = SubtractMainLightWithRealtimeAttenuationFromLightmap(gi.indirect.diffuse, data.atten, bakedColorTex, normalWorld);
        #endif
    #endif

    #ifdef DYNAMICLIGHTMAP_ON
        fixed4 realtimeColorTex = UNITY_SAMPLE_TEX2D(unity_DynamicLightmap, data.lightmapUV.zw);
        half3 realtimeColor = DecodeRealtimeLightmap(realtimeColorTex);
        HYBRID_RENDER_DIRLIGHTMAP_COMBINED(realtimeColor, unity_DynamicLightmapInd, unity_DynamicLightmap, data.lightmapUV.zw, normalWorld);
        gi.indirect.diffuse += realtimeColor;
    #endif

    gi.indirect.diffuse *= occlusion;
    return gi;
}

#undef HYBRID_RENDER_DIRLIGHTMAP_COMBINED

inline UnityGI HybridGI(UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData gloss) {
    UnityGI gi = HybridGI(data, occlusion, normalWorld);
    gi.indirect.specular = UnityGI_IndirectSpecular(data, occlusion, gloss);
    #ifdef _LTCGI
        float3 viewDir = normalize(_WorldSpaceCameraPos - data.worldPos);
        LTCGI_Contribution(gi.indirect, data.worldPos, normalWorld, viewDir, gloss.roughness, data.lightmapUV.xy);
    #endif
    return gi;
}
#endif