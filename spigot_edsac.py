"""
src/pi_tank.asm was based on this template
"""

RADIX      = 100   # .const_radix
ARRAY_LEN  = 822   # .const_array_len
ARRAY_INIT = 20    # .const_array_init
RADIX_LOG  = 2     # .const_radix_log
MAX_COLUMN = 11    # .const_max_column

DIGITS_REMAINING_INIT = 250

output_column = 0
def format_colwidth():
    global output_column
    output_column += 1
    if output_column >= MAX_COLUMN:
        print("\n ", end="")
        output_column = 1


def output_superdigit(s):
    tens, units = divmod(s, 10)
    print(tens, end="")
    format_colwidth()
    print(units, end="")
    format_colwidth()


carry_predigit = 0
carry_initialised = 0
def carry_detector(d):
    global carry_predigit, carry_initialised
    if carry_initialised < 1:
        carry_predigit = d
        carry_initialised = 1
        return
    if d >= RADIX:
        output_superdigit(carry_predigit + 1)
        carry_predigit = 0
    else:
        output_superdigit(carry_predigit)
        carry_predigit = d


def main_inner(remainder, quotient, i):
    return divmod(RADIX * remainder + quotient * i, 2 * i - 1)


def main():

    a = [0] + [ARRAY_INIT] * ARRAY_LEN

    digits_remaining = DIGITS_REMAINING_INIT

    while digits_remaining >= 0:

        quotient = 0
        i = ARRAY_LEN

        while i >= 1:
            remainder = a[i]
            quotient, new_rem = main_inner(remainder, quotient, i)
            a[i] = new_rem
            i -= 1

        new_quotient, remainder = divmod(quotient, RADIX)
        a[1] = remainder
        carry_detector(new_quotient)
        digits_remaining -= RADIX_LOG

    print(end="")


if __name__ == '__main__':
    main()
