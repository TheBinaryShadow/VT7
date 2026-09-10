// Copyright (c) 2026 VT7 contributors.
// Licensed under the MIT license.
#pragma once

// Fixed proof configuration, independent of the upstream feature-staging build.
struct Feature_VtChecksumReport { static constexpr bool IsEnabled() noexcept { return false; } };
struct Feature_ScrollbarMarks { static constexpr bool IsEnabled() noexcept { return false; } };
struct Feature_ShellCompletions { static constexpr bool IsEnabled() noexcept { return false; } };
struct Feature_KeypadModeEnabled { static constexpr bool IsEnabled() noexcept { return true; } };
struct Feature_AdjustIndistinguishableText { static constexpr bool IsEnabled() noexcept { return false; } };
