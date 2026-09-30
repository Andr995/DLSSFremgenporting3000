# Local validation and scope

Integration and local validation: nikecatania95/Andr995. Backend implementation:
[sdli1995/dlssg_for_sm86](https://github.com/sdli1995/dlssg_for_sm86), version 0.3.5,
commit `9621db573e07ed54f50c15bbb585ed9a7bdfac28`. The archive contains the unchanged,
precompiled upstream DLL and the configuration used for the reported tests.

## Test system and results

Collected on 24 September 2026: RTX 3060 Ti, Ryzen 5 5600X, 32 GB RAM, Windows 11
Pro build 26200, NVIDIA driver 616.56. Cyberpunk 2077 **2.3**, 1920 x 1080,
borderless, VSync off, no FPS cap, DLSS Quality with the Transformer model,
Ray Reconstruction on, ray tracing on with Psycho lighting, path tracing off.
Reported settings match across the three runs except Frame Generation.

| Mode | Average FPS | Minimum FPS | Maximum FPS |
| --- | ---: | ---: | ---: |
| Frame Generation off | 44.96 | 40.19 | 49.24 |
| NVIDIA DLSS FG 2x | 77.33 | 60.63 | 88.02 |
| NVIDIA DLSS FG 4x | 120.01 | 32.58 | 138.84 |

These are single benchmark runs and **game-reported** values, not an independent
capture of unique displayed frames or input latency. The 4x minimum reveals a
drop that the average alone would conceal. Minimum FPS is not a 1% low statistic.
No broad stability guarantee or per-GPU performance promise follows from this.

A separate **2.31** run reported 114.71 average FPS at 4x. It is included in the
evidence but is not pooled with the 2.3 comparison because the game version
changed. Other RTX 30-series cards, drivers and game versions were not tested.

## Execution evidence

The matching session's backend reports NVIDIA DLSS-G 310.9.1.0, successful feature
creation, device SM86, `cubin_sm86`, and one or three generated frames per
evaluation sample. It recorded 12,516 total evaluations on exit and 116 sampled
evaluation rows, with successful sampled statuses and zero sampled failed
launches or image fallbacks. The session exited cleanly. Later sessions provide
additional successful samples in the attached summary.

These are software diagnostics. They are not instruction-level Tensor Core
profiling, a frame-uniqueness measurement, or an end-to-end security audit.
FSR and XeSS Frame Generation were disabled in these reports. This integration
uses an adapted NVIDIA runtime and does not imply official RTX 30-series support.

The `evidence` directory contains the preserved benchmark data and sanitized
backend summaries, including source hashes. No game executable, personal save,
raw session log or original game DLL is included as a separate archive file.
The upstream proxy itself embeds NVIDIA runtime/kernel assets as documented
in `BACKEND_PROVENANCE.md` and the unchanged upstream third-party notice.

## Archive verification

The packaging script checks the pinned DLL and notice hashes, verifies the INI
against the prepared package, tests both archives, extracts each into an empty
directory, and compares every extracted file with the staged content by SHA-256.
This verifies packaging integrity; it is not a new in-game benchmark or a malware
certification. Manual installation is documented; Vortex installation is untested.

## Integration update 0.3.5-cp2077.2 (30 September 2026)

The backend binary and numerical configuration remain unchanged. The ASI package
places that exact binary and its INI directly in bin/x64/plugins, preserving CET's
root version.dll. A separate Standalone package retains the original root layout.
Do not install both. Tests cover CET file preservation, exact restoration,
unknown-loader conflicts, legacy manifests, altered files, diagnostic log parsing
and junction rejection. These file tests are not a GPU compatibility test.

The RTX 3070m missing-menu report remains unverified. HAGS is a troubleshooting
step suggested in the thread, not a confirmed fix for that user's machine.

## CET/ASI runtime check — 30 September 2026

CET 1.37.1 and dlssg_sm86.asi were observed loaded together on RTX 3060 Ti /
Cyberpunk 2.31 / driver 616.56. CET's original root version.dll was preserved.
Its first-time overlay and successful D3D12 initialization were observed.
The completed FG log reports a successful DLSS-G creation, HAGS on,
SM86/cubin_sm86, 19,296 total evaluations and 172 successful evaluation samples
requesting three generated frames, with zero sampled launch errors or image
fallbacks. The process exited cleanly.

Two user-driven benchmarks in that session reported 119.69 and 45.02 average FPS.
DLSS quality, RT, path tracing and Ray Reconstruction differ between the runs.
These results are not a controlled A/B comparison and do not establish an FPS
change caused by CET. The low second result remains documented; no cold-restart
comparison was performed to identify its cause. Restart the game after changing
graphics settings and verify the new session's logs before comparing results.

See evidence/cyberpunk-cet-asi-validation.json for both full benchmark reports,
sanitized execution evidence and source hashes. This confirms CET initialization
and FG execution in one session, not every CET-dependent mod or graphics preset.
The temporary CET installation was archived after the test and the original
local backend/loader were restored.
