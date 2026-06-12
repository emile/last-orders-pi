
# Last orders Pi

1120 decimal digits of π were known in 1949, before that record was shattered
by ENIAC using vacuum tubes and punch cards [1](https://doi.org/10.1090%2FS0025-5718-1950-0037597-6)

This project explores whether EDSAC could in theory have matched
or beat the ENIAC record of 2037 decimal places by using paper tape for storage.

The idea of using magnetic tape as addressable auxiliary storage was discussed by
the creators of EDSAC in 1956, lending some credibility to the idea.
[2](https://doi.org/10.1049/pi-b-1.1956.0070)
[3](https://doi.org/10.1109%2F85.194055)

Eiiti Wada wrote a digit generator for EDSAC in 2022, based on Machin's formula.
It generates 500 digits using main memory (mercury-based delay lines).
This effort demonstrates that the original EDSAC hardware probably lacked
the capacity to match the ENIAC record.
[4](https://www.dcs.warwick.ac.uk/~edsac/Programs2/EiitiPie.html)

This project demonstrates generating about 250 digits using main memory
and many thousands of digits using paper tape as storage. There are many caveats:
* The computation requires an impractical length of paper tape
* The computation would take very long on real hardware
* The algorithm used did not exist at the time

A browser-based EDSAC simulator is included with extended IO instructions
not present in the original hardware, but could plausibly have existed:
* Toggle output to perforator, punching paper tape (instead of teleprinter)
* Toggle output to teleprinter (instead of perforator)
* Switch input to paper tape

Switching the input to paper tape might seem superfluous, since input
is normally read from paper tape by default. The additional instruction
is intended for drawing a distinction between tape containing instructions
and tape containing data, from previous output to the perforator.

There are no instructions for seeking, rewinding or addressing the tapes,
so from the programmer's perspective storage appears as a write head followed by
a read head on an infinite buffer. 

Running the simulator locally required Zig, Python and AWK, or you can
try it [online](https://last-orders-pi.pages.dev/).
