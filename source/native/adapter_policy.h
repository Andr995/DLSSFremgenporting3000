#pragma once

namespace adapter_policy
{
// The temporal payload and its output hash are validated for Ada SM 8.9.
// Relabelling PTX cannot port the other NGX kernels or its inference runtime.
// Ampere requires a real GPU backend before it can enter this mutation path.
constexpr bool SupportsTemporalPatch(int major, int minor) noexcept
{
    return major == 8 && minor == 9;
}
}
