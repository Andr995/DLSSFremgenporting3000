#include "status_validation.h"
#include <nlohmann/json.hpp>
#include <set>

namespace status_validation
{
namespace { struct InvalidStatus {}; }
bool IsCurrent(const std::string& text, Session session, uint64_t nowSeconds)
{
    if (!session.pid || !session.processStartTime || text.empty()
        || text.size() > 1024 * 1024 || text.find('\0') != std::string::npos)
        return false;
    try
    {
        // Status output is a flat object. Reject nested/duplicate properties so
        // downstream legacy field readers cannot select a different value.
        std::set<std::string> keys;
        const auto callback = [&](int depth, nlohmann::json::parse_event_t event,
                                  nlohmann::json& value) {
            if (depth > 1
                || (depth != 0 && (event == nlohmann::json::parse_event_t::object_start
                    || event == nlohmann::json::parse_event_t::array_start))
                || (event == nlohmann::json::parse_event_t::key
                && !keys.insert(value.get<std::string>()).second))
                throw InvalidStatus{};
            return true;
        };
        const auto object = nlohmann::json::parse(text, callback, false);
        if (!object.is_object())
            return false;
        const auto unsignedValue = [&](const char* name, uint64_t& result) {
            const auto item = object.find(name);
            if (item == object.end() || !item->is_number_unsigned())
                return false;
            result = item->get<uint64_t>();
            return true;
        };
        uint64_t protocol = 0, pid = 0, start = 0, heartbeat = 0;
        return unsignedValue("version", protocol) && protocol == kProtocolVersion
            && unsignedValue("pid", pid) && pid == session.pid
            && unsignedValue("processStartTime", start) && start == session.processStartTime
            && unsignedValue("heartbeat", heartbeat) && heartbeat != 0 && heartbeat <= nowSeconds
            && nowSeconds - heartbeat <= kMaximumAgeSeconds;
    }
    catch (const InvalidStatus&) { return false; }
    catch (const nlohmann::json::exception&) { return false; }
}
}
