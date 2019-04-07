module price;

import std.range: ElementType, isInfinite, hasLength, isInputRange;
import std.traits: isFloatingPoint;
import std.typecons: Tuple, isTuple;
import mir.random;
import mir.random.variable: NormalVariable;

/**
Type of price
*/
enum DataType {OPEN, HIGH, LOW, CLOSE, VOLUME, OPEN_INTEREST}


/**
Returns `true` if `T` is a price tuple which means `T` has the following named fields: timestamp, value and type. 
Examples:
---
isPrice!(Tuple!(long, "timestamp", DataType, "type", double, "value")) // returns true
---
Params:
    T = type to be tested
Returns:
    `true` if T is a price tuple, `false` otherwise.
*/
enum bool isPrice(T) = isTuple!T
&& __traits(hasMember, T, "timestamp")
&& __traits(hasMember, T, "type")
&& __traits(hasMember, T, "value");

unittest
{
    static assert(isPrice!(Tuple!(long, "timestamp", DataType, "type", double, "value")));
}

/**
Compute a range of simulated prices where returns follows a gaussian distribution.
Params:
    calendar = a range of date, epoch which defines the time window of the simulated range.
    µ = gaussian distribution location parameter.
    σ = gaussian distribution scale parameter.
    initialPrice = the initial value of the simulated range.
Returns:
    an Input Range of tuples which contains the price timestamp, the price type and the price value
Example
---
auto p = getGaussianPrices([0, 1, 2], 0., 1., 100.); // three elements range of tuples
---
*/
auto getGaussianPrices(R, T = double)
    (R calendar, in T µ, in T σ, in T initialPrice, in DataType type = DataType.CLOSE) pure nothrow
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
        private DataType type_;

        this(R calendar, in T µ, in T σ, in T initialPrice, in DataType type) pure
        {
            calendar_ = calendar;
            µ_ = µ;
            σ_ = σ;
            initialPrice_ = initialPrice;
            currentReturn_ = 0.;
            type_ = type;
        }

        private auto nextReturn() const
        {
            auto d = NormalVariable!double(µ_, σ_);
            return d(rne);
        }

        static if (hasLength!R) {
            @property bool empty() const
            {
                return currentIndex_ >= calendar_.length;
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
            return Tuple!(ElementType!R, "timestamp", DataType, "type", T, "value")
                (calendar_.front, type_, initialPrice_*(1+currentReturn_));
        }

        void popFront()
        {
            assert(!empty);
            initialPrice_ = front.value;
            currentReturn_ = nextReturn();
            currentIndex_++;
            calendar_.popFront();
        }
    }
    return GaussianPrices!(R, T)(calendar, µ, σ, initialPrice, type);
}

@safe unittest 
{
    import std.traits: ReturnType;
    import heartbeat: NaiveCalendar;
    import std.datetime: Date;

    alias R = ReturnType!(getGaussianPrices!(NaiveCalendar!(Date, "months"), double));
    static assert(isInputRange!R);
}


@safe unittest
{
    import std.range: enumerate;
    import heartbeat: naiveDailyCalendar;
    import std.datetime: Date;
    auto calendar = naiveDailyCalendar(Date(2019, 1, 1), Date(2019, 1, 31));
    auto prices = getGaussianPrices(calendar, 0., 0.05, 100.);
    assert(prices.front.timestamp == 1546300800, "date ok");
    assert(prices.front.type == DataType.CLOSE);
    assert(prices.front.value == 100., "initial price ok");
    immutable auto n = prices.length;
    foreach(i, el; prices.enumerate(1))
    {
        assert(i <= n);
    }
}