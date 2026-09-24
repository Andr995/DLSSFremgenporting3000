#include "module_lifetime.h"
#include "check.h"
#include <filesystem>
#include <cstring>

int main(int argc, char** argv)
{
    CHECK(argc == 2);
    CHECK(!module_lifetime::PinForProcessLifetime(nullptr));
    const auto path = std::filesystem::absolute(argv[1]).wstring();
    HMODULE module = LoadLibraryW(path.c_str());
    CHECK(module != nullptr);
    using Probe = int(*)();
    const auto address = GetProcAddress(module, "LifetimeProbe");
    Probe probe = nullptr;
    static_assert(sizeof(probe) == sizeof(address));
    std::memcpy(&probe, &address, sizeof(probe));
    CHECK(probe && probe() == 42);
    CHECK(FreeLibrary(module));
    CHECK(GetModuleHandleW(path.c_str()) == module);
    CHECK(probe() == 42); // Cached export remains callable after release.
    HMODULE again = LoadLibraryW(path.c_str());
    CHECK(again == module);
    CHECK(FreeLibrary(again));
    CHECK(probe() == 42);
    std::puts("Pinned DLL remains mapped and callable after FreeLibrary passed");
}
