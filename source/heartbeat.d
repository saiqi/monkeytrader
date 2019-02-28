module heartbeat;

import std.range.primitives: isInputRange;
import std.datetime: DateTime, Date;
import core.time: days, hours, minutes, seconds;
import std.exception: enforce;

///
enum bool isCalendarElement(T) = is(typeof(T.init) == Date)
    || is(typeof(T.init) == DateTime);

unittest
{
    static assert(isCalendarElement!Date);
}

///
struct NaiveCalendar(T, string freq)
if (isCalendarElement!T)
{
    private T current_;
    private T stop_;

    ///
    this(const T firstDate, const T lastDate)
    {
        enforce(firstDate < lastDate,
            "firstDate is greater than lastDate");

        current_ = firstDate;
        stop_ = lastDate;
    }

    ///
    @property bool empty() const
    {
        return !(current_ <= stop_);
    }

    ///
    @property string front() const
    {
        return current_.toISOString();
    }

    ///
    @property size_t length() const
    {
        if(empty) return 0;

        static if (freq == "months") {
            return 12*(stop_.year - current_.year) + stop_.month - current_.month + 1;
        } else static if (freq == "years") {
            return stop_.year - current_.year + 1;
        } else {
            return (stop_ - current_).total!freq;
        }
    }

    ///
    void popFront()
    {
        static if (freq == "years" || freq == "months") {
            current_.add!freq(1);
        } else static if (freq == "days") {
            current_ += days(1);
        } else static if (freq == "hours" && is(typeof(T.init) == DateTime)) {
            current_ += hours(1);
        } else static if (freq == "minutes" && is(typeof(T.init) == DateTime)) {
            current_ += minutes(1);
        } else static if (freq == "seconds" && is(typeof(T.init) == DateTime)) {
            current_ += seconds(1);
        } else {
            static assert(false, freq ~ " is not supported associated with " ~ T.stringof);
        }
    }
}

static assert(isInputRange!(NaiveCalendar!(Date, "months")));

alias naiveDailyCalendar = NaiveCalendar!(Date, "days");
alias naiveMonthlyCalendar = NaiveCalendar!(Date, "months");
alias naiveIntradayCalendar = NaiveCalendar!(DateTime, "minutes");

unittest
{
    import std.exception: assertThrown;

	auto calendar = NaiveCalendar!(DateTime, "months")(DateTime(2017, 12, 31), DateTime(2018, 1, 31));
    assert(calendar.length == 2, "length equals 2");
    assert(!calendar.empty, "created calendar not empty");
    assert(calendar.front == "20171231T000000", "first value not equals excepted value");
    calendar.popFront();
    assert(calendar.length == 1, "length equals 1");
    assert(calendar.front == "20180131T000000", "last value not equals excepted value");
    calendar.popFront();
    assert(calendar.empty, "calendar empty and all values has been popped");
    assert(calendar.length == 0, "length equals 0");
    assertThrown(NaiveCalendar!(DateTime, "months")(DateTime(2017, 12, 31), DateTime(2016, 1, 31)));

    auto prebuiltDailyCalendar = naiveDailyCalendar(Date(2017, 12, 31), Date(2018, 1, 31));
    assert(!prebuiltDailyCalendar.empty, "calendar not empty");
    assert(prebuiltDailyCalendar.length == 31, "length checked");
    prebuiltDailyCalendar.popFront();
    assert(prebuiltDailyCalendar.front == "20180101",
        "a Date type calendar front method returns YYYYMMDD string");

    auto prebuiltIntradayCalendar = naiveIntradayCalendar(DateTime(2017, 12, 31), DateTime(2018, 1, 31));
    prebuiltIntradayCalendar.popFront();
    assert(prebuiltIntradayCalendar.front == "20171231T000100",
        "a DateTime calendar front method returns YYYYMMDDTHHMMSS string");
}