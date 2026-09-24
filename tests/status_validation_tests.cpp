#include "status_validation.h"
#include "check.h"
#include <string>

using namespace status_validation;
int main()
{
    const Session session{123, 987654321};
    const auto make = [](unsigned pid, uint64_t start, uint64_t heartbeat, unsigned version = 19) {
        return "{\"version\":" + std::to_string(version)
            + ",\"pid\":" + std::to_string(pid)
            + ",\"processStartTime\":" + std::to_string(start)
            + ",\"heartbeat\":" + std::to_string(heartbeat) + "}";
    };
    CHECK(IsCurrent(make(123, 987654321, 100), session, 100));
    CHECK(IsCurrent(make(123, 987654321, 100), session, 105));
    CHECK(!IsCurrent(make(123, 987654321, 100), session, 106));
    CHECK(!IsCurrent(make(123, 987654321, 101), session, 100));
    CHECK(!IsCurrent(make(124, 987654321, 100), session, 100));
    CHECK(!IsCurrent(make(123, 987654320, 100), session, 100)); // Reused PID.
    CHECK(!IsCurrent(make(123, 987654321, 100, 18), session, 100));
    CHECK(!IsCurrent(make(123, 987654321, 100, 20), session, 100));
    CHECK(!IsCurrent(make(123, 987654321, 100), {}, 100));
    CHECK(!IsCurrent(make(123, 987654321, 0), session, 0));
    const auto valid = make(123, 987654321, 100);
    for (const auto* extra : {",\"pid\":124", ",\"p\\u0069d\":123", ",\"nested\":{}",
                             ",\"nested\":[]", ",\"nested\":{\"bridgeReady\":true}"})
        CHECK(!IsCurrent(valid.substr(0, valid.size()-1) + extra + "}", session, 100));
    CHECK(!IsCurrent(valid + "junk", session, 100));
    CHECK(!IsCurrent(valid + '\0', session, 100));
    CHECK(!IsCurrent(valid.substr(0, valid.size()-1), session, 100));
    CHECK(!IsCurrent(R"({"pid":123,"heartbeat":100})", session, 100));
    CHECK(!IsCurrent(std::string(1024 * 1024 + 1, ' '), session, 100));
    std::puts("Status protocol, PID reuse, freshness, future time and malformed JSON passed");
}
