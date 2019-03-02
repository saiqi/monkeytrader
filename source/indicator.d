module indicator;

import std.range: isInfinite, isInputRange, isBidirectionalRange, hasLength, ElementType, take, drop;
import std.traits: isNumeric, isFloatingPoint;
import std.algorithm: sum;

///
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

///
auto movingAverage(R)(R prices, const size_t depth) pure nothrow
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

        this(R prices, const size_t depth) pure
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

        @property bool empty()
        {
            static if (hasLength!R) {
                return prices_.length == currentIndex_;
            } else static if (isInfinite!R){
                return false;
            } else {
                static assert(false, "MovingAverage range can not be both finite and without length property");
            }
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

unittest
{
    import std.range: repeat;
    import std.math: isNaN;
    auto prices = 4.5.repeat.take(80);
    auto sma = movingAverage(prices, 5);
    assert(isNaN(sma.front), "double range first value is nan");
}

unittest
{
    import std.range: iota;
    auto prices = iota(50);
    auto sma = movingAverage(prices, 5);
    assert(sma.front == 0, "integer range first value is nan");
}

unittest
{
    import std.range: iota;
    import std.conv: to;
    import std.algorithm: map;
    import std.algorithm.comparison: equal;
    import std.array: array;

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

unittest
{
    import std.range: repeat;
    auto p = 3.4.repeat;
    auto sma = movingAverage(p, 5);
    static assert(!isInfinite!(typeof(sma)), "infinite prices give infinite sma");
}