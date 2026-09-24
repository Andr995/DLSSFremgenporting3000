#include "runtime_paths.h"
#include "process_session.h"
#include "check.h"
#include <filesystem>
#include <fstream>

int main()
{
    namespace fs = std::filesystem;
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_CONFIG_PATH", nullptr));
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_STATUS_PATH", nullptr));
    const fs::path root = fs::current_path() / (L"paths-test-" + std::to_wstring(GetCurrentProcessId()));
    CHECK(!fs::exists(root));
    fs::create_directories(root);
    const auto resolve = [&] { return runtime_paths::ResolveConfigPath(root.wstring()); };
    const auto status = [&] { return runtime_paths::ResolveStatusPath(resolve(), root.wstring()); };
    CHECK(fs::path(resolve()) == root / L"RTX40MFG-Universal.json");
    CHECK(fs::path(status()) == root / L"RTX40MFG-Universal.status.json");
    const fs::path cet = root / L"plugins/cyber_engine_tweaks/mods/RTX40MFG";
    fs::create_directories(cet);
    { std::ofstream file(cet / L"init.lua"); file << "-- test"; CHECK(file.good()); }
    CHECK(fs::path(resolve()) == cet / L"RTX40MFG-Universal.json");
    CHECK(fs::path(status()) == cet / L"RTX40MFG-Universal.status.json");
    const fs::path custom = root / L"custom/config.json";
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_CONFIG_PATH", custom.c_str()));
    CHECK(fs::path(resolve()) == custom);
    CHECK(fs::path(status()) == custom.parent_path() / L"bridge_status.json");
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_STATUS_PATH", L"custom/state.json"));
    CHECK(fs::path(status()) == root / L"custom/state.json");
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_CONFIG_PATH", L"custom/config.json"));
    const auto previousDirectory = fs::current_path();
    fs::current_path(cet);
    CHECK(fs::path(resolve()) == custom); // Independent from the host's cwd.
    CHECK(fs::path(status()) == root / L"custom/state.json");
    fs::current_path(previousDirectory);
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_CONFIG_PATH", nullptr));
    CHECK(SetEnvironmentVariableW(L"RTX40_MFG_STATUS_PATH", nullptr));
    fs::remove(cet / L"init.lua");
    fs::create_directory(cet / L"init.lua");
    CHECK(fs::path(resolve()) == root / L"RTX40MFG-Universal.json"); // Directory is not a marker.
    const auto session = process_session::Current();
    CHECK(session.pid == GetCurrentProcessId() && session.processStartTime != 0);
    CHECK(process_session::Current().processStartTime == session.processStartTime);
    CHECK(process_session::UnixTimeSeconds() > 0);
    // Only remove explicitly created entries; never recurse through a computed root.
    fs::remove(cet / L"init.lua");
    for (auto directory = cet; directory != root; directory = directory.parent_path())
        fs::remove(directory);
    fs::remove(root);
    std::puts("Universal/CET/override paths, cwd independence and process identity passed");
}
