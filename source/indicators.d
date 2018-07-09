module indicators;

import std.numeric: dotProduct;
import std.range;
import std.algorithm: map, sum;
import std.typecons;
import std.traits;

pure auto ema(Range)(Range input, double alpha) if (isInputRange!Range)
{
  auto neededOffset = () { return 1; };

  auto initialValue = () { return input[0]; };

  auto zeros = (size_t i) { return [alpha]; };

  auto poles = (size_t i) { return [1. - alpha]; };

  return Tuple!(typeof(neededOffset), "neededOffset"
    , typeof(initialValue), "initialValue"
    , typeof(zeros), "zeros"
    , typeof(poles), "poles")
    (neededOffset, initialValue, zeros, poles);
}

@safe unittest
{
  import std.math: approxEqual;

  assert(1==1);

  auto values = [0., 1., 2., 3.];
  auto ema005 = ema(values, 0.05);

  assert(ema005.initialValue() == values[0]);
  assert(ema005.neededOffset() == 1);
  assert(approxEqual(ema005.zeros(0), [0.05]));
  assert(approxEqual(ema005.poles(0), [0.95]));
}

pure auto sma(Range)(Range input, size_t depth) if (isInputRange!Range)
{
  auto neededOffset = () { return depth - 1; };

  auto initialValue = () { return input[neededOffset() - 1]; };

  auto zeros = (size_t i) { return (1./cast(double)depth).repeat().take(depth); };

  auto poles = (size_t i) { return [0.]; };

  return Tuple!(typeof(neededOffset), "neededOffset"
    , typeof(initialValue), "initialValue"
    , typeof(zeros), "zeros"
    , typeof(poles), "poles")
    (neededOffset, initialValue, zeros, poles);
}

@safe unittest
{
  import std.math: approxEqual;

  auto values = [0., 1., 2., 3.];
  auto sma2 = sma(values, 2);

  assert(sma2.initialValue() == values[0]);
  assert(sma2.neededOffset() == 1);
  assert(approxEqual(sma2.zeros(0), [1./2., 1./2.]));
  assert(approxEqual(sma2.poles(0), [0.]));
}

pure double delegate(size_t) computeFilter(alias indicator, Range)(Range input)
if (isInputRange!Range 
    && is(typeof(indicator.neededOffset())) 
    && is(typeof(indicator.initialValue()))
    && is(typeof(indicator.zeros(0)))
    && is(typeof(indicator.poles(0)))) 
{
  return (size_t i) {

    // In initialisation period we return null
    if(i < indicator.neededOffset() - 1)
    {
      return double.nan;
    }
    // At the end of initialisation period we return initial value provided
    else if (i == indicator.neededOffset() - 1)
    {
      return indicator.initialValue();
    }
    // We compute filter current value
    else
    {
      // Zeros part: I(t)*a0 + I(t-1)*a1 + ... + I(t-n)*an
      auto result = dotProduct(input[i - indicator.zeros(i).length + 1 .. i + 1], indicator.zeros(i));

      // Check if filter is FIR only
      if(sum(indicator.poles(i)) == 0.)
      {
        // Filter is FIR no computation needed
        result += 0.;
      }
      else
      {
        // Create delegate function to call computeFilter recursively
        auto _computeFilter = computeFilter!(indicator)(input);

        // range of indexes
        auto indexes = iota(indicator.poles(i).length);

        // get last filter values
        auto lastFilterValues = map!((k) => _computeFilter(i-k-1))(indexes);

        // Poles Part: O(t-1)*b1 + O(t-2)*b2 + ... + O(t-n)*bn
        result += dotProduct(lastFilterValues, indicator.poles(i));
      }
      return result;
    }
  };
}

@system unittest
{
  import std.algorithm: equal, sum;
  import std.math: approxEqual, isNaN;

  double[] values = [0., 1., 2., 3.];
  auto timestamps = iota(values.length);

  // EMA
  auto ema005 = ema(values, 0.05);
  auto computeEma005 = computeFilter!(ema005)(values);
  auto emaResults = map!(computeEma005)(timestamps);
  
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
  auto sma3 = sma(values, 3);
  auto computeSma3 = computeFilter!(sma3)(values);
  auto smaResults = map!(computeSma3)(timestamps);

  foreach(i; timestamps)
  {
    if(i == 0)
    {
      assert(isNaN(smaResults[i]));
    }
    else if( i == 1)
    {
      assert(approxEqual(smaResults[i], values[i]));
    }
    else
    {
      assert(approxEqual(smaResults[i], sum(values[i - 2 .. i + 1])/3.));
    }
  }

}
