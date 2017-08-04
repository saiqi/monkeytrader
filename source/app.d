import std.stdio;

import quandl;

void main()
{
	auto rawPrices = getDataset("CME", "PAQ2017");
	auto prices = getPrice(Datatype.HIGH, rawPrices);
	writeln(prices);
}
