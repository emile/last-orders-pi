import sys

# read all input, remove whitespace
raw = sys.stdin.read().strip().lstrip("0").replace(" ", "").replace("\n", "")

# split on decimal point to separate integer and fractional parts
if "." in raw:
    integer_part, fractional_part = raw.split(".", 1)
    digits = fractional_part
else:
    # treat first digit as integer part if there's no decimal point
    integer_part = raw[0] if raw else ""
    digits = raw[1:] if len(raw) > 1 else ""

# print integer part with decimal point
print(f"{integer_part}.")

# print in groups of 10, with 5 groups per line (50 digits per line)
# add blank line every 1000 digits (every 20 lines)
for line_num, line_start in enumerate(range(0, len(digits), 50)):
    line_end = min(line_start + 50, len(digits))
    groups = [digits[i:i+10] for i in range(line_start, line_end, 10)]
    print(" ".join(groups))

    # Add blank line after every 20 lines (1000 digits)
    if (line_num + 1) % 20 == 0:
        print()