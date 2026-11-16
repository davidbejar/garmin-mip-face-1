import Toybox.Lang;

//! Calendar helpers. Names are fixed English upper case, as in the mockups.
module DateUtil {

    //! Indexed by Gregorian.Info.day_of_week - 1 (1 = Sunday).
    const DAY_NAMES = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"] as Array<String>;

    //! Indexed by month - 1.
    const MONTH_NAMES = [
        "JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE",
        "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"
    ] as Array<String>;

    //! Days before the first of each month in a non-leap year.
    const DAYS_BEFORE_MONTH = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334] as Array<Number>;

    //! Converts Gregorian day_of_week (1 = Sunday ... 7 = Saturday) to ISO (1 = Monday ... 7 = Sunday).
    function isoDayOfWeek(gregorianDow as Number) as Number {
        return ((gregorianDow + 5) % 7) + 1;
    }

    //! ISO 8601 week number (1-53).
    function isoWeek(year as Number, month as Number, day as Number, isoDow as Number) as Number {
        var week = (dayOfYear(year, month, day) - isoDow + 10) / 7;
        if (week < 1) {
            return weeksInYear(year - 1);
        }
        if (week > weeksInYear(year)) {
            return 1;
        }
        return week;
    }

    function isLeapYear(year as Number) as Boolean {
        return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    }

    function dayOfYear(year as Number, month as Number, day as Number) as Number {
        var n = DAYS_BEFORE_MONTH[month - 1] + day;
        if (month > 2 && isLeapYear(year)) {
            n += 1;
        }
        return n;
    }

    //! A year has 53 ISO weeks when it ends on a Thursday, or the year before ends on a Wednesday.
    function weeksInYear(year as Number) as Number {
        return (yearEndWeekday(year) == 4 || yearEndWeekday(year - 1) == 3) ? 53 : 52;
    }

    //! Weekday of 31 December (0 = Sunday ... 6 = Saturday).
    function yearEndWeekday(year as Number) as Number {
        return (year + year / 4 - year / 100 + year / 400) % 7;
    }
}
