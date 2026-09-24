#include "module_lifetime.h"

extern "C" __declspec(dllexport) int LifetimeProbe() { return 42; }

BOOL WINAPI DllMain(HINSTANCE instance, DWORD reason, LPVOID)
{
    return reason != DLL_PROCESS_ATTACH
        || module_lifetime::PinForProcessLifetime(instance);
}
