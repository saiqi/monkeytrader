module indicators;

import std.numeric: dotProduct;
import std.range.primitives;
import std.range: iota;
import std.algorithm: map;

pure ElementType!R1 computeFilter(R1, R2, R3, F)
  (R1 input, R2 zeros, R3 poles, size_t currentIndex, size_t neededOffset, F initialValue)
{
  if(currentIndex < neededOffset - 1)
  {
    return cast(double)null;
  }
  else if (currentIndex == neededOffset - 1)
  {
    return initialValue;
  }
  else {
    auto FIR = dotProduct(input[currentIndex - zeros[currentIndex].length + 1 .. currentIndex + 1], zeros[currentIndex]);
    auto IIR = dotProduct(iota(poles[currentIndex].length)
                          .map!((i) => computeFilter(input, zeros, poles, currentIndex - i - 1, neededOffset, initialValue)),
                          poles[currentIndex]);
    
    return FIR + IIR;
  }
}

unittest
{
  import std.algorithm: equal;
  import std.math: approxEqual;
  
  double[] values = [0., 1., 2., 3.];
  auto timestamps = iota(values.length);
  
  // EMA
  auto zeros = timestamps.map!((a) => [.05]);
  auto poles = timestamps.map!((a) => [.95]);
  auto results = timestamps.map!((a) => computeFilter(values, zeros, poles, a, 1, values[0]));
  
  import std.stdio;
  writeln(results);
  
  foreach(i; timestamps)
  {
    if(i > 0)
    {
      assert(approxEqual(.05*values[i] + .95*results[i-1], results[i]));
    }
    else 
    {
      assert(approxEqual(values[i], results[i]));
    }
  }
}