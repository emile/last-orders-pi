/*
compute digits of PI using spigot algorithm
source taken from https://www.hvks.com/Numerical/Downloads/HVE%20Practical%20implementation%20of%20Spigot%20Algorithms%20for%20transcendental%20constants.pdf
g++ spigot.cpp -o spigot_cpp
*/

#include <iostream>
#include <string>
#include <climits>

std::string pi_spigot_32 (const int digits, int no_dig = 4)
{
  static unsigned long f_table[]  = { 0, 10, 100, 1000, 10000, 100000 };
  static unsigned long f2_table[] = { 0,  2,  20,  200,  2000,  20000 };
  const int TERMS = (10 * no_dig / 3 + 1);
  bool first_time = true;       // First time in loop flag
  bool overflow_flag = false;   // Overflow flag
  char buffer[32];
  std::string ss;               // The String that hold the calculated PI
  long b, c;                    // Loop counters
  int carry, no_carry = 0;      // Outer loop carrier, plus no of carroer adjustment counts
  unsigned long f, f2;          // New base 1 decimal digits at a time
  unsigned long dig_n = 0;      // dig_n holds the next no_dig digit to add
  unsigned long e = 0;          // Save previous 4 digits
  unsigned long acc = 0, g = 0, tmp32;
  ss.reserve (digits + 16);     // Pre reserve the string size to be able to accumulate all digits plus 8
  if (no_dig > 5)
    no_dig = 5;                 // ensure no_dig<=5
  if (no_dig < 1)
    no_dig = 1;                 // Ensure no_dig>0
  c = (digits / no_dig + 1) * no_dig;   // Since we do collect PI in trunks of no_dig digit at a time we need to ensure
                                        // digits is divisble by no_dig.
  if (no_dig == 1)
    c++;                        // Extra guard digit for 1 digit at a time.
  c = (c / no_dig + 1) * TERMS; // c ensure that the digits we seek is divisble by no_dig
  f = f_table[no_dig];          // Load the initial f
  f2 = f2_table[no_dig];        // Load the initial f2
  unsigned long *a = new unsigned long[c];      // Array of 4 digits decimals
                                                // b is the nominator previous base; c is the index
  for (; (b = c -= TERMS) > 0 && overflow_flag == false; first_time = false)
    {
      for (; --b > 0 && overflow_flag == false;)
        {                           // Check for overflow
	  if (acc > ULONG_MAX / b)
	    overflow_flag = true;
	  acc *= b;                     // Accumulator *= nom previous base
	  tmp32 = f;
	  if (first_time == true)       // Test for first run in the main loop
	    tmp32 *= f2;                // First outer loop. a[b] is not yet initialized
	  else
	    tmp32 *= a[b];              // Non first outer loop. a[b] is initialized in the first loop
	  if (acc > ULONG_MAX - tmp32)
	    overflow_flag = true;       // Check for overflow
	  acc += tmp32;         // add it to accumulator
	  g = b + b - 1;        // denominated previous base
	  a[b] = acc % g;       // Update the accumulator
	  acc /= g;             // save carry
	}
      dig_n = (unsigned long) (e + acc / f);    // Get previous no_dig digits. Could occasinaly be no_dig+1 digits in
                                                // which case we have to propagate back the extra digit.
      carry = (unsigned) (dig_n / f);           // Check for extra carry that we need to propagate back into the
                                                // current sum of PI digits
      dig_n %= f;                               // Eliminate the extra carrier so now l contains no_dig digits to add
                                                // to the string
                                                // Add the carrier to the existing number for PI calculated so far.
      if (carry > 0)
        {
	  ++no_carry;               // Keep count of how many carrier detect
                                // Loop and propagate back the extra carrier to the existing PI digits found so far
	  for (int i = ss.length (); carry > 0 && i > 0; --i)
	    {
                                                    // Never seen more than one loop here but it can handle multiple carry back propagation
	      int new_digit;
	      new_digit = (ss[i - 1] - '0') + carry;    // Calculate new digit
	      carry = new_digit / 10;                   // Calculate new carry if any
	      ss[i - 1] = new_digit % 10 + '0';         // Put the adjusted digit back in our PI digit list
	    }
	}
      (void) sprintf (buffer, "%0*lu", no_dig, dig_n);  // Print previous no_dig digits to buffer
      ss += std::string (buffer);                       // Add it to PI string
      if (first_time == true)
	ss.insert (1, ".");                                 // add the decimal pointafter the first digit to create 3.14...
      acc = acc % f;                                    // save current no_dig digits and repeat loop
      e = (unsigned long) acc;
    }
  if (overflow_flag == false)
    ss.erase (digits + 1);      // Remove the extra digits that we didnt requested but used as guard
                                // digits
  else
    ss = std::string ("Overflow:") + ss;        // Set overflow in the return string
  delete a;                                     // Delete the a[];
  return ss;                                    // Return Pi with the number of digits
}

int main (int argc, char* argv[])
{
  if (argc != 3) {
    std::cerr << "Usage: " << argv[0] << " <digits> <no_digits>" << std::endl;
    std::cerr << "  digits: number of digits to compute" << std::endl;
    std::cerr << "  no_digits: number of digits per iteration (1-5)" << std::endl;
    return 1;
  }

  int digits = std::stoi(argv[1]);
  int no_digits = std::stoi(argv[2]);

  std::cout << pi_spigot_32(digits, no_digits) << std::endl;
  return 0;
}
