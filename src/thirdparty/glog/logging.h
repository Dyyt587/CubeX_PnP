#pragma once

#include <iostream>

namespace glog_compat {
class LogStream {
public:
    explicit LogStream(const char *level)
    {
        std::cerr << "[" << level << "] ";
    }

    ~LogStream()
    {
        std::cerr << std::endl;
    }

    template <typename T>
    LogStream &operator<<(const T &value)
    {
        std::cerr << value;
        return *this;
    }
};
} // namespace glog_compat

#define LOG(level) glog_compat::LogStream(#level)
#define DLOG(level) glog_compat::LogStream(#level)
