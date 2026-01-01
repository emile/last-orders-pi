Computing the digits of PI with EDSAC

According to this Wittenberg article the ENIAC computation used punchcards
for storage of intermediate results:
https://www.wittenberg.edu/news/2013/03-14-pi

The record stood at 1120 decimal digits before ENIAC broke the record in 1949.

This project explores the question of whether EDSAC could in theory have matched
or beat the ENIAC record of 2037 decimal places by using paper tape for storage
of intermediate results.

The idea of using magnetic tape for storage was discussed by the creators of
EDSAC in 1956.
https://doi.org/10.1049/pi-b-1.1956.0070

Eiiti Wada wrote a digit generator for EDSAC in 2022, based on Machin's formula.
It generates 1000 digits using main memory alone.
https://www.dcs.warwick.ac.uk/~edsac/Programs2/EiitiPie.html

Spigot algorithms didn't exist when EDSAC was operational but have some appealing
properties. They only require integer support. The storage access is serial, matching
the serial read and write patterns of a tape.

