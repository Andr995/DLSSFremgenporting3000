#include "control_config.h"

#include <nlohmann/json.hpp>
#include <array>
#include <cstring>
#include <set>
#include <string>

namespace control_config
{
namespace
{
using Json = nlohmann::json;
struct InvalidControl {};

bool Boolean(const Json& object, const char* key, bool& value)
{
    const auto found = object.find(key);
    if (found == object.end())
        return true;
    if (!found->is_boolean())
        return false;
    value = found->get<bool>();
    return true;
}

bool Unsigned(const Json& object, const char* key, uint32_t minimum,
    uint32_t maximum, uint32_t& value, bool required = false)
{
    const auto found = object.find(key);
    if (found == object.end())
        return !required;
    if (!found->is_number_unsigned())
        return false;
    const auto number = found->get<uint64_t>();
    if (number < minimum || number > maximum)
        return false;
    value = static_cast<uint32_t>(number);
    return true;
}
}

bool Parse(const char* data, size_t size, ControlConfig& output)
{
    if (!data || size == 0 || size > kMaximumBytes || std::memchr(data, '\0', size))
        return false;
    try
    {
        // Bound parser recursion and reject duplicate keys, including escaped
        // spellings of the same key. Unknown metadata is allowed and validated.
        std::array<std::set<std::string>, 18> keys;
        const auto callback = [&](int depth, Json::parse_event_t event, Json& value) {
            if (depth < 0 || depth > 16)
                throw InvalidControl{};
            if (event == Json::parse_event_t::object_start)
                keys[static_cast<size_t>(depth) + 1].clear();
            if (event == Json::parse_event_t::key
                && !keys[static_cast<size_t>(depth)].insert(
                    value.get<std::string>()).second)
                throw InvalidControl{};
            return true;
        };
        const Json object = Json::parse(data, data + size, callback, false);
        if (!object.is_object())
            return false;
        ControlConfig parsed{};
        // Legacy configs with no followGame field request a fixed/dynamic override.
        parsed.followGame = false;
        if (!Boolean(object, "followGame", parsed.followGame)
            || !Unsigned(object, "multiplier", 2, 6, parsed.multiplier, true)
            || !Unsigned(object, "dynamicTargetFrameRate", 0, 1000,
                parsed.dynamicTargetFrameRate)
            || !Boolean(object, "dynamicExperimental56", parsed.dynamicExperimental56)
            || !Boolean(object, "generatedOnlyDebug", parsed.generatedOnlyDebug)
            || !Boolean(object, "intervalLogging", parsed.intervalLogging)
            || !Boolean(object, "selectiveOtaDlssgWrapper", parsed.selectiveOtaDlssgWrapper))
            return false;
        const auto mode = object.find("mode");
        if (mode != object.end())
        {
            if (!mode->is_string())
                return false;
            const auto& name = mode->get_ref<const std::string&>();
            if (name == "dynamic")
                parsed.dynamic = true;
            else if (name != "fixed" && !(name == "follow" && parsed.followGame))
                return false;
        }
        if (parsed.followGame)
            parsed.dynamic = false;
        // Protocol 18 retired these switches; accept old files without arming them.
        parsed.intervalLogging = true;
        parsed.selectiveOtaDlssgWrapper = false;
        output = parsed;
        return true;
    }
    catch (const InvalidControl&)
    {
        return false;
    }
    catch (const Json::exception&)
    {
        return false;
    }
}
}
