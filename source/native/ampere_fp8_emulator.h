#pragma once

#include <cstdint>
#include <cstddef>

// CPU reference arithmetic for future backend validation. These functions do
// not intercept CUDA instructions, access GPU buffers, or enable NGX on Ampere.
namespace ampere_emulation
{
enum class Fp8Format : uint32_t
{
    eE4M3 = 0, // E4M3FN: bias 7, finite extended exponent, signed NaNs.
    eE5M2 = 1  // Bias 15, IEEE-style infinities and NaNs.
};

// Decode exactly; quiet NaNs and preserve their sign, and signed zero.
uint16_t ConvertFp8ToFp16(uint8_t value, Fp8Format format) noexcept;
// Round to nearest, ties to even, saturating finite overflow. Preserve E5M2
// infinities; saturate E4M3 infinities; canonicalize NaNs with sign preserved.
uint8_t ConvertFp16ToFp8(uint16_t value, Fp8Format format) noexcept;

// Host buffers must not overlap. Null buffers are a no-op.
void BatchConvertFp8ToFp16(const uint8_t* source, uint16_t* destination,
    size_t count, Fp8Format format) noexcept;

// Numerical reference for a row.col tile, not CUDA warp-register emulation.
// A: row-major 16x32; B: column-major 32x8; C/D: row-major 16x8.
// C may be null (zero) or equal D. Other buffers must not overlap.
void EmulateMmaM16N8K32_Fp8ToFp32(const uint8_t* matrixA,
    const uint8_t* matrixB, const float* matrixC, float* matrixD) noexcept;

// Counts CPU reference work only, never GPU execution or generated frames.
uint64_t GetEmulatedOperationCount() noexcept;
}
