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
    auto result = dotProduct(input[currentIndex - zeros[currentIndex].length + 1 .. currentIndex + 1], zeros[currentIndex]);
    
    if(poles[currentIndex] is null)
    {
      result += 0.;
    }
    else
    {
      result += dotProduct(iota(poles[currentIndex].length)
                           .map!((i) => computeFilter(input, zeros, poles, currentIndex - i - 1, neededOffset, initialValue)),
                           poles[currentIndex]);
    }
    
    return result;
  }
}

unittest
{
  import std.algorithm: equal, sum;
  import std.math: approxEqual;
  import std.stdio;
  
  double[] values = [0., 1., 2., 3.];
  auto timestamps = iota(values.length);
  
  // EMA
  auto emaZeros = timestamps.map!((a) => [.05]);
  auto emaPoles = timestamps.map!((a) => [.95]);
  auto emaResults = timestamps.map!((a) => computeFilter(values, emaZeros, emaPoles, a, 1, values[0]));
  
  foreach(i; timestamps)
  {
    if(i > 0)
    {
      assert(approxEqual(.05*values[i] + .95*emaResults[i-1], emaResults[i]));
    }
    else 
    {
      assert(approxEqual(values[i], emaResults[i]));
    }
  }
  
  // SMA
  auto smaZeros = timestamps.map!((a) => [1./3., 1./3., 1./3.]);
  auto smaPoles = timestamps.map!((a) => [0]);
  auto smaResults = timestamps.map!((a) => computeFilter(values, smaZeros, smaPoles, a, 2, 0.));
  
  foreach(i; timestamps)
  {
    if(i > 1)
    {
      auto mean = sum(values[i - 2 .. i + 1])/3.;
      assert(approxEqual(mean, smaResults[i]));
    }
  }
}