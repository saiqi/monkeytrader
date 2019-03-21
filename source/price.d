module price;

import std.range: ElementType, isInfinite, hasLength, isInputRange;
import std.traits: isFloatingPoint;
import mir.random;
import mir.random.variable: NormalVariable;

/**
Type of price
*/
enum DataType {OPEN, HIGH, LOW, CLOSE, VOLUME, OPEN_INTEREST}

/**
Compute a range of simulated prices where returns follows a gaussian distribution.
Params:
    calendar = a range of date, epoch which defines the time window of the simulated range.
    µ = gaussian distribution location parameter.
    σ = gaussian distribution scale parameter.
    initialPrice = the initial value of the simulated range.
Returns:
    an Input Range
Example
---
auto p = getGaussianPrices([0, 1, 2], 0., 1., 100.); // three elements range of double, its first value equals 100.
---
*/
auto getGaussianPrices(R, T = double)(R calendar, in T µ, in T σ, in T initialPrice) pure nothrow
if(isFloatingPoint!T)
{
    static struct GaussianPrices(R, T)
    {
        private T µ_;
        private T σ_;
        private T initialPrice_;
        private T currentReturn_;
        private R calendar_;
        private ElementType!R currentTimestamp_;
        private size_t currentIndex_;

        this(R calendar, in T µ, in T σ, in T initialPrice) pure
        {
            calendar_ = calendar;
            µ_ = µ;
            σ_ = σ;
            initialPrice_ = initialPrice;
            currentReturn_ = 0.;
        }

        private auto nextReturn() const
        {
            auto d = NormalVariable!double(µ_, σ_);
            return d(rne);
        }

        static if (hasLength!R) {
            @property bool empty() const
            {
                return calendar_.length == currentIndex_;
            }
        } else static if (isInfinite!R) {
            @property enum empty = false;
        } else {
            static assert(false, "GaussianPrices range can not be both finite and without length property");
        }
        

        static if (hasLength!R) {
            @property auto length() const
            {
                return calendar_.length; 
            }
        }

        @property auto front() const
        {
            assert(!empty);
            return initialPrice_ * (1 + currentReturn_);
        }

        void popFront()
        {
            initialPrice_ = front();
            currentReturn_ = nextReturn();
            currentIndex_++;
        }
    }
    return GaussianPrices!(R, T)(calendar, µ, σ, initialPrice);
}

unittest 
{
    import std.traits: ReturnType;
    import heartbeat: NaiveCalendar;
    import std.datetime: Date;

    alias R = ReturnType!(getGaussianPrices!(NaiveCalendar!(Date, "months"), double));
    static assert(isInputRange!R);
}


unittest
{
    import heartbeat: naiveDailyCalendar;
    import std.datetime: Date;
    import std.range: take;

    auto calendar = naiveDailyCalendar(Date(2019, 1, 1), Date(2019, 1, 31));
    auto prices = getGaussianPrices(calendar, 0., 0.05, 100.);
    auto n = calendar.length;

    import std.stdio: writeln;
    assert(prices.front == 100., "initial price ok");
    prices.popFront();

}