module indicators;

import std.numeric: dotProduct;
import std.range;
import std.algorithm: map, sum;

template computeFilter(alias zeros, alias poles, Range)  if (isInputRange!Range)
{
  pure double delegate(size_t) computeFilter(Range input, size_t neededOffset, double initialValue)
  {
    return (size_t i) {

      // In initialisation period we return null
      if(i < neededOffset - 1)
      {
        return cast(double) null;
      }
      // At the end of initialisation period we return initial value provided
      else if (i == neededOffset - 1)
      {
        return initialValue;
      }
      // We compute filter current value
      else
      {
        // Zeros part: I(t)*a0 + I(t-1)*a1 + ... + I(t-n)*an
        auto result = dotProduct(input[i - zeros(i).length + 1 .. i + 1], zeros(i));

        // Check if filter is FIR only
        if(sum(poles(i)) == 0.)
        {
          // Filter is FIR no computation needed
          result += 0.;
        }
        else
        {
          // Create delegate function to call computeFilter recursively
          auto _computeFilter = computeFilter!(zeros, poles)(input, neededOffset, initialValue);

          // range of indexes
          auto indexes = iota(poles(i).length);

          // get last filter values
          auto lastFilterValues = map!((k) => _computeFilter(i-k-1))(indexes);

          // Poles Part: O(t-1)*b1 + O(t-2)*b2 + ... + O(t-n)*bn
          result += dotProduct(lastFilterValues, poles(i));
        }
        return result;
      }
    };
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
  auto emaZeros = (size_t x) => [.05];
  auto emaPoles = (size_t x) => [1. - .05];
  auto ema005 = computeFilter!(emaZeros, emaPoles)(values, 1, values[0]);
  auto emaResults = map!(ema005)(timestamps);

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
  auto smaZeros = (size_t x) => [1./3., 1./3., 1./3.];
  auto smaPoles = (size_t x) => [0.];
  auto sma3 = computeFilter!(smaZeros, smaPoles)(values, 2, 0.);
  auto smaResults = map!(sma3)(timestamps);

  foreach(i; timestamps)
  {
    if(i > 1)
    {
      auto mean = sum(values[i - 2 .. i + 1])/3.;
      assert(approxEqual(mean, smaResults[i]));
    }
  }
}
