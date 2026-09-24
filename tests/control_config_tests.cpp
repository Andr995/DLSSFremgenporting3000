#include "control_config.h"
#include "control_state.h"
#include "check.h"
#include <cstring>
#include <string>
#include <array>
#include <atomic>
#include <thread>

using namespace control_config;

int main()
{
    ControlConfig config{};
    const auto parse = [&](const std::string& text) {
        return Parse(text.data(), text.size(), config);
    };
    CHECK(parse(R"({"mode":"fixed","multiplier":4,"version":6})"));
    CHECK(!config.followGame && !config.dynamic && config.multiplier == 4);
    CHECK(parse(R"({"followGame":true,"mode":"follow","multiplier":2})"));
    CHECK(config.followGame && !config.dynamic);
    CHECK(parse(R"({"mode":"dynamic","multiplier":6,"dynamicTargetFrameRate":1000,
        "dynamicExperimental56":true,"generatedOnlyDebug":true,
        "intervalLogging":false,"selectiveOtaDlssgWrapper":true})"));
    CHECK(config.dynamic && config.multiplier == 6 && config.dynamicTargetFrameRate == 1000);
    CHECK(config.dynamicExperimental56 && config.generatedOnlyDebug);
    CHECK(config.intervalLogging && !config.selectiveOtaDlssgWrapper);

    for (const auto* text : {
        "", "null", "[]", "{}", "{\"multiplier\":2", "{\"multiplier\":2}garbage",
        "{\"multiplier\":2,}", "{\"multiplier\":2oops}", "{\"multiplier\":02}",
        "{\"multiplier\":2.0}", "{\"multiplier\":2e0}", "{\"multiplier\":-2}",
        "{\"multiplier\":\"2\"}", "{\"multiplier\":null}", "{\"multiplier\":true}",
        "{\"multiplier\":1}", "{\"multiplier\":7}", "{\"multiplier\":18446744073709551616}",
        "{\"multiplier\":2,\"followGame\":truegarbage}",
        "{\"multiplier\":2,\"followGame\":1}",
        "{\"multiplier\":2,\"dynamicTargetFrameRate\":1001}",
        "{\"multiplier\":2,\"dynamicTargetFrameRate\":-1}",
        "{\"multiplier\":2,\"mode\":\"unknown\"}",
        "{\"multiplier\":2,\"mode\":\"follow\"}",
        "{\"multiplier\":2,\"mode\":false}",
        "{\"nested\":{\"multiplier\":4}}",
        "{\"multiplier\":2,\"multiplier\":6}",
        "{\"multiplier\":2,\"multi\\u0070lier\":6}",
        "{\"multiplier\":2,\"metadata\":{\"a\":1,\"a\":2}}"
    })
    {
        CHECK(!parse(text));
        // Failed edits must preserve the previous valid configuration.
        CHECK(config.dynamic && config.multiplier == 6 && config.dynamicTargetFrameRate == 1000);
        CHECK(config.generatedOnlyDebug && config.dynamicExperimental56);
    }
    CHECK(!Parse(nullptr, 1, config));
    const std::string nul = std::string(R"({"multiplier":2})") + '\0' + "garbage";
    CHECK(!parse(nul));
    CHECK(!parse(std::string(kMaximumBytes + 1, ' ')));
    CHECK(!parse("{\"multiplier\":2,\"x\":" + std::string(64, '[')
        + "0" + std::string(64, ']') + "}"));
    CHECK(parse(R"({"multiplier":2,"metadata":[{"a":1},{"a":2}],"mode":"fixed"})"));
    CHECK(parse(R"({"multi\u0070lier":3})"));
    CHECK(config.multiplier == 3);
    std::string exact = R"({"multiplier":2})";
    exact.resize(kMaximumBytes, ' ');
    CHECK(parse(exact));
    exact.push_back(' ');
    CHECK(!parse(exact));
    State state;
    std::atomic<bool> start{false};
    std::atomic<unsigned> finished{0};
    std::array<std::thread, 8> workers;
    for (unsigned id = 0; id < 4; ++id)
        workers[id] = std::thread([&, id] {
            while (!start.load(std::memory_order_acquire)) std::this_thread::yield();
            for (unsigned i = 0; i < 10000; ++i)
            {
                ControlConfig update{};
                update.multiplier = 2 + (i + id) % 5;
                update.dynamicTargetFrameRate = update.multiplier * 100;
                update.dynamic = (update.multiplier & 1u) != 0;
                state.Store(update);
            }
            finished.fetch_add(1, std::memory_order_release);
        });
    for (unsigned id = 4; id < 8; ++id)
        workers[id] = std::thread([&] {
            while (!start.load(std::memory_order_acquire)) std::this_thread::yield();
            uint64_t previous = 0;
            do
            {
                const auto snapshot = state.Read();
                CHECK(snapshot.revision >= previous);
                previous = snapshot.revision;
                if (snapshot.revision != 0)
                {
                    CHECK(snapshot.control.dynamicTargetFrameRate == snapshot.control.multiplier * 100);
                    CHECK(snapshot.control.dynamic == ((snapshot.control.multiplier & 1u) != 0));
                }
            } while (finished.load(std::memory_order_acquire) != 4);
        });
    start.store(true, std::memory_order_release);
    for (auto& worker : workers) worker.join();
    CHECK(state.Revision() == 40000);
    const auto previous = state.Read();
    CHECK(state.BumpRevision() == 40001);
    CHECK(state.Read().control.multiplier == previous.control.multiplier);
    std::puts("Strict JSON, legacy migration, bounds and 40000 concurrent state updates passed");
}
