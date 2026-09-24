# DLSS MFG research tools

This repository now has two separate paths: a pinned **NVIDIA Frame Generation backend for Ampere**, prepared by `scripts/prepare-ampere.ps1`, and the original C++ Ada research core. The Ampere path integrates `sdli1995/dlssg_for_sm86` 0.3.5; it does not substitute FSR. See [the Italian installation guide](TUTORIAL_RTX3000.md) and [local validation](VALIDAZIONE_CYBERPUNK.md).

The external backend is pinned by commit, size and SHA-256 in `scripts/ampere-backend.lock.json`. The reviewed upstream snapshot supplies binaries and documentation rather than a complete rebuildable source tree. Its NVIDIA runtime and SM86 backend are not authored here. Packaging/deployment scripts preserve the original files and provide an integrity-checked restore. Do not load the local Ada core together with the Ampere backend.

**The C++ code below remains Ada research code, not an RTX 30 port.** Its temporal correction accepts Ada SM 8.9 only, with provider-version, layout and SHA-256 checks. The old local Ampere path merely changed a PTX target; that path and its output-hash bypass were removed. The external integration does not loosen this Ada-specific policy.

`ampere_fp8_emulator.*` contains CPU reference arithmetic for future backend development. It is tested separately and is not linked into the injected core. It cannot execute CUDA kernels or generate game frames.

For the current Ampere installation guide, see [README.md](README.md). The build instructions below apply only to the historical Ada C++ core. Only NVIDIA Frame Generation is in scope; no substitute frame-generation backend has been added.

## Current behavior

- Follow game, fixed multiplier and Dynamic controls through a ReShade add-on.
- DX12 and Vulkan integration paths; availability depends on the actual game, provider and active adapter.
- Capacity bounded by the bundled title policy, wrapper layout and route readiness. A title listing is not proof of mod compatibility.
- Unknown providers and unsupported adapters do not receive the temporal patch.
- Invalid configuration edits preserve the last accepted core configuration.
- These controls describe the local Ada core. The separate Ampere integration has its own configuration and validation record; image quality and long-run stability require real-game validation.

## Build

Use an **x64 Native Tools / Developer shell for Visual Studio 2022**, with MSVC, MASM, Windows SDK, CMake 3.24+, Ninja and Git available, then run:

```powershell
.\build.bat
```

The script resolves its own repository directory, so it also works when launched from another directory. Dependencies are pinned in `scripts/dependencies.json`: Streamline 2.12.0, ReShade 6.8.0 and ReShade's exact ImGui submodule revision. An arbitrary ImGui checkout is not ABI-compatible by assumption. Existing mismatched or modified dependencies are rejected, not reset.

The DLL build uses `build/msvc-x64`. Build and CTest must both succeed before a fresh `dist/package-<id>` directory is created. Each package includes SHA-256 checksums. Files from older `dist` directories are not evidence of a successful current build and are not republished by CI.

GitHub Actions uses the same script and uploads only that run's package. A green build checks compilation and automated regressions, not game compatibility.

## Regression tests

Tests can run without a GPU or the injected DLLs. With the pinned Streamline tree already present and a MinGW GCC compiler:

```powershell
.\scripts\test-portable.ps1 -Compiler 'C:\path\to\g++.exe'
```

Alternatively, use CMake with your available C++ compiler/build tool:

```powershell
cmake -S tests -B build-tests -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build-tests
ctest --test-dir build-tests --output-on-failure --no-tests=error
```

Coverage includes all 256 FP8 encodings and all 65,536 FP16 encodings for each format, special values, rounding, batch conversion, matrix layout, concurrent initialization, configuration validation and 40,000 concurrent configuration writes. Policy tests cover adapter eligibility, capacity limits, manifest ordering, wrapper patterns, route lifecycle and OTA decisions. Checks remain enabled in Release builds.

Six executables run on Windows: arithmetic, policies, control configuration, status session/freshness, shared path routing and actual DLL lifetime after `FreeLibrary`. The four platform-independent suites also run on other platforms. The Windows lifetime test uses a small fixture DLL; it does not load the injected core.

The historical `tests/live_control_harness` uses stub DLLs and a separate legacy loader/configuration setup. It is not registered as a validated integration test for the current universal core.

## Installation after a successful native build

Requires a game with existing Streamline DLSS Frame Generation, an eligible Ada GPU, Ultimate ASI Loader and ReShade with add-on support. Copy these files from the same fresh package beside the game executable:

```text
RTX40MFGCore.dll
RTX40MFG.asi
RTX40MFG-UI.addon64
```

For DX12, install ReShade for DirectX 10/11/12 and use a different proxy name for Ultimate ASI Loader, such as `dinput8.dll` or `version.dll`. For Vulkan, use ReShade's Vulkan installation and an ASI loader proxy imported by the game. Merge any supplied `global.ini` values into the corresponding loader configuration.

Open the ReShade overlay and its DLSS MFG controls. The mod does not add a missing game FG integration. Requested multipliers and CPU submission telemetry do not prove that unique frames were displayed.

## Configuration and diagnostics

The universal configuration normally lives beside the executable as `RTX40MFG-Universal.json`. Core and UI now share path resolution, including CET discovery and `RTX40_MFG_CONFIG_PATH` / `RTX40_MFG_STATUS_PATH` overrides. Set overrides before launching the game. Relative overrides are resolved against the game executable directory, independently of its working directory. For custom config names, the default status filename is `bridge_status.json` in the config directory; create custom directories before launching.

```json
{
  "followGame": true,
  "mode": "follow",
  "multiplier": 2,
  "dynamicTargetFrameRate": 0,
  "dynamicExperimental56": false,
  "generatedOnlyDebug": false
}
```

Files must be complete JSON objects no larger than 4096 bytes. Duplicate keys, invalid types, out-of-range values, embedded NULs and excessive nesting are rejected. Multiplier range is 2-6; target FPS is 0-1000, with 0 preserving the refresh-rate target convention. Legacy files without `followGame` retain explicit override behavior. Retired `intervalLogging` and `selectiveOtaDlssgWrapper` fields are validated but do not affect behavior.

Logs are written to `%TEMP%\MfgUnlock-<PID>.log` and `%TEMP%\MfgUnlock-intervals-<PID>.csv`. Universal status normally uses `RTX40MFG-Universal.status.json`. Adapter verification logs identify the observed CUDA capability and explain the Ada-only temporal patch requirement.

Status protocol 19 requires the current PID, process creation time and a heartbeat no more than five seconds old. Stale, foreign-process and malformed status files cannot supply readiness or multiplier capacity. Update the core and UI together. The core is pinned until process exit because hooks and its worker retain code pointers; updating or removing it requires closing the game.

`scripts/diagnose-nvidia.ps1 -Compiler 'C:\path\to\g++.exe'` queries the installed CUDA driver and adapters without loading a game or NGX model. A successful query does not test Frame Generation. The local query identified an RTX 3060 Ti (SM 8.6), which is outside the current temporal patch policy.

See `AUDIT.md` for the changes, executed validation and remaining integration work.

## License

Original repository code is MIT licensed. NVIDIA Streamline/NGX, ReShade, ImGui, nlohmann/json and MinHook retain their respective licenses and notices.
