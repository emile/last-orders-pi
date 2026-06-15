
This project answers a historical speculative question: could EDSAC have beat the record for number of digits for pi set by ENIAC?

It includes an assembler targetting the instruction set of EDSAC in 1949 using initial orders 2.

There's an implementation of a spigot algorithm for the digits in this assembly language.

And there's a simulator to run it, either on the commandline or [in the browser](https://last-orders-pi.pages.dev/).

The answer to the question is a qualified "maybe". The program runs and produces thousands of digits, with caveats:
* EDSAC would have needed IO instructions to use tape for storage
* The computation would require an impractical length of paper tape
* The computation would take very long on real hardware
* The algorithm wasn't known at the time


## References

   * [THE PREPARATION OF PROGRAMS FOR AN ELECTRONIC DIGITAL COMPUTER](https://en.wikipedia.org/wiki/The_Preparation_of_Programs_for_an_Electronic_Digital_Computer)
   * [Tutorial Guide to the EDSAC Simulator](http://www.dcs.warwick.ac.uk/~edsac/Software/EdsacTG.pdf)
   * [Assembly conventions for the EDSAC. EWD718](https://www.cs.utexas.edu/~EWD/ewd07xx/EWD718.PDF)

## See also
   * [EDSAC on browser](http://nhiro.org/learn_language/repos/EDSAC-on-browser/index.html) by NISHIO Hirokazu
   * [edsim](https://computerconservationsociety.org/emu/edsac/index.htm) by Lee Wittenberg
   * [edsacasm](https://github.com/andrewjherbert/edsacasm) by Andrew Herbert
   * [QEdsac](https://github.com/qedsac/qedsac)
   * [Eiiti Wada programs for computing pi](https://www.dcs.warwick.ac.uk/~edsac/Programs2/EiitiPie.html)
