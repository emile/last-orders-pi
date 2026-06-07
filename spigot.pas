
(*
  transcribed from "A Spigot Algorithm for the Digits of Pi" by Stanley Rabinowitz and Stan Wagon
  https://web.archive.org/web/20240315205853/https://maa.org/sites/default/files/pdf/pubs/amm_supplements/Monthly_Reference_12.pdf
  https://www.maa.org/sites/default/files/pdf/pubs/amm_supplements/Monthly_Reference_12.pdf
  http://stanleyrabinowitz.com/download/spigot-revised.pdf

  > The following program, for which we are grateful to Macalester student Simeon Simeonov,
  > implements the algorithm pi-spigot. This code makes use of the fact that the queue of
  > predigits always has a pile of 9s to the right of its leftmost member, and so only this
  > leftmost predigit and the number of 9s need be remembered. The program computes 1000
  > digits of pi and requires a version of Pascal with a longint data type (32-bit integer).

  fpc -XMPi_Spigot -ospigot_pas spigot.pas
*)

Program Pi_Spigot;
const n =1000;
len     =10*n div 3;
var   i, j, k, q, x, nines, predigit : integer;
      a : array[1..len] of longint;
begin
  for j := 1 to len do a[j] := 2;        {Start with 2s}
  nines := 0; predigit := 0;     {First predigit is a 0}
  for j := 1 to n do
  begin q := 0;
    for i := len downto 1 do            {Work backwards}
    begin
      x := 10*a[i]+q*i;
      a[i] := x mod (2*i-1);
      q := x div (2*i-1);
    end;
    a[1] := q mod 10; q := q div 10;
    if q = 9 then nines := nines + 1
    else if q=10 then
        begin
          write(predigit+1);
          for k := 1 to nines do write(0);       {zeros}
          predigit := 0; nines := 0
        end
        else begin
          write(predigit); predigit := q;
          if nines <> 0 then
          begin
            for k := 1 to nines do write(9);
            nines := 0
          end
        end
  end;
  writeln(predigit);
end.
