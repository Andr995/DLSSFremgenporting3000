#include "adapter_policy.h"
#include "nvidia_mfg_policy.h"
#include "selective_ota_wrapper_policy.h"
#include "streamline_ota_policy.h"
#include "universal_route_policy.h"
#include "universal_wrapper_profile.h"
#include "check.h"
#include <array>
#include <cstring>

namespace manifest_test
{
using nvidia_mfg_policy::Tier;
#include "nvidia_mfg_manifest.generated.h"
}

int main()
{
    for (size_t i = 0; i < manifest_test::kManifest.size(); ++i)
    {
        const auto& entry = manifest_test::kManifest[i];
        CHECK(!entry.key.empty());
        CHECK(entry.tier == nvidia_mfg_policy::Tier::eFourX
            || entry.tier == nvidia_mfg_policy::Tier::eSixX);
        if (i != 0) CHECK(manifest_test::kManifest[i - 1].key < entry.key);
        for (const char c : entry.key)
            CHECK((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9'));
    }
    for (int major = -1; major <= 13; ++major)
        for (int minor = -1; minor <= 10; ++minor)
            CHECK(adapter_policy::SupportsTemporalPatch(major, minor)
                == (major == 8 && minor == 9));
    using namespace nvidia_mfg_policy;
    for (auto tier : {Tier::eUnknown, Tier::eFourX, Tier::eSixX})
        for (bool patched : {false, true})
            for (uint32_t compiled : {0u, 1u, 2u, 3u, 4u, 5u, 6u, UINT32_MAX})
            {
                const auto result = DecideCapacity(tier, patched, compiled);
                CHECK(result.effectiveMaximumMultiplier >= 2 && result.effectiveMaximumMultiplier <= 6);
                if (tier == Tier::eSixX && compiled != 5)
                    CHECK(result.effectiveMaximumMultiplier <= 4);
                if (tier == Tier::eFourX)
                    CHECK(result.effectiveMaximumMultiplier <= 4);
                if (tier == Tier::eUnknown)
                    CHECK(result.effectiveMaximumMultiplier == NativeMaximumMultiplier(compiled));
            }
    using namespace universal_wrapper_profile;
    std::array<uint8_t, 10> pattern{0xba, 5, 0, 0, 0, 0x3b, 0xca, 0x0f, 0x42, 0xd1};
    CHECK(Matches(pattern.data(), pattern.size()));
    CHECK(!Matches(nullptr, 10));
    for (size_t size = 0; size < pattern.size(); ++size)
        CHECK(!Matches(pattern.data(), size));
    for (unsigned byte = 0; byte < 10; ++byte)
    {
        auto broken = pattern;
        broken[byte] ^= 0xff;
        CHECK(!Matches(broken.data(), broken.size()));
    }
    pattern[7] = pattern[8] = pattern[9] = 0x90;
    CHECK(Matches(pattern.data(), pattern.size()));
    CHECK(ClampMultiplier(UINT32_MAX, 5) == 6);
    CHECK(ClampMultiplier(0, 5) == 2);
    CHECK(ClampMultiplier(6, 123) == 2);

    using namespace universal_route_policy;
    Lifecycle lifecycle{};
    const Identity first{1, 1}, second{2, 1};
    ObserveSetOptions(lifecycle, true, false);
    CHECK(CanActivateRoute(first, second, lifecycle));
    ObserveSetOptions(lifecycle, true, true);
    lifecycle.pipelineCreated = true;
    CHECK(!CanActivateRoute(first, second, lifecycle));
    CHECK(!ObserveRelease(lifecycle, true, true));
    ObserveSetOptions(lifecycle, false, true);
    CHECK(!ObserveRelease(lifecycle, false, true));
    CHECK(!ObserveRelease(lifecycle, true, false));
    CHECK(ObserveRelease(lifecycle, true, true));
    CHECK(CanActivateRoute(first, second, lifecycle));
    CHECK(ResolveProvider(false, 2) == ProviderResolution::eAmbiguous);
    CHECK(ResolveProvider(false, 1) == ProviderResolution::eUniqueCandidate);
    CHECK(ResolveProvider(true, 2) == ProviderResolution::eDirect);
    CHECK(EvaluateReadiness({}) == Failure::eNoActiveRoute);
    CHECK(ClassifyInternalGet(StructureStatus::eFound, StructureStatus::eFound,
        99, StructureStatus::eNotFound, 0) == AdapterAction::eRejectUnknownState);
    CHECK(ClassifyInternalSet(StructureStatus::eFound, StructureStatus::eFound,
        99) == AdapterAction::eRejectUnknownOptions);
    for (unsigned mask = 0; mask < 8; ++mask)
    {
        const auto ota = streamline_ota_policy::Apply(0x8000, mask & 1, mask & 2, mask & 4);
        CHECK((ota.flags & 0x8000) != 0);
        CHECK(ota.allowOtaForced == (mask == 7));
    }
    CHECK(selective_ota_wrapper_policy::IsCompatibleCandidate({2, 11, 0, 0}, 5));
    CHECK(!selective_ota_wrapper_policy::IsCompatibleCandidate({2, 12, 0, 0}, 5));
    CHECK(!selective_ota_wrapper_policy::IsCompatibleCandidate({2, 11, 0, 0}, 3));
    std::puts("Adapter eligibility, wrapper bounds, route lifecycle and OTA regressions passed");
}
