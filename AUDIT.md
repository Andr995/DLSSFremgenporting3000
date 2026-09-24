# Engineering review — updated 2026-09-24

## Outcome

The local C++ core rejects its old nonfunctional Ampere patch path and has automated arithmetic, configuration and policy regressions. A separate integration now packages the precompiled `sdli1995/dlssg_for_sm86` 0.3.5 backend. Cyberpunk reports and GPU backend logs confirm NVIDIA Frame Generation on the local RTX 3060 Ti; see [VALIDAZIONE_CYBERPUNK.md](VALIDAZIONE_CYBERPUNK.md). The local C++ core was not used for this Ampere execution, and neither path is certified defect-free.

## Corrections

1. **Architecture and integrity:** removed PTX/fatbin relabelling from SM 8.9 to SM 8.6/8.0, the conditional output SHA-256 bypass and the fictitious emulation-active state. Ada eligibility is an explicit tested policy. A successful revalidation also clears a stale failure code.
2. **FP8 reference arithmetic:** E4M3FN NaNs no longer decode as infinity; signed zeros, subnormals, finite overflow, infinities and ties-to-even rounding have explicit semantics. Finite overflow saturates. E5M2 infinities remain infinities; E4M3FN infinities saturate. NaNs are quieted/canonicalized with sign preserved.
3. **Matrix reference:** B uses the documented column-major layout; accumulation uses `fma`. The reference operates on host arrays, not CUDA warp-register fragments. Function-local table initialization is safe across threads and translation units.
4. **Configuration:** replaced substring matching with the SDK's existing JSON parser; reject truncation, trailing junk, duplicate/escaped duplicate keys, NULs, bad types, overflow, deep nesting and oversized files. Core and frontend use the same validator. Invalid updates do not overwrite accepted core state.
5. **Concurrency:** configuration fields and their revision are published together under one mutex, including revision-only invalidations. Log readers acquire the publication flag before touching the worker-initialized stream.
6. **Telemetry:** count and index are published in one atomic value, preventing impossible mixed temporal positions. The `noexcept` trace flusher uses fixed storage instead of allocating a vector.
7. **Function hooks:** the entry readability check covers the longest six-byte signature; current hotpatch verification checks the memory region first. The compare-exchange expected value is captured before allocation/publication, reducing the window in which a competing hook could be overwritten. This does not establish general compatibility with arbitrary third-party hook writers.
8. **Build/release:** native targets require Windows x64 MSVC/MASM; dependency revisions are locked, including ReShade's matching ImGui. Every build/test/copy failure stops packaging. Fresh package directories and checksums avoid silently uploading stale DLLs. CI invokes the same build script.
9. **Core lifetime (review issue 1):** pin the core before publishing hooks, callbacks or the worker. TLS/thread creation failures stop startup before hook publication; the readiness export reports completed process-attach setup. The UI atomically pins the module before resolving cached exports. Core unloading is deliberately deferred to process exit; a fixture verifies that `FreeLibrary` leaves pinned code callable.
10. **Core/UI routing (review issue 2):** both universal targets call the same path resolver for executable-local, CET and environment-override paths. Relative overrides use the executable directory even when the game changes its working directory.
11. **Stale telemetry (review issue 3):** status protocol 19 adds process creation time. All frontend status-file consumers require this session's PID and creation time, a non-future heartbeat at most five seconds old, and structurally valid flat JSON without duplicate keys. PID reuse and old core protocols are rejected. Missing/failing status clears reported readiness and cannot enlarge the control limit beyond its conservative default.

## Validation executed locally

- GCC 14.1.0, C++20, optimized Release compilation with `-Wall -Wextra -Wpedantic -Werror`.
- Six test executables passed through both the portable script and CMake/CTest (Watcom WMake generator driving GCC).
- FP8: 512 decode cases and 131,072 encode cases against independent double-precision numerical oracles, plus batch conversion, matrix layout, in-place accumulation and concurrent first initialization.
- Control: malformed inputs, legacy migration, duplicate keys, escaped keys, nesting/size limits and 40,000 writes from four writers with four concurrent readers.
- Policies: explicit Ada-only eligibility, multiplier bounds, sorted/unique title manifest, malformed wrapper patterns, release lifecycle, provider ambiguity and OTA conditions.
- Status: protocol mismatch, different PID, reused PID, five-second boundary, expired/future/zero heartbeat, malformed/oversized JSON, duplicate and escaped-duplicate keys, nested containers and embedded NULs.
- Windows: executable/CET/override path selection, cwd independence, directory-versus-file CET marker, stable process identity, and load/release/reload of a pinned fixture DLL with cached export calls.
- Read-only CUDA driver query: NVIDIA GeForce RTX 3060 Ti, compute capability 8.6, driver API version 13.4. This is not the installed GeForce driver release and is not an NGX/Frame Generation test.
- Native build launcher returns failure before dependency changes/packaging when prerequisites are missing.

Reproduce the portable checks with `scripts/test-portable.ps1`. The local CTest results are in `build-tests/wmake/Testing/Temporary/LastTest.log` (generated, not committed).

## Not validated / remaining work

- MSVC, MASM and a usable Ninja installation were unavailable in this session. The full core/ASI/ReShade DLL build and the updated GitHub Actions job have not been executed successfully here. Existing DLLs in `dist` were not rebuilt or relabelled as current.
- The local C++ core was not exercised in a live game. The separate Ampere backend was exercised in Cyberpunk, with successful NGX feature creation and SM86 evaluation logs. General DX12/Vulkan compatibility, frame uniqueness, pacing, latency and long-run stability remain unverified.
- The existing loader still performs substantive initialization under `DllMain`. Process-lifetime pinning prevents runtime unmapping, but loader-lock interactions and shutdown ordering still require full-core integration tests. Hot unloading is intentionally unsupported.
- The old live-control harness assumes an external proxy loader and legacy config path. It is not evidence for the current universal build and is not run as if it were.
- RTX 30 execution uses the separate external backend and its GPU kernel adaptation. The CPU reference library is not used to generate frames. Complete rebuildable source for the upstream backend was not present in the pinned snapshot; it has not received a full source audit here.

## Ampere deployment validation

The package pins commit, DLL size and SHA-256, preserves conflicting files in a per-install backup, and verifies every restore input before mutation. Fixture tests passed for installation, unrelated-file preservation, altered INI rejection, traversal rejection, exact restore, repeat-restore rejection and wrong DLL rejection. The release includes the same installer and restore scripts with the precompiled upstream DLL; runtime provenance and notices remain explicit.
