# format a stream of digits, assuming a decimal point after leading digit
# only works with GNU Awk since it uses RT (record terminator)

BEGIN {
    # every character is a separator
    RS = "[0-9_]"
}
{
    # actual digit is in RT
    char = RT
    if (char == "") next;

    # handle first digit and decimal point
    if (!started) {
        printf "%s.", char;
        started = 1;
        fflush();
        next;
    }
    printf "%s", char;
    c++;

    if (c % 1000 == 0) printf "\n\n  ";  # blocks of 1000
    else if (c % 50 == 0) printf "\n  "; # lines  of 50
    else if (c % 10 == 0) printf " ";    # groups of 10
    fflush();
}
END {
    print "\n";
}
