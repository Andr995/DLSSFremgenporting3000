#include <Windows.h>
#include <cstdio>
#include <cstring>

template <typename T> T Load(HMODULE module, const char* name)
{
    const auto address = GetProcAddress(module, name);
    T result = nullptr;
    static_assert(sizeof(result) == sizeof(address));
    std::memcpy(&result, &address, sizeof(result));
    return result;
}

int main()
{
    HMODULE cuda = LoadLibraryExW(L"nvcuda.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (!cuda)
    {
        std::printf("Cannot load NVIDIA CUDA driver. Windows error: %lu\n", GetLastError());
        return 2;
    }
    const auto init = Load<int(WINAPI*)(unsigned)>(cuda, "cuInit");
    const auto count = Load<int(WINAPI*)(int*)>(cuda, "cuDeviceGetCount");
    const auto device = Load<int(WINAPI*)(int*, int)>(cuda, "cuDeviceGet");
    const auto name = Load<int(WINAPI*)(char*, int, int)>(cuda, "cuDeviceGetName");
    const auto capability = Load<int(WINAPI*)(int*, int*, int)>(cuda, "cuDeviceComputeCapability");
    const auto driverVersion = Load<int(WINAPI*)(int*)>(cuda, "cuDriverGetVersion");
    if (!init || !count || !device || !name || !capability || !driverVersion)
    {
        std::puts("Required CUDA driver exports are unavailable.");
        FreeLibrary(cuda);
        return 2;
    }
    const int initialized = init(0);
    if (initialized != 0)
    {
        std::printf("cuInit failed: CUDA error %d\n", initialized);
        FreeLibrary(cuda);
        return 2;
    }
    int version = 0, devices = 0;
    if (driverVersion(&version) != 0 || count(&devices) != 0 || devices <= 0)
    {
        std::puts("No CUDA device could be queried in this session.");
        FreeLibrary(cuda);
        return 2;
    }
    std::printf("CUDA driver API version: %d.%d (not the GeForce driver release)\n",
        version / 1000, (version % 1000) / 10);
    for (int i = 0; i < devices; ++i)
    {
        int handle = 0, major = 0, minor = 0;
        char label[256]{};
        if (device(&handle, i) != 0 || name(label, sizeof(label), handle) != 0
            || capability(&major, &minor, handle) != 0)
        {
            std::printf("Device %d: query failed\n", i);
            FreeLibrary(cuda);
            return 2;
        }
        std::printf("GPU %d: %s | compute capability %d.%d\n", i, label, major, minor);
    }
    std::puts("NVIDIA Frame Generation: NOT TESTED. No NGX model was initialized or evaluated.");
    std::puts("A CUDA-capable GPU is not proof of DLSS Frame Generation compatibility.");
    FreeLibrary(cuda);
    return 0;
}
