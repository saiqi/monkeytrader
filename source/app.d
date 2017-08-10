import std.stdio;
import std.range: enumerate;

import quandl;
import indicators;

void main()
{
	auto rawPrices = getDataset("CME", "TYU2017");
	auto prices = getPrice(Datatype.SETTLE, rawPrices);
	auto emaZeros = (size_t x) => [.05];
  auto emaPoles = (size_t x) => [.95];
	
	auto emaResults = prices.enumerate()
		.map!((a) => computeFilter(prices, emaZeros, emaPoles, a[0], 1, prices[0]));
	writeln(emaResults);
}
