#!/usr/bin/env python3
"""
this implementation closely matches the logic of pi_mem.asm
and was used to validate correctness

usage:
    python3 spigot_edsac.py
"""
import sys
import math

# complete carry handling
def carry_detector_general(radix):
    carry_limit = radix - 1
    predigit = None
    carries = 0
    def detector(d):
        nonlocal predigit
        nonlocal carries
        if predigit is None:
            predigit = d
            return None
        if d < carry_limit:
            return_value = [predigit] + [carry_limit] * carries
            predigit = d
            carries = 0
            return return_value
        if d == carry_limit:
            carries += 1
            return None
        if d == radix:
            return_value = [predigit + 1] + [0] * carries
            carries = 0
            predigit = 0
            return return_value
        assert False
    return detector

# no carry detection
def carry_detector0(radix):
    def detector(d):
        return [d]
    return detector

# minimal carry detection
def carry_detector1(radix):
    predigit = None
    def detector(d):
        nonlocal predigit
        if predigit is None:
            predigit = d
            return None
        elif d == radix:
            return_value, predigit = predigit + 1, 0
            return [return_value]
        else:
            return_value, predigit = predigit, d
            return [return_value]
    return detector


def divmod_slow(numerator, denominator):
    quotient = 0
    remainder = numerator

    while True:
        test = remainder - denominator
        if test < 0:
            # exit without updating remainder
            break
        # update remainder and increment quotient
        remainder = test
        quotient = quotient + 1

    return quotient, remainder


def divmodpy(numerator, denominator):
    return divmod(numerator, denominator)


def main_inner(radix, remainder, quotient, i):
    x = radix * remainder + quotient * i
    denominator = 2 * i - 1
    new_quotient, new_remainder = divmod_local(x, denominator)
    return new_quotient, new_remainder


divmod_local = divmodpy
carry_detector = carry_detector1

def compute_pi_digits(n, radix = 10):

    const_log_radix = int(math.log10(radix))
    const_init = radix // 5
    digits_remaining = const_log_radix + n + 3 # bits stuck in carry detection buffer
    const_array_len = int(((digits_remaining // const_log_radix) + 1) * 14)
    released_digits = carry_detector(radix)

    # initialise array
    # a[0] is unused, but included for clarity
    a = [0] + [const_init] * const_array_len

    output = []
    iteration = 0

    # main loop
    while digits_remaining >= 0:

        iteration += 1

        # initialise quotient to 0
        quotient = 0

        # initialise i to array_len
        i = const_array_len

        # inner i-loop
        # loop from arraylen down to i=1 (NOT including i=0)
        while i >= 1:
            # read a[i] and save to remainder
            remainder = a[i]

            # call main_inner
            new_quotient, new_remainder = main_inner(radix, remainder, quotient, i)

            # save new quotient
            quotient = new_quotient

            # save new remainder to a[i]
            a[i] = new_remainder

            # decrement i and check loop condition
            # loop continues while (i-2) >= 0, i.e., while i >= 2 after decrement
            i = i - 1

        # divide by radix to extract digits
        new_quotient, remainder = divmod_local(quotient, radix)

        # save remainder
        a[1] = remainder

        # output processing for quotient
        output_digits = released_digits(new_quotient)
        if output_digits is not None:
            for output_digit in output_digits:
                for c in f"{output_digit:0{const_log_radix}}":
                    output.append(int(c))
                    digits_remaining -= 1

    return output


if __name__ == "__main__":

    n = 250
    radix = 100
    if len(sys.argv) > 1:
        n = int(sys.argv[1])
    if len(sys.argv) > 2:
        radix = int(sys.argv[2])

    digits = compute_pi_digits(n+1, radix)
    print(f"{digits[0]}.")
    remaining = digits[1:n + 1]
    for i in range(0, len(remaining), 10):
        group = remaining[i:i+10]
        print(''.join(map(str, group)), end=' ')
        if (i + 10) % 50 == 0: # line for every 50 digits
            print()
        if (i + 10) % 1000 == 0: # paragraph every 1000 digits
            print()
    print()
