#pragma once
#include <Windows.h>

namespace module_lifetime
{
// Hooks, loader notifications and the worker retain addresses in this DLL.
// Pin before publishing any of them: runtime FreeLibrary must not unmap it.
inline bool PinForProcessLifetime(HMODULE module) noexcept
{
    if (!module)
        return false;
    HMODULE pinned = nullptr;
    return GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS
            | GET_MODULE_HANDLE_EX_FLAG_PIN,
            reinterpret_cast<LPCWSTR>(module), &pinned)
        && pinned == module;
}
}
