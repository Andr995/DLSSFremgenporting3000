#pragma once
#include <cstdio>
#include <cstdlib>
#define CHECK(condition) do { if (!(condition)) { \
    std::fprintf(stderr, "%s:%d: %s\n", __FILE__, __LINE__, #condition); \
    std::exit(EXIT_FAILURE); } } while (false)
