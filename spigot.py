"""
Compute digits of PI using spigot algorithm
https://www.hvks.com/Numerical/Downloads/HVE%20Practical%20implementation%20of%20Spigot%20Algorithms%20for%20transcendental%20constants.pdf
"""

import sys


def pi_spigot(digits: int, no_dig: int = 4) -> tuple[str, int]:
    """
    Calculate PI using the spigot algorithm without the first_time flag.

    Instead of checking first_time, pre-populate the array with f2 values.
    This eliminates the conditional branch in the inner loop.

    Args:
        digits: Number of digits to compute
        no_dig: Number of digits per iteration (1-5)

    Returns:
        A tuple of (pi_string, max_value) where:
        - pi_string is the computed PI digits as a string
        - max_value is the largest integer value encountered during computation
    """
    f_table = [0, 10, 100, 1000, 10000, 100000]
    f2_table = [0, 2, 20, 200, 2000, 20000]

    TERMS = (10 * no_dig // 3 + 1)
    max_value = 0      # Track the maximum value encountered

    ss = ""  # The string that holds the calculated PI
    no_carry = 0  # Number of carrier adjustment counts
    dig_n = 0  # dig_n holds the next no_dig digit to add
    e = 0  # Save previous digits
    acc = 0
    g = 0

    # Ensure no_dig is in valid range
    if no_dig > 5:
        no_dig = 5
    if no_dig < 1:
        no_dig = 1

    # Since we collect PI in chunks of no_dig digits at a time,
    # ensure digits is divisible by no_dig
    c = (digits // no_dig + 1) * no_dig

    # Extra guard digit for 1 digit at a time
    if no_dig == 1:
        c += 1

    # Ensure that the digits we seek is divisible by no_dig
    c = (c // no_dig + 1) * TERMS

    f = f_table[no_dig]   # Load the initial f
    f2 = f2_table[no_dig]  # Load the initial f2

    # Initialize array with f2 values instead of zeros
    # This eliminates the need for first_time check
    a = [f2] * c

    # Main loop
    while True:
        c -= TERMS
        b = c
        if b <= 0:
            break

        # Inner loop
        while True:
            b -= 1
            if b <= 0:
                break

            # Track maximum value
            acc *= b  # Accumulator *= nom previous base
            max_value = max(max_value, acc)

            # Always use a[b] - no conditional needed
            # First iteration reads f2, subsequent iterations read computed values
            term = f * a[b]

            acc += term  # Add it to accumulator
            max_value = max(max_value, acc)

            g = b + b - 1  # Denominated previous base
            acc, a[b] = divmod(acc, g)  # Save carry and update accumulator

        # Get previous no_dig digits. Could occasionally be no_dig+1 digits
        # in which case we have to propagate back the extra digit.
        dig_n = e + acc // f

        # Check for extra carry that we need to propagate back into the
        # current sum of PI digits
        carry, dig_n = divmod(dig_n, f)  # Split into carry and digits

        # Add the carrier to the existing number for PI calculated so far
        if carry > 0:
            no_carry += 1  # Keep count of how many carriers detected

            # Loop and propagate back the extra carrier to the existing PI digits found so far
            i = len(ss)
            while carry > 0 and i > 0:
                # Calculate new digit
                new_digit = int(ss[i - 1]) + carry
                carry, digit = divmod(new_digit, 10)  # Calculate new carry and digit
                ss = ss[:i-1] + str(digit) + ss[i:]  # Put the adjusted digit back
                i -= 1

        # Format previous no_dig digits to buffer
        ss += f"{dig_n:0{no_dig}d}"

        # Add decimal point after first chunk (when length equals no_dig)
        if len(ss) == no_dig:
            ss = ss[0] + '.' + ss[1:]

        acc = acc % f  # Save current no_dig digits and repeat loop
        e = acc

    # Remove the extra digits that we didn't request but used as guard digits
    ss = ss[:digits + 1]

    return ss, max_value


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <digits> <no_digits>", file=sys.stderr)
        print("  digits: number of digits to compute", file=sys.stderr)
        print("  no_digits: number of digits per iteration (1-5)", file=sys.stderr)
        sys.exit(1)

    try:
        digits = int(sys.argv[1])
        no_digits = int(sys.argv[2])
    except ValueError:
        print("Error: arguments must be integers", file=sys.stderr)
        sys.exit(1)

    pi_value, max_val = pi_spigot(digits, no_digits)
    print(pi_value)
    print(f"Maximum value encountered: {max_val}", file=sys.stderr)


if __name__ == "__main__":
    main()
