#pragma once
#include <string>

namespace runtime_paths
{
// Shared by the universal core and its frontend. Keep legacy routing outside
// these functions; environment overrides take precedence over CET detection.
std::wstring ResolveConfigPath(const std::wstring& executableDirectory);
std::wstring ResolveStatusPath(const std::wstring& configPath,
    const std::wstring& executableDirectory);
}
