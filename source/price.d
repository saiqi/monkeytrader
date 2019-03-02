module price;

import std.range: ElementType, isInfinite, hasLength, isInputRange;
import std.traits: isFloatingPoint;
import mir.random;
import mir.random.variable: NormalVariable;

///
enum DataType {OPEN, HIGH, LOW, CLOSE, VOLUME, OPEN_INTEREST}

///
auto getGaussianPrices(R, T = double)(R calendar, in T mu, in T sigma, in T initialPrice) pure
if(isFloatingPoint!T)
{
    static struct GaussianPrices(R, T)
    {
        private T mu_;
        private T sigma_;
        private T initialPrice_;
        private T currentReturn_;
        private R calendar_;
        private ElementType!R currentTimestamp_;
        private size_t currentIndex_;

        this(R calendar, in T mu, in T sigma, in T initialPrice) pure
        {
            calendar_ = calendar;
            mu_ = mu;
            sigma_ = sigma;
            initialPrice_ = initialPrice;
            currentReturn_ = 0.;
        }

        private auto nextReturn() const
        {
            auto d = NormalVariable!double(mu_, sigma_);
            return d(rne);
        }

        @property bool empty() const
        {
            static if (hasLength!R) {
                return calendar_.length == currentIndex_;
            } else static if (isInfinite!R) {
                return false;
            } else {
                static assert(false, "GaussianPrices range can not be both finite and without length property");
            }
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
            currentReturn_ = nextReturn();
            currentIndex_++;
        }
    }
    return GaussianPrices!(R, T)(calendar, mu, sigma, initialPrice);
}

unittest {
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