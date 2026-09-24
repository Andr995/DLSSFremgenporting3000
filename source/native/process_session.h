#pragma once
#include "status_validation.h"
#include <Windows.h>

namespace process_session
{
inline uint64_t FileTimeTicks(FILETIME value) noexcept
{
    return (static_cast<uint64_t>(value.dwHighDateTime) << 32) | value.dwLowDateTime;
}

inline status_validation::Session Current() noexcept
{
    FILETIME creation{}, exit{}, kernel{}, user{};
    if (!GetProcessTimes(GetCurrentProcess(), &creation, &exit, &kernel, &user))
        return {};
    return {GetCurrentProcessId(), FileTimeTicks(creation)};
}

inline uint64_t UnixTimeSeconds() noexcept
{
    FILETIME now{};
    GetSystemTimeAsFileTime(&now);
    constexpr uint64_t epoch = 116444736000000000ULL;
    const uint64_t ticks = FileTimeTicks(now);
    return ticks >= epoch ? (ticks - epoch) / 10000000ULL : 0;
}
}
