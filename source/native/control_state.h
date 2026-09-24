#pragma once
#include "control_config.h"
#include <mutex>

namespace control_config
{
struct Snapshot
{
    ControlConfig control{};
    uint64_t revision = 0;
};

// Fields and revision are one transaction. Never call external code while
// holding this lock; readers cannot observe part of a concurrent update.
class State
{
public:
    uint64_t Store(const ControlConfig& control)
    {
        std::lock_guard lock(mutex_);
        snapshot_.control = control;
        return ++snapshot_.revision;
    }
    uint64_t BumpRevision()
    {
        std::lock_guard lock(mutex_);
        return ++snapshot_.revision;
    }
    Snapshot Read() const
    {
        std::lock_guard lock(mutex_);
        return snapshot_;
    }
    uint64_t Revision() const { return Read().revision; }
private:
    mutable std::mutex mutex_;
    Snapshot snapshot_{};
};
}
