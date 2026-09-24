#include "runtime_paths.h"
#include <Windows.h>
#include <filesystem>

namespace runtime_paths
{
namespace
{
std::wstring Override(const wchar_t* name, const std::wstring& executableDirectory)
{
    std::wstring value(32768, L'\0');
    const DWORD length = GetEnvironmentVariableW(name, value.data(),
        static_cast<DWORD>(value.size()));
    if (!length || length >= value.size())
        return {};
    value.resize(length);
    // Use the executable directory for relative overrides, so game changes to
    // the process working directory cannot split core and frontend routing.
    const std::filesystem::path path(value);
    return (path.is_absolute() ? path : std::filesystem::path(executableDirectory)
        / path).lexically_normal().wstring();
}

bool SamePath(const std::filesystem::path& a, const std::filesystem::path& b)
{
    const auto left = a.lexically_normal().wstring();
    const auto right = b.lexically_normal().wstring();
    return _wcsicmp(left.c_str(), right.c_str()) == 0;
}
}

std::wstring ResolveConfigPath(const std::wstring& executableDirectory)
{
    const auto override = Override(L"RTX40_MFG_CONFIG_PATH", executableDirectory);
    if (!override.empty())
        return override;
    const std::filesystem::path directory(executableDirectory);
    const auto cet = directory / L"plugins/cyber_engine_tweaks/mods/RTX40MFG";
    const DWORD attributes = GetFileAttributesW((cet / L"init.lua").c_str());
    const bool cetInstalled = attributes != INVALID_FILE_ATTRIBUTES
        && !(attributes & FILE_ATTRIBUTE_DIRECTORY);
    return ((cetInstalled ? cet : directory) / L"RTX40MFG-Universal.json").wstring();
}

std::wstring ResolveStatusPath(const std::wstring& configPath,
    const std::wstring& executableDirectory)
{
    const auto override = Override(L"RTX40_MFG_STATUS_PATH", executableDirectory);
    if (!override.empty())
        return override;
    const std::filesystem::path directory(executableDirectory);
    const std::filesystem::path config(configPath);
    const bool universal = SamePath(config, directory / L"RTX40MFG-Universal.json")
        || SamePath(config, directory / L"plugins/cyber_engine_tweaks/mods/RTX40MFG"
            / L"RTX40MFG-Universal.json");
    return (config.parent_path() / (universal
        ? L"RTX40MFG-Universal.status.json" : L"bridge_status.json")).wstring();
}
}
