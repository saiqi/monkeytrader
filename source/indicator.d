module indicator;

import std.range: isInfinite, isInputRange, isBidirectionalRange, hasLength, ElementType, take, drop;
import std.traits: isNumeric, isFloatingPoint, ReturnType;
import std.algorithm: sum, map;
import std.array;
import std.typecons: tuple, isTuple;
import std.exception: enforce;
import std.conv: to;
import std.math: isNaN, sqrt;
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
Account percentage to normalise 
*/
enum RISK_UNITS_K = 0.0001;

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
    momentType = the type of the moment. 1 = mean, 2 = variance
    prices = a range which contains numeric elements.
    depth = the depth of the moving average
Returns:
    a ForwardRange
Example:
---
auto sma = movingMoment([1., 2., 3.], 2); // sma contains [double.nan, 1.5, 2.5]
---
*/
auto movingMoment(R, uint momentType = 1)(R prices, in size_t depth) pure nothrow
if(isInputRange!R && isNumeric!(ElementType!R) && (momentType == 1 || momentType == 2))
{
    static struct MovingMoment(R, uint momentType)
    {
        private R prices_;
        private ElementType!R lastSumValue_;
        private ElementType!R currentSumValue_;
        private size_t depth_;
        private size_t currentIndex_;

        static if (momentType == 2) {
            private ElementType!R currentSumSquaredValue_;
            private ElementType!R lastSumSquaredValue_;
        }

        mixin MissingValue!R;

        static if(!isBidirectionalRange!R) pragma(msg, 
            "WARNING !! calculation complexity should be high on non BidirectionalRange");

        this(R prices, in size_t depth) pure
        {
            prices_ = prices;
            depth_ = depth;
            currentIndex_ = 0;
            currentSumValue_ = missingValue();
            static if (momentType == 2) {
                currentSumSquaredValue_ = missingValue();
            }
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
                return prices_.drop(currentIndex_ - depth_ + 1).take(depth_).sum;
            }
        }

        static if (momentType == 2) {
            @property auto rollingSumSquared()
            {
                if(currentIndex_ < depth_ - 1) return missingValue();

                if(currentIndex_ == depth_ - 1) return prices_.take(depth_).map!"a*a".sum;

                static if (isBidirectionalRange!R) {
                    auto sample = prices_.drop(currentIndex_ - depth_).take(depth_ + 1);
                    return lastSumSquaredValue_
                        + sample.back*sample.back 
                        - sample.front*sample.front;
                } else {
                    return prices_.drop(currentIndex_ - depth_ + 1).take(depth_).map!"a*a".sum;
                }
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
            static assert(false, "MovingMoment range can not be both finite and without length property");
        }

        void popFront()
        {
            assert(!empty);

            lastSumValue_ = currentSumValue_;
            static if(momentType == 2)
                lastSumSquaredValue_ = currentSumSquaredValue_;
            currentIndex_++;
            currentSumValue_ = rollingSum();
            static if(momentType == 2)
                currentSumSquaredValue_ = rollingSumSquared();
        }

        @property auto front()
        {
            assert(!empty);
            static if (momentType == 1) {
                return currentSumValue_ / depth_;
            } else {
                return (currentSumSquaredValue_ - currentSumValue_*currentSumValue_/depth_) / (depth_ - 1.); 
            }
        }

        auto save()
        {
            auto copy = MovingMoment!(R, momentType)(prices_, depth_);
            copy.currentIndex_ = currentIndex_;
            copy.lastSumValue_ = lastSumValue_;
            copy.currentSumValue_ = currentSumValue_;
            static if(momentType == 2) {
                copy.lastSumSquaredValue_ = lastSumSquaredValue_;
                copy.currentSumSquaredValue_ = lastSumSquaredValue_;
            }
            return copy;
        }

    }

    return MovingMoment!(R, momentType)(prices, depth);
}

alias movingAverage(R) = movingMoment!(R, 1);
alias movingVariance(R) = movingMoment!(R, 2);

@safe unittest
{
    auto v = [3.0, 3.0, 3.0, 3.0];
    auto sma = movingAverage!(double[])(v, 2);
    sma.popFront();
    assert(sma.front == 3.0);
}

@safe unittest
{
    auto values = [1., 2., 3., 4., 5.];
    auto sma = movingMoment!(double[], 1)(values, 2);
    sma.popFront();
    assert(sma.front == 1.5);
}

@safe unittest
{
    import std.range: iota;
    import std.algorithm: equal;
    auto values = iota(10).array;
    auto smv = movingMoment!(int[], 2)(values, 5);
    assert(equal(smv, [0, 0, 0, 0, 2.5, 2.5, 2.5, 2.5, 2.5, 2.5]));
}

@safe unittest
{
    import std.range: repeat;
    auto prices = 4.5.repeat.take(80);
    auto sma = movingMoment(prices, 5);
    assert(isNaN(sma.front), "double range first value is nan");
}

@safe unittest
{
    import std.range: iota;
    auto prices = iota(50);
    auto sma = movingMoment(prices, 5);
    assert(sma.front == 0, "integer range first value is nan");
}

@safe unittest
{
    import std.range: iota;
    import std.conv: to;
    import std.algorithm: map;
    import std.algorithm.comparison: equal;

    auto prices = iota(5).map!((a) => to!double(a%2) + to!double(a%3));

    auto sma = movingMoment(prices, 3).array;

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
    auto sma = movingMoment(p, 5);
    static assert(isInfinite!(typeof(sma)), "infinite prices give infinite sma");
}

@safe unittest
{
    auto p = [2., 4., double.nan, 10., 12.];
    auto sma = movingMoment(p, 2);
    sma.popFront();
    sma.popFront();
    assert(isNaN(sma.front));
}

@safe unittest 
{
    struct DummyRange {

        @property double front()
        {
            return last;
        }

        enum empty = false;
        
        void popFront()
        {
            last += 1.0;
        }

        private double last = 0;
    }
    
    import std.range: enumerate;
    auto r = DummyRange();
    const size_t depth = 7;
    auto sma = movingAverage!DummyRange(r, depth);

    double avg = 0.;
    foreach(i, el; sma.take(depth + 5).enumerate)
    {
        if(i == depth - 1)
        {
            avg = .5*i*(i+1) / depth;
        } else if (i > depth - 1) {
            avg++;
        }
        assert(!isNaN(el) ? avg == el : isNaN(el));
    }
}

@safe unittest 
{
    import std.range: repeat;
    auto el = tuple(0, 45.0);
    auto prices = el.repeat(50).map!"a[1]";
    auto v = prices.movingAverage!(typeof(prices))(20);
    assert(isInputRange!(typeof(v)));
    v.popFront();
}

mixin template SignalHandler(R)
{
    @property auto front()
    {
        auto currentPrice = prices_.front;
        static if(__traits(hasMember, ElementType!R, "yield"))
            return tuple!("timestamp", "price", "yield", "signal")
                (currentPrice.timestamp, currentPrice.value, currentPrice.yield, currentSignal_);
        else
            return tuple!("timestamp", "price", "signal")
                (currentPrice.timestamp, currentPrice.value, currentSignal_);
    }

    @property bool empty()
    {
        return prices_.empty;
    }

    static if (hasLength!R) {
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
        prices_.popFront();
        indicator_.popFront();
    }
}

/**

*/
auto singleLinePosition(R1, R2)(inout(R1) prices, R2 indicator) pure nothrow
if(isInputRange!R1 
    && isInputRange!R2 
    && isNumeric!(ElementType!R2) 
    && isPrice!(ElementType!R1))
{
    static struct SingleLinePosition(R1, R2)
    {
        mixin SignalHandler!R1;

        this(inout(R1) prices, R2 indicator)
        {
            prices_ = cast(R1) prices;
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

auto getSignals(R, T)(R prices, in TradingSystem system, in T parameters) pure
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
            auto signals = singleLinePosition(prices, values.movingMoment(depth));
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

    this(inout(R) signals)
    {
        signals_ = cast(R)signals;
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

@safe unittest
{
    import heartbeat: naiveDailyCalendar;
    import price: getGaussianPrices;
    import std.datetime: Date;
    import std.algorithm: map;
    auto system = naiveDailyCalendar(Date(2019, 4, 1), Date(2019, 4, 7), "Europe/London")
        .getGaussianPrices(0., 0.0025, 100.)
        .getSignals(TradingSystem.SMA_ONE_LINE_POSITION, tuple(22))
        .map!"a.signal";
    assert(system.length == 7);
}

auto getReturns(R)(R prices) pure nothrow
if(isInputRange!R 
&& isNumeric!(ElementType!R))
{
    static struct Returns(R)
    {
        mixin MissingValue!R;

        this(R prices)
        {
            prices_ = prices;
        }

        @property auto front()
        {
            assert(!empty);
            if (currentIndex_ == 0) return missingValue();
            return currentValue_;        
        }

        @property bool empty()
        {
            return prices_.empty;
        }

        static if (hasLength!R) {
            @property auto length()
            {
                return prices_.length;
            }
        }

        void popFront()
        {
            assert(!empty);
            static if (isBidirectionalRange!R) {
                auto sample = prices_.take(2);
            } else {
                auto sample = prices_.take(2).array;
            }
            
            currentValue_ = to!double(sample.back) / to!double(sample.front) - 1;
            prices_.popFront();
            currentIndex_++;
        }

        private R prices_;
        private double currentValue_;
        private size_t currentIndex_;
    }
    return Returns!R(prices);
}

@safe unittest
{
    import std.math: approxEqual;
    auto r = getReturns([100.0, 110.0, 114.9, 105.6, 99.8]);
    assert(isNaN(r.front), "first is nan");
    r.popFront();
    assert(approxEqual(r.front, .1), "second");
}

@safe unittest
{
    import std.range: enumerate;
    import std.math: approxEqual;
    auto r = getReturns([1., 2., 3., 4., 5.]);

    foreach(i, el; r.enumerate)
    {
        if(i == 0) {
            assert(isNaN(el));
        } else {
            const auto v = cast(double)i;
            assert(approxEqual(el, (v+1)/v-1));
        }
    }
}

@safe unittest
{
    struct DummyRange
    {
        @property auto front()
        {
            return value_;
        }

        enum bool empty = false;

        void popFront()
        {
            value_++;
        }

        private double value_ = 0.;
    }

    auto r = getReturns(DummyRange());
    r.popFront();
}

/**

*/
auto getNominalToTrade(R1)(R1 signals, in size_t volatilityDepth = 252) pure
if (
    isInputRange!R1
    && isTuple!(ElementType!R1)
    && __traits(hasMember, ElementType!R1, "timestamp")
    && __traits(hasMember, ElementType!R1, "yield")
    && __traits(hasMember, ElementType!R1, "signal")
)
{
    static struct NominalToTrade(R1, R2)
    {
        this(R1 signals, R2 rollingVariance)
        {
            signals_ = signals;
            currentNominal_ = 0.;
            lastNominal_ = 0.;
            rollingVariance_ = rollingVariance;
        }

        @property auto front()
        {
            assert(!empty);
            return currentNominal_;
        }

        @property bool empty()
        {
            return signals_.empty;
        }

        static if (hasLength!R1)
        {
            @property size_t length()
            {
                return signals_.length;
            }
        }

        private auto computeCurrentNominal() 
        {
            final switch(signals_.front.signal) {
                case SignalType.SELL:
                    return -RISK_UNITS_K / sqrt(rollingVariance_.front);
                case SignalType.BUY:
                    return RISK_UNITS_K / sqrt(rollingVariance_.front);
                case SignalType.ROLL:
                    return lastNominal_;
                case SignalType.NONE:
                    return 0.;
            }
        }

        void popFront()
        {
            assert(!empty);
            currentNominal_ = isNaN(computeCurrentNominal()) ? 0. : computeCurrentNominal();
            lastNominal_ = currentNominal_ == 0. ? lastNominal_ : currentNominal_;
            rollingVariance_.popFront();
            signals_.popFront();
        }
        
        private double currentNominal_;
        private double lastNominal_;
        private R1 signals_;
        private R2 rollingVariance_;
    }
    auto returns = signals.map!"a.yield";
    auto rollingVariance = returns.movingVariance!(typeof(returns))(volatilityDepth);
    return NominalToTrade!(R1, typeof(rollingVariance))(signals, rollingVariance);
}

@safe unittest
{
    import std.range: repeat, enumerate;
    auto v = tuple!("timestamp", "price", "yield", "signal")(0, 100., -0.1, SignalType.SELL);
    auto n = v.repeat(40).getNominalToTrade(21);
    foreach(i, el; n.enumerate)
    {
        if (i < 21) assert(el == 0.);
        else assert(el < 0.);
    }
}

@safe unittest
{
    import heartbeat: naiveDailyCalendar;
    import price: getGaussianPrices;
    import std.datetime: Date;
    auto strategy = naiveDailyCalendar(Date(2019, 4, 1), Date(2019, 4, 30), "Europe/London")
        .getGaussianPrices(0., 0.0025, 100.)
        .getSignals(TradingSystem.SMA_ONE_LINE_POSITION, tuple(5));
    alias R1 = typeof(strategy);
    static assert (
        isInputRange!R1
        && isTuple!(ElementType!R1)
        && __traits(hasMember, ElementType!R1, "timestamp")
        && __traits(hasMember, ElementType!R1, "yield")
        && __traits(hasMember, ElementType!R1, "signal")
    );
    auto nominal = strategy.getNominalToTrade(10);
    nominal.popFront();
}

@safe unittest
{
    import std.range: repeat, enumerate;
    auto v = tuple!("timestamp", "price", "yield", "signal")(0, 100., -0.1, SignalType.SELL);
    auto n = v.repeat(40).array.getNominalToTrade(21);
    foreach(i, el; n.enumerate)
    {
        if (i < 21) assert(el == 0.);
        else assert(el < 0.);
    }
}