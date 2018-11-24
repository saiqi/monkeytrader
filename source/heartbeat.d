module heartbeat;

import std.range.primitives: isInputRange;
import std.datetime: DateTime;
import std.exception: enforce;

///doc
struct NaiveCalendar(string freq)
{
private:
    DateTime current_;
    DateTime stop_;

public:
    ///doc
    this(const DateTime firstDate, const DateTime lastDate)
    {
        enforce(firstDate < lastDate,
            "firstDate is greater than lastDate");

        current_ = firstDate;
        stop_ = lastDate;
    }

    ///doc
    @property bool empty() const
    {
        return !(current_ <= stop_);
    }

    ///doc
    @property string front() const
    {
        return current_.toISOString();
    }

    ///doc
    void popFront()
    {
        current_.add!freq(1);
    }
}

static assert(isInputRange!(NaiveCalendar!"months"));

unittest
{
    import std.exception: assertThrown;

	auto calendar = NaiveCalendar!"months"(DateTime(2017, 12, 31), DateTime(2018, 1, 31));
    assert(!calendar.empty, "created calendar not empty");
    assert(calendar.front == "20171231T000000", "first value not equals excepted value");
    calendar.popFront();
    assert(calendar.front == "20180131T000000", "last value not equals excepted value");
    calendar.popFront();
    assert(calendar.empty, "calendar not empty and all values has been poped");
    assertThrown(NaiveCalendar!"months"(DateTime(2017, 12, 31), DateTime(2016, 1, 31)));
}