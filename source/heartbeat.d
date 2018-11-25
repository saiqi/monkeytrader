module heartbeat;

import std.range.primitives: isInputRange;
import std.datetime: DateTime, Date;
import std.exception: enforce;

///doc
enum bool isCalendarElement(T) = is(typeof(T.init) == Date)
    || is(typeof(T.init) == DateTime);

unittest
{
    static assert(isCalendarElement!Date);
}

///doc
struct NaiveCalendar(T, string freq)
if (isCalendarElement!T)
{
private:
    T current_;
    T stop_;

public:
    ///doc
    this(const T firstDate, const T lastDate)
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

static assert(isInputRange!(NaiveCalendar!(Date, "months")));

unittest
{
    import std.exception: assertThrown;

	auto calendar = NaiveCalendar!(DateTime, "months")(DateTime(2017, 12, 31), DateTime(2018, 1, 31));
    assert(!calendar.empty, "created calendar not empty");
    assert(calendar.front == "20171231T000000", "first value not equals excepted value");
    calendar.popFront();
    assert(calendar.front == "20180131T000000", "last value not equals excepted value");
    calendar.popFront();
    assert(calendar.empty, "calendar not empty and all values has been popped");
    assertThrown(NaiveCalendar!(DateTime, "months")(DateTime(2017, 12, 31), DateTime(2016, 1, 31)));
}