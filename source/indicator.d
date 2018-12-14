module indicator;

import std.range: isInfinite, isBidirectionalRange, isInputRange, ElementType, take;
import std.traits: isNumeric, isFloatingPoint;
import std.algorithm: sum;

///
mixin template MissingValue(R)
{
    static if (is(typeof(R.front.nan))) {
        enum missingValue = () => typeof(R.front).nan;
    } else {
        enum missingValue = () => 0;
    }
}

///
auto movingAverage(R)(const R prices, const size_t depth) pure nothrow
if(isInputRange!R && isNumeric!(ElementType!R))
{
    static struct MovingAverage(R)
    {
        private R prices_;
        private ElementType!R lastSumValue_;
        private size_t depth_;
        private size_t currentIndex_;

        mixin MissingValue!R;

        this(R prices, const size_t depth)
        {
            prices_ = prices;
            depth_ = depth;
        }

        @property auto rollingSum()
        {
            assert(!empty);

            if(currentIndex_ < depth_ - 1) return missingValue();

            if(currentIndex_ == depth_ - 1) return prices_.take(depth_).sum;

            static if (isBidirectionalRange!R) {
                return lastSumValue_ 
                    + prices_.take(depth_).front 
                    - prices_.take(depth_).back;
            } else {
                return prices_.take(depth_).sum;
            }
            
        }

        @property bool empty()
        {
            static if (!isInfinite!R) {
                return prices_.length == currentIndex_;
            } else {
                return false;
            }
        }

        void popFront()
        {
            assert(!empty);

            lastSumValue_ = rollingSum();
            currentIndex_++;
        }

        @property auto front()
        {
            assert(!empty);
            
            static if (isFloatingPoint!(ElementType!R)) {
                return rollingSum() / depth_;
            } else {
                return rollingSum() / depth_;
            }
        }

        auto save()
        {
            auto copy = MovingAverage!R(prices_, depth_);
            copy.currentIndex_ = currentIndex_;
            copy.lastSumValue_ = lastSumValue_;
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