module heartbeat;

import std.range.primitives: isInputRange;
import std.datetime: DateTime, Date;
import core.time: days, hours, minutes, seconds;
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
    assert(!calendar.empty, "created calendar not empty");
    assert(calendar.front == "20171231T000000", "first value not equals excepted value");
    calendar.popFront();
    assert(calendar.front == "20180131T000000", "last value not equals excepted value");
    calendar.popFront();
    assert(calendar.empty, "calendar not empty and all values has been popped");
    assertThrown(NaiveCalendar!(DateTime, "months")(DateTime(2017, 12, 31), DateTime(2016, 1, 31)));

    auto prebuiltDailyCalendar = naiveDailyCalendar(Date(2017, 12, 31), Date(2018, 1, 31));
    prebuiltDailyCalendar.popFront();
    assert(prebuiltDailyCalendar.front == "20180101",
        "a Date type calendar front method returns YYYYMMDD string");

    auto prebuiltIntradayCalendar = naiveIntradayCalendar(DateTime(2017, 12, 31), DateTime(2018, 1, 31));
    prebuiltIntradayCalendar.popFront();
    assert(prebuiltIntradayCalendar.front == "20171231T000100",
        "a DateTime calendar front method returns YYYYMMDDTHHMMSS string");
}