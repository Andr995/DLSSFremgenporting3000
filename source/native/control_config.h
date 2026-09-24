#pragma once

#include <cstddef>
#include <cstdint>

namespace control_config
{
inline constexpr size_t kMaximumBytes = 4096;

struct ControlConfig
{
    bool followGame = true;
    uint32_t multiplier = 2;
    bool dynamic = false;
    uint32_t dynamicTargetFrameRate = 0;
    bool dynamicExperimental56 = false;
    bool generatedOnlyDebug = false;
    bool intervalLogging = true;
    bool selectiveOtaDlssgWrapper = false;
};

// Reject malformed/ambiguous documents atomically: output is unchanged on error.
bool Parse(const char* data, size_t size, ControlConfig& output);
}
