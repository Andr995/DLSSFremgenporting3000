#pragma once
#include <cstdint>
#include <string>

namespace status_validation
{
inline constexpr uint32_t kProtocolVersion = 19;
inline constexpr uint64_t kMaximumAgeSeconds = 5;
struct Session
{
    uint32_t pid = 0;
    uint64_t processStartTime = 0; // Raw Windows FILETIME: disambiguates PID reuse.
};

// Verify complete JSON and session ownership before any UI telemetry is used.
bool IsCurrent(const std::string& json, Session session, uint64_t nowSeconds);
}
