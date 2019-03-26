module indicator;

import std.range: isInfinite, isInputRange, isBidirectionalRange, hasLength, ElementType, take, drop;
import std.traits: isNumeric, isFloatingPoint;
import std.algorithm: sum, map;
import std.array;
import std.typecons: tuple, isTuple;
import std.exception: enforce;
import std.conv: to;
import std.math: isNaN;
import price: isPrice;

/**
Type of regime
*/
enum Regime: short {BULL = 1, BEAR = - 1, FLAT = 0}

/**
Systems available
*/
enum TradingSystem {
    SMA_ONE_LINE_POSITION
}

/**
Type of signal
*/
enum SignalType {BUY, SELL, ROLL, NONE}

/**
This implements the missing value management depending on `R` type.
`R` must be a numeric type.
`MissingValue` template include a `missingValue` function in its scope 
which returns `NaN` if `R` is typed as floating point type, `0` else.
*/
mixin template MissingValue(R)
if(isNumeric!(ElementType!R))
{
    static if (isFloatingPoint!(ElementType!R)) {
        auto missingValue() pure @nogc @safe nothrow 
        {
            return (ElementType!R).nan;
        }
    } else {
        auto missingValue() pure @nogc @safe nothrow 
        {
            return 0;
        }
    }
}

/**
This computes the moving average of a given range.
As we can't calculate the first n elements their value are those 
returned by missingValue function in MissingValue template 
(`NaN` if the elements type is a floating point, `0` otherwise)
Please note that the algorithm complexity decreases by order of magnitude 
when prices are provided through a bidirectional range
Params:
    prices = a range which contains numeric elements.
    depth = the depth of the moving average
Returns:
    a ForwardRange
Example:
---
auto sma = MovingAverage([1., 2., 3.], 2); // sma contains [double.nan, 1.5, 2.5]
---
*/
auto movingAverage(R)(R prices, in size_t depth) pure nothrow
if(isInputRange!R && isNumeric!(ElementType!R))
{
    static struct MovingAverage(R)
    {
        private R prices_;
        private ElementType!R lastSumValue_;
        private ElementType!R currentSumValue_;
        private size_t depth_;
        private size_t currentIndex_;

        mixin MissingValue!R;

        this(R prices, in size_t depth) pure
        {
            prices_ = prices;
            depth_ = depth;
            currentIndex_ = 0;
            currentSumValue_ = missingValue();
        }

        @property auto rollingSum()
        {
            if(currentIndex_ < depth_ - 1) return missingValue();

            if(currentIndex_ == depth_ - 1) return prices_.take(depth_).sum;

            static if (isBidirectionalRange!R) {
                auto sample = prices_.drop(currentIndex_ - depth_).take(depth_ + 1);
                return lastSumValue_ 
                    + sample.back 
                    - sample.front;
            } else {
                return prices_.take(depth_).sum;
            }
        }

        static if (hasLength!R) {
            @property bool empty() 
            {
                return currentIndex_ >= prices_.length;
            }
        } else static if (isInfinite!R){
            @property enum empty = false;
        } else {
            static assert(false, "MovingAverage range can not be both finite and without length property");
        }

        void popFront()
        {
            assert(!empty);

            lastSumValue_ = currentSumValue_;
            currentIndex_++;
            currentSumValue_ = rollingSum();
        }

        @property auto front()
        {
            assert(!empty);
            static if (isFloatingPoint!(ElementType!R)) {
                return currentSumValue_ / depth_;
            } else {
                return currentSumValue_ / depth_;
            }
        }

        auto save()
        {
            auto copy = MovingAverage!R(prices_, depth_);
            copy.currentIndex_ = currentIndex_;
            copy.lastSumValue_ = lastSumValue_;
            copy.currentSumValue_ = currentSumValue_;
            return copy;
        }

    }

    return MovingAverage!R(prices, depth);
}

@safe unittest
{
    auto sma = movingAverage([1., 2., 3., 4., 5.], 2);
    sma.popFront();
    assert(sma.front == 1.5);
}

@safe unittest
{
    import std.range: repeat;
    auto prices = 4.5.repeat.take(80);
    auto sma = movingAverage(prices, 5);
    assert(isNaN(sma.front), "double range first value is nan");
}

@safe unittest
{
    import std.range: iota;
    auto prices = iota(50);
    auto sma = movingAverage(prices, 5);
    assert(sma.front == 0, "integer range first value is nan");
}

@safe unittest
{
    import std.range: iota;
    import std.conv: to;
    import std.algorithm: map;
    import std.algorithm.comparison: equal;

    auto prices = iota(5).map!((a) => to!double(a%2) + to!double(a%3));

    auto sma = movingAverage(prices, 3).array;

    auto result = [
        double.nan,
        double.nan,
        4./3.,
        5./3.,
        4./3.
    ];

    assert(equal(sma[2 .. $], result[2 .. $]), "computation succeed");

}

@safe unittest
{
    import std.range: repeat;
    auto p = 3.4.repeat;
    auto sma = movingAverage(p, 5);
    static assert(isInfinite!(typeof(sma)), "infinite prices give infinite sma");
}

@safe unittest
{
    auto p = [2., 4., double.nan, 10., 12.];
    auto sma = movingAverage(p, 2);
    sma.popFront();
    sma.popFront();
    assert(isNaN(sma.front));
}

mixin template SignalHandler(R)
{
    @property auto front()
    {
        auto currentPrice = prices_.front;
        return tuple!("timestamp", "price", "signal")
            (currentPrice.timestamp, currentPrice.value, currentSignal_);
    }

    static if (hasLength!R) {
        @property bool empty()
        {
            return currentIndex_ >= prices_.length;
        }
    } else static if (isInfinite!R) {
        @property enum empty = false;
    } else {
        static assert(false, "SignalHandler range can not be both finite and without length property");
    }

    static if (hasLength!R1) {
        @property auto length()
        {
            return prices_.length;
        }
    }

    auto computeSignal() pure nothrow
    {
        if (currentRegime_ == Regime.BULL && lastRegime_ != Regime.BULL) return SignalType.BUY;
        if (currentRegime_ == Regime.BEAR && lastRegime_ != Regime.BEAR) return SignalType.SELL;
        if (currentRegime_ == Regime.FLAT && lastRegime_ == Regime.BEAR) return SignalType.BUY;
        if (currentRegime_ == Regime.FLAT && lastRegime_ == Regime.BULL) return SignalType.SELL;
        
        return SignalType.NONE;
    }

    void popFront()
    {
        lastRegime_ = currentRegime_;
        currentRegime_ = computeRegime();
        currentSignal_ = computeSignal();
        currentIndex_++;
        prices_.popFront();
        indicator_.popFront();
    }
}


/**

*/
auto singleLinePosition(R1, R2)(in R1 prices, in R2 indicator) pure nothrow
if(isInputRange!R1 
    && isInputRange!R2 
    && isNumeric!(ElementType!R2) 
    && isPrice!(ElementType!R1))
{
    static struct SingleLinePosition(R1, R2)
    {
        mixin SignalHandler!R1;

        this(in R1 prices, in R2 indicator)
        {
            prices_ = prices;
            indicator_ = indicator;
            currentRegime_ = Regime.FLAT;
            lastRegime_ = Regime.FLAT;
            currentSignal_ = SignalType.NONE;
        }

        private auto computeRegime()
        {
            if(isNaN(prices_.front.value) || isNaN(indicator_.front))
                return lastRegime_;
            
            if(prices_.front.value > indicator_.front) 
                return Regime.BULL;
            
            return Regime.BEAR;
        }

        private Regime currentRegime_;
        private Regime lastRegime_;
        private R1 prices_;
        private R2 indicator_;
        private SignalType currentSignal_;
        private size_t currentIndex_;
    }
    return SingleLinePosition!(R1, R2)(prices, indicator);
}

@safe unittest
{
    import std.range: repeat;
    import std.algorithm: map;
    auto price = tuple!("timestamp", "type", "value")(0, 1, 56.6);
    auto prices = price.repeat.take(50);
    auto indicator = prices.map!"a.value + 2";
    auto system = singleLinePosition(prices, indicator);
    assert(system.front.price == prices.front.value);
    assert(system.front.signal == SignalType.NONE);
    system.popFront();
    assert(system.front.signal == SignalType.SELL);
    system.popFront();
    assert(system.front.signal == SignalType.NONE);
}

auto getSignals(R, T)(in R prices, in TradingSystem system, in T parameters) pure
if(isInputRange!R 
&& isTuple!T
&& isPrice!(ElementType!R))
{
    final switch(system) {
        case TradingSystem.SMA_ONE_LINE_POSITION:
            enforce(parameters.length == 1, 
                "SMA_ONE_LINE_POSITION depends on one parameter");
            auto depth = to!int(parameters[0]);
            auto values = prices.map!"a.value";
            auto signals = singleLinePosition(prices, values.movingAverage(depth));
            return Signals!(typeof(signals))(signals);
    }
}


private struct Signals(R)
if(isInputRange!R 
&& __traits(hasMember, ElementType!R, "timestamp")
&& __traits(hasMember, ElementType!R, "price")
&& __traits(hasMember, ElementType!R, "signal"))
{
    R signals_;

    this(in R signals)
    {
        signals_ = signals;
    }

    @property auto front()
    {
        return signals_.front;
    }

    @property bool empty()
    {
        return signals_.empty;
    }

    static if(hasLength!R) {
        @property auto length()
        {
            return signals_.length;
        }
    }

    void popFront()
    {
        signals_.popFront();
    }
}


@safe unittest
{
    import std.range: repeat;
    auto price = tuple!("timestamp", "type", "value")(0, 1, 56.6);
    auto system = price.repeat.take(50)
        .getSignals(TradingSystem.SMA_ONE_LINE_POSITION, tuple(5));
    assert(system.front.signal == SignalType.NONE);
    foreach(el; system)
    {
        assert(el.timestamp == 0);
    }
}


