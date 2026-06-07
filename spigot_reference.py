import sys

# generator for reference digits of pi using Gibbons algorithm
# https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf

def pi_digits():
 q,r,t,k,n,l = 1,0,1,1,3,3
 while True:
  if 4*q+r-t<n*t:
      yield n
      q,r,t,k,n,l = 10*q, 10*(r-n*t), t, k, (10*(3*q+r))//t-10*n, l
  else:
      q,r,t,k,n,l = q*k, (2*q+r)*l, t*l, k+1, (q*(7*k+2)+r*l)//(t*l), l+2

reference_stream = pi_digits()
failed = False

while(c := sys.stdin.read(1)):
    if c.isdigit():
        reference_digit = next(reference_stream)
        failed = failed or (reference_digit != int(c))
        print(reference_digit if not failed else "_", end="", flush=1)
