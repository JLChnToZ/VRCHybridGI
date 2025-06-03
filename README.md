# VRC Hybrid GI

This is a [custom lighting model](https://docs.unity3d.com/2022.3/Documentation/Manual/SL-SurfaceShaderLighting.html) (not a complete shader) designed to use in VRChat, where it supports many community de-facto standard lighting systems. Currently, it bundles following:

- [LTCGI](https://ltcgi.dev/)
- [VRC Light Volumes](https://github.com/REDSIM/VRCLightVolumes)
- [Bakery SH/Mono SH](https://geom.io/bakery/wiki/index.php?title=Manual#Directional_mode)

If there is more standards like these appeared in future, we will implement it if the framework capable.

## Installation

Pretestique: you will need to install this package, LTCGI and VRC Light Volumes. Although these are dependencies, it is intentionally not hard depends on them, to allows users not importing them if they don't need.

To install this package, you should use [VRChat Creator Companion](https://vcc.docs.vrchat.com/) or [ALCOM](https://vrc-get.anatawa12.com/alcom/) or other VPM tools with [my package listings](https://xtlcdn.github.io/vpm/).

## How to use it

It is very simple to use, assume you are working on a [surface shader](https://docs.unity3d.com/2022.3/Documentation/Manual/SL-SurfaceShaders.html),
just replace a few properties and your shader will be available to above systems.

```hlsl
// This is the demo shader on how to use the "Hybrid GI".
Shader "Custom/HybridSurfaceSample" {
    Properties {
        // ... (Normal shader properties here)

        // Add following properties to make these features toggleable
        [Toggle(_LTCGI)] _LTCGI ("Use LTCGI", Int) = 0
        [Toggle(_VRCLV)] _VRCLV ("Use VRC Light Volumes", Int) = 0
        [KeywordEnum(None, SH, MonoSH)] _Bakery ("Directional Lightmap Mode", Int) = 0
        [Toggle(_BAKERY_SHNONLINEAR)] _SHNonLinear ("Non-Linear SH", Int) = 0
    }
    SubShader {
        Tags {
            "RenderType" = "Opaque"
            "LTCGI" = "_LTCGI" // This tag is required for LTCGI support
        }
        LOD 200

        CGPROGRAM
        // Use "StandardHybrid" instead of "Standard" to enable hybrid lighting model.
        // If you were using "StandardSpecular", you can replace it to "StandardSpecularHybrid".
        #pragma surface surf StandardHybrid fullforwardshadows

        // Use shader model 3.0 target, to get nicer looking lighting
        #pragma target 3.0

        // It is required to add this file.
        #include "Packages/idv.jlchntoz.vrchybridgi/Shaders/Includes/StandardHybrid.cginc"

        // The rest are the same as normal surface shaders.
        // ...
    }
}
```

Besides of this lighting model, it also contain following shaders for use:
- `Particles/Standard Hybrid Surface`: A surface particle shader likes the standard one, but with Hybrid GI.
- `Particles/GI Lit`: An particle shader likes the standard unlit one, but lit with VRC Light Volumes and light probes support.

## Why?

This is a great question. There are plenty of feature rich shaders are for end users, already supporting these community made essentials, LilToon, Poiyomi, Filamented, Mochie, you name it. This package's goal isn't "reinventing the wheel" to compete with them, instead it is made for advanced shader engineers, who wants to DIY some simple functional shaders for use in worlds and/or avatars, but find tedious and annoyed to make it compatible with these essentials.

## License

[MIT](LICENSE)