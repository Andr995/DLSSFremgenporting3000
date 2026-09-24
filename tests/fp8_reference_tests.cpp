#include "ampere_fp8_emulator.h"
#include "check.h"
#include <array>
#include <cmath>
#include <limits>
#include <thread>

using namespace ampere_emulation;

// Independent mathematical oracle, in double precision.
double Half(unsigned bits)
{
    const unsigned exponent = (bits >> 10) & 31;
    const unsigned fraction = bits & 1023;
    double value = exponent == 0 ? std::ldexp(fraction / 1024.0, -14)
        : exponent == 31 ? (fraction ? std::numeric_limits<double>::quiet_NaN()
                                    : std::numeric_limits<double>::infinity())
        : std::ldexp(1.0 + fraction / 1024.0, static_cast<int>(exponent) - 15);
    return bits & 0x8000 ? -value : value;
}

double Fp8(unsigned bits, Fp8Format format)
{
    const unsigned mantissaBits = format == Fp8Format::eE4M3 ? 3 : 2;
    const unsigned bias = format == Fp8Format::eE4M3 ? 7 : 15;
    const unsigned exponent = (bits & 127) >> mantissaBits;
    const unsigned fraction = bits & ((1u << mantissaBits) - 1);
    double value;
    if (format == Fp8Format::eE4M3 && (bits & 127) == 127)
        value = std::numeric_limits<double>::quiet_NaN();
    else if (format == Fp8Format::eE5M2 && exponent == 31)
        value = fraction ? std::numeric_limits<double>::quiet_NaN()
                         : std::numeric_limits<double>::infinity();
    else
        value = std::ldexp((exponent ? 1.0 : 0.0)
            + static_cast<double>(fraction) / (1u << mantissaBits),
            static_cast<int>(exponent ? exponent : 1) - static_cast<int>(bias));
    return bits & 128 ? -value : value;
}

void Exhaustive(Fp8Format format)
{
    for (unsigned bits = 0; bits < 256; ++bits)
    {
        const double expected = Fp8(bits, format);
        const double actual = Half(ConvertFp8ToFp16(static_cast<uint8_t>(bits), format));
        CHECK(std::isnan(expected) ? std::isnan(actual) : actual == expected);
        if (!std::isnan(expected))
            CHECK(std::signbit(actual) == std::signbit(expected));
    }
    const unsigned maximum = format == Fp8Format::eE4M3 ? 126 : 123;
    std::array<double, 127> candidates{};
    for (unsigned i = 0; i <= maximum; ++i)
        candidates[i] = Fp8(i, format);
    for (unsigned bits = 0; bits < 65536; ++bits)
    {
        const double value = std::abs(Half(bits));
        unsigned expected = 0;
        if (std::isnan(value))
            expected = 127;
        else if (std::isinf(value))
            expected = format == Fp8Format::eE5M2 ? 124 : maximum;
        else
        {
            double best = std::numeric_limits<double>::infinity();
            for (unsigned i = 0; i <= maximum; ++i)
            {
                const double distance = std::abs(value - candidates[i]);
                if (distance < best || (distance == best && (i & 1u) == 0))
                {
                    best = distance;
                    expected = i;
                }
            }
        }
        expected |= (bits & 0x8000) >> 8;
        CHECK(ConvertFp16ToFp8(static_cast<uint16_t>(bits), format) == expected);
    }
}

int main()
{
    // Exercise simultaneous first initialization of the reference tables.
    std::array<std::thread, 8> workers;
    for (auto& worker : workers)
        worker = std::thread([] {
            CHECK(ConvertFp16ToFp8(0x3c00, Fp8Format::eE4M3) == 0x38);
        });
    for (auto& worker : workers)
        worker.join();
    Exhaustive(Fp8Format::eE4M3);
    Exhaustive(Fp8Format::eE5M2);

    std::array<uint8_t, 256> bytes{};
    std::array<uint16_t, 256> halves{};
    for (unsigned i = 0; i < bytes.size(); ++i)
        bytes[i] = static_cast<uint8_t>(i);
    const auto initialCount = GetEmulatedOperationCount();
    for (auto format : {Fp8Format::eE4M3, Fp8Format::eE5M2})
    {
        BatchConvertFp8ToFp16(bytes.data(), halves.data(), bytes.size(), format);
        for (unsigned i = 0; i < bytes.size(); ++i)
            CHECK(halves[i] == ConvertFp8ToFp16(bytes[i], format));
    }
    BatchConvertFp8ToFp16(nullptr, halves.data(), 256, Fp8Format::eE4M3);
    BatchConvertFp8ToFp16(bytes.data(), nullptr, 256, Fp8Format::eE4M3);
    CHECK(GetEmulatedOperationCount() == initialCount + 512);

    std::array<uint8_t, 16 * 32> a{};
    std::array<uint8_t, 32 * 8> b{};
    std::array<float, 16 * 8> c{}, d{};
    for (unsigned i = 0; i < a.size(); ++i)
        a[i] = i % 3 == 0 ? 0x40 : i % 3 == 1 ? 0xb8 : 0;
    for (unsigned i = 0; i < b.size(); ++i)
        b[i] = i % 5 == 0 ? 0xc0 : i % 5 == 1 ? 0x38 : 0;
    for (unsigned i = 0; i < c.size(); ++i)
        c[i] = static_cast<float>(i);
    EmulateMmaM16N8K32_Fp8ToFp32(a.data(), b.data(), c.data(), d.data());
    for (unsigned row = 0; row < 16; ++row)
        for (unsigned column = 0; column < 8; ++column)
        {
            double expected = c[row * 8 + column];
            for (unsigned k = 0; k < 32; ++k)
                expected += Fp8(a[row * 32 + k], Fp8Format::eE4M3)
                    * Fp8(b[column * 32 + k], Fp8Format::eE4M3);
            CHECK(d[row * 8 + column] == expected);
        }
    EmulateMmaM16N8K32_Fp8ToFp32(a.data(), b.data(), c.data(), c.data());
    CHECK(c == d);
    const auto count = GetEmulatedOperationCount();
    EmulateMmaM16N8K32_Fp8ToFp32(nullptr, b.data(), nullptr, d.data());
    CHECK(GetEmulatedOperationCount() == count);
    std::puts("512 FP8 decodes, 131072 FP16 encodes, batch and matrix regressions passed");
}
