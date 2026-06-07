# Gibbons algorithm
# https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf
# requires arbitrary-precision arithmetic (BigNum) and therefore GNU awk
#
# gawk -M -f spigot.awk

BEGIN {
    PREC = 1024;
    q = 1; r = 0; t = 1; k = 1; n = 3; l = 3;
    first = 1;
    count = 0;

    while (1) {
        if (4 * q + r - t < n * t) {
            printf "%d", n;
            if (first) {
                printf ".";
                fflush();
                first = 0;
            } else {
                count++;
            }
            if (count % 50 == 0) {
                count = 0;
                printf "\n";
                fflush();
            }
            nr = 10 * (r - n * t);
            n  = int((10 * (3 * q + r) / t) - 10 * n);
            q *= 10;
            r  = nr;
        } else {
            nr = (2 * q + r) * l;
            nn = int((q * (7 * k + 2) + r * l) / (t * l));
            q *= k;
            t *= l;
            l += 2;
            k++;
            n  = nn;
            r  = nr;
        }
    }
}
