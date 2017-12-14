import std.stdio;
import std.range: enumerate;

import quandl;
import indicators;

void main()
{
	auto rawPrices = getDataset("CME", "TYU2017");
	auto prices = getPrice(Datatype.SETTLE, rawPrices);
	auto ema005 = ema(prices, 0.05);
	auto computeEma005 = computeFilter!(ema005)(prices);

	writeln(computeEma005(20));
}
