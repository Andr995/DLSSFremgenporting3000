#include "ampere_fp8_emulator.h"

#include <array>
#include <atomic>
#include <cmath>
#include <limits>

namespace ampere_emulation
{
namespace
{
std::atomic<uint64_t> gReferenceOperationCount{0};

constexpr uint16_t Decode(uint8_t value, Fp8Format format) noexcept
{
    const uint16_t sign = static_cast<uint16_t>((value & 0x80u) << 8);
    const unsigned magnitude = value & 0x7fu;
    if (format == Fp8Format::eE5M2)
    {
        // Exponent bias is identical; preserve infinities and quiet any NaN.
        const uint16_t bits = static_cast<uint16_t>(magnitude << 8);
        return static_cast<uint16_t>(sign | bits | (magnitude > 0x7cu ? 0x0200u : 0u));
    }
    if (magnitude == 0x7fu)
        return static_cast<uint16_t>(sign | 0x7e00u); // E4M3FN has NaNs, but no infinities.
    unsigned exponent = magnitude >> 3;
    unsigned mantissa = magnitude & 7u;
    if (exponent != 0)
        return static_cast<uint16_t>(sign | ((exponent + 8u) << 10)
            | (mantissa << 7));
    if (mantissa == 0)
        return sign;
    exponent = 9;
    while (mantissa < 8u)
    {
        mantissa <<= 1;
        --exponent;
    }
    return static_cast<uint16_t>(sign | (exponent << 10)
        | ((mantissa - 8u) << 7));
}

float HalfToFloat(uint16_t bits) noexcept
{
    const unsigned exponent = (bits >> 10) & 31u;
    const unsigned mantissa = bits & 1023u;
    float magnitude = exponent == 0 ? std::ldexp(static_cast<float>(mantissa), -24)
        : exponent == 31 ? (mantissa ? std::numeric_limits<float>::quiet_NaN()
                                    : std::numeric_limits<float>::infinity())
        : std::ldexp(static_cast<float>(1024u + mantissa),
            static_cast<int>(exponent) - 25);
    return bits & 0x8000u ? -magnitude : magnitude;
}

struct ConversionTables
{
    std::array<uint16_t, 256> e4m3{};
    std::array<uint16_t, 256> e5m2{};
    std::array<float, 256> e4m3Float{};
    ConversionTables() noexcept
    {
        for (unsigned i = 0; i < 256; ++i)
        {
            e4m3[i] = Decode(static_cast<uint8_t>(i), Fp8Format::eE4M3);
            e5m2[i] = Decode(static_cast<uint8_t>(i), Fp8Format::eE5M2);
            e4m3Float[i] = HalfToFloat(e4m3[i]);
        }
    }
};

const ConversionTables& Tables() noexcept
{
    // Safe even when called from another translation unit's static initializer.
    static const ConversionTables tables;
    return tables;
}
}

uint16_t ConvertFp8ToFp16(uint8_t value, Fp8Format format) noexcept
{
    return Decode(value, format);
}

uint8_t ConvertFp16ToFp8(uint16_t value, Fp8Format format) noexcept
{
    const uint8_t sign = static_cast<uint8_t>((value >> 8) & 0x80u);
    const uint16_t magnitude = value & 0x7fffu;
    const bool e5m2 = format == Fp8Format::eE5M2;
    const unsigned maximum = e5m2 ? 0x7bu : 0x7eu;
    if (magnitude > 0x7c00u)
        return static_cast<uint8_t>(sign | 0x7fu);
    if (magnitude == 0x7c00u && e5m2)
        return static_cast<uint8_t>(sign | 0x7cu);
    const auto& table = e5m2 ? Tables().e5m2 : Tables().e4m3;
    if (magnitude >= table[maximum])
        return static_cast<uint8_t>(sign | maximum);
    // Positive finite half bit patterns are ordered numerically. Find the
    // bounding FP8 values, then round to nearest, ties to even (including zero).
    unsigned low = 0;
    unsigned high = maximum;
    while (high - low > 1)
    {
        const unsigned middle = (low + high) / 2;
        if (table[middle] <= magnitude)
            low = middle;
        else
            high = middle;
    }
    const float input = HalfToFloat(magnitude);
    const float lowerDistance = input - HalfToFloat(table[low]);
    const float upperDistance = HalfToFloat(table[high]) - input;
    const unsigned rounded = lowerDistance < upperDistance ? low
        : upperDistance < lowerDistance ? high : (low & 1u) ? high : low;
    return static_cast<uint8_t>(sign | rounded);
}

void BatchConvertFp8ToFp16(const uint8_t* source, uint16_t* destination,
    size_t count, Fp8Format format) noexcept
{
    if (!source || !destination)
        return;
    const auto& table = format == Fp8Format::eE4M3 ? Tables().e4m3 : Tables().e5m2;
    for (size_t i = 0; i < count; ++i)
        destination[i] = table[source[i]];
    gReferenceOperationCount.fetch_add(count, std::memory_order_relaxed);
}

void EmulateMmaM16N8K32_Fp8ToFp32(const uint8_t* matrixA,
    const uint8_t* matrixB, const float* matrixC, float* matrixD) noexcept
{
    if (!matrixA || !matrixB || !matrixD)
        return;
    const auto& table = Tables().e4m3Float;
    for (size_t i = 0; i < 16; ++i)
    {
        for (size_t j = 0; j < 8; ++j)
        {
            float accumulator = matrixC ? matrixC[i * 8 + j] : 0.0f;
            for (size_t k = 0; k < 32; ++k)
                accumulator = std::fma(table[matrixA[i * 32 + k]],
                    table[matrixB[j * 32 + k]], accumulator);
            matrixD[i * 8 + j] = accumulator;
        }
    }
    gReferenceOperationCount.fetch_add(16 * 8 * 32, std::memory_order_relaxed);
}

uint64_t GetEmulatedOperationCount() noexcept
{
    return gReferenceOperationCount.load(std::memory_order_relaxed);
}
}
