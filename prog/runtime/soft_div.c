/*
 * soft_div.c - Software multiply/divide/modulo routines for RV32I
 *
 * RV32I has no hardware multiply/divide instructions, so the compiler emits
 * calls to these GCC runtime helpers whenever C code uses '*', '/' or '%'
 * on integer types.
 * When built with -nostdlib (and no -lgcc), we must supply them ourselves.
 *
 * Symbols provided:
 *   __mulsi3    32-bit multiplication           (a * b), low 32 bits
 *   __udivsi3   unsigned 32-bit division        (a / b)
 *   __umodsi3   unsigned 32-bit modulo          (a % b)
 *   __divsi3    signed   32-bit division        (a / b)
 *   __modsi3    signed   32-bit modulo          (a % b)
 */

typedef unsigned int  uint32;
typedef   signed int  int32;

unsigned int __mulsi3(unsigned int a, unsigned int b)
{
    uint32 result = 0;

    while (b != 0) {
        if (b & 1u) {
            result += a;
        }
        a <<= 1;
        b >>= 1;
    }

    return result;
}

/* ------------------------------------------------------------------ */
/* Unsigned core: fills *rem_out (if non-NULL) and returns quotient.  */
/* ------------------------------------------------------------------ */
static uint32 udivmod(uint32 a, uint32 b, uint32 *rem_out)
{
    if (b == 0) {
        /* Undefined behaviour; return 0 to avoid infinite loop. */
        if (rem_out) *rem_out = 0;
        return 0;
    }

    uint32 quotient  = 0;
    uint32 remainder = 0;

    for (int i = 31; i >= 0; --i) {
        remainder = (remainder << 1) | ((a >> i) & 1u);
        if (remainder >= b) {
            remainder -= b;
            quotient  |= (1u << i);
        }
    }

    if (rem_out) *rem_out = remainder;
    return quotient;
}

/* ------------------------------------------------------------------ */
/* Public GCC runtime symbols                                         */
/* ------------------------------------------------------------------ */

unsigned int __udivsi3(unsigned int a, unsigned int b)
{
    return udivmod(a, b, (uint32 *)0);
}

unsigned int __umodsi3(unsigned int a, unsigned int b)
{
    uint32 rem;
    udivmod(a, b, &rem);
    return rem;
}

int __divsi3(int a, int b)
{
    int neg = ((a < 0) ^ (b < 0));
    uint32 ua = (a < 0) ? (uint32)(-a) : (uint32)a;
    uint32 ub = (b < 0) ? (uint32)(-b) : (uint32)b;
    uint32 q  = udivmod(ua, ub, (uint32 *)0);
    return neg ? -(int)q : (int)q;
}

int __modsi3(int a, int b)
{
    int neg = (a < 0);
    uint32 ua = (a < 0) ? (uint32)(-a) : (uint32)a;
    uint32 ub = (b < 0) ? (uint32)(-b) : (uint32)b;
    uint32 rem;
    udivmod(ua, ub, &rem);
    return neg ? -(int)rem : (int)rem;
}
