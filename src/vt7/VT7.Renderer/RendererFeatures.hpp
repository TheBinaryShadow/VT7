// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once

#include <windows.h>
// Atlas stores optional newer DirectWrite types even when targeting older APIs.
// Expose declarations only, then restore the target. This does not implement
// those interfaces and is not evidence that the unported library can run on 7.
#pragma push_macro("NTDDI_VERSION")
#pragma push_macro("_WIN32_WINNT")
#undef NTDDI_VERSION
#undef _WIN32_WINNT
#define NTDDI_VERSION 0x0A000004 // RS3 declarations, including font axes/fallback1.
#define _WIN32_WINNT 0x0A00
#include <wincodec.h>
#include <dwrite_3.h>
#include <d2d1_3.h>
#include <dcomp.h>
#pragma pop_macro("_WIN32_WINNT")
#pragma pop_macro("NTDDI_VERSION")

// Explicit selections for the isolated VT7 Atlas backend/presentation build.
#define VT7_ATLAS 1
#define TIL_FEATURE_CONHOSTATLASENGINECUSTOMSHADERS_ENABLED 0
struct Feature_AtlasEngineLoudErrors { static constexpr bool IsEnabled() noexcept { return true; } };
struct Feature_AtlasEnginePresentFallback { static constexpr bool IsEnabled() noexcept { return true; } };
struct Feature_NearbyFontLoading { static constexpr bool IsEnabled() noexcept { return false; } };
