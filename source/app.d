import std.stdio;
import std.datetime: Date;
import std.algorithm: map;
import mir.random;
import mir.random.variable: normalVar;
import mir.random.algorithm: randomSlice;
import heartbeat: naiveDailyCalendar;

void main()
{
	auto gen = Random(unpredictableSeed);
	auto d = normalVar;

	double delegate(string) prices = (string t) { return d(gen); };
	double delegate(string) portfolio = (string t) { return 1000.0; };

	bool signals(string t, double delegate(string) prices, double delegate(string) portfolio)
	{
		if(portfolio(t) < 1000.0) return false;
		
		if(prices(t) > 0) return true;
		return false;
	}

	bool randomSignals(string t)
	{
		return signals(t, prices, portfolio);
	}

	auto cal = naiveDailyCalendar(Date(2000, 1, 3), Date(2018, 10, 31));
	import std.array;
	auto result = cal.map!randomSignals;
	writeln(result.front);
	
}