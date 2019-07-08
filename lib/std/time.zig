const builtin = @import("builtin");
const std = @import("std.zig");
const assert = std.debug.assert;
const testing = std.testing;
const os = std.os;
const math = std.math;

pub const epoch = @import("time/epoch.zig");

/// Spurious wakeups are possible and no precision of timing is guaranteed.
pub fn sleep(nanoseconds: u64) void {
    if (builtin.os == .windows) {
        const ns_per_ms = ns_per_s / ms_per_s;
        const big_ms_from_ns = nanoseconds / ns_per_ms;
        const ms = math.cast(os.windows.DWORD, big_ms_from_ns) catch math.maxInt(os.windows.DWORD);
        os.windows.kernel32.Sleep(ms);
        return;
    }
    const s = nanoseconds / ns_per_s;
    const ns = nanoseconds % ns_per_s;
    std.os.nanosleep(s, ns);
}

/// Get the posix timestamp, UTC, in seconds
/// TODO audit this function. is it possible to return an error?
pub fn timestamp() u64 {
    return @divFloor(milliTimestamp(), ms_per_s);
}

/// Get the posix timestamp, UTC, in milliseconds
/// TODO audit this function. is it possible to return an error?
pub fn milliTimestamp() u64 {
    if (builtin.os == .windows) {
        //FileTime has a granularity of 100 nanoseconds
        //  and uses the NTFS/Windows epoch
        var ft: os.windows.FILETIME = undefined;
        os.windows.kernel32.GetSystemTimeAsFileTime(&ft);
        const hns_per_ms = (ns_per_s / 100) / ms_per_s;
        const epoch_adj = epoch.windows * ms_per_s;

        const ft64 = (@as(u64, ft.dwHighDateTime) << 32) | ft.dwLowDateTime;
        return @divFloor(ft64, hns_per_ms) - -epoch_adj;
    }
    if (builtin.os == .wasi and !builtin.link_libc) {
        var ns: os.wasi.timestamp_t = undefined;

        // TODO: Verify that precision is ignored
        const err = os.wasi.clock_time_get(os.wasi.CLOCK_REALTIME, 1, &ns);
        assert(err == os.wasi.ESUCCESS);

        const ns_per_ms = 1000;
        return @divFloor(ns, ns_per_ms);
    }
    if (comptime std.Target.current.isDarwin()) {
        var tv: os.darwin.timeval = undefined;
        var err = os.darwin.gettimeofday(&tv, null);
        assert(err == 0);
        const sec_ms = tv.tv_sec * ms_per_s;
        const usec_ms = @divFloor(tv.tv_usec, us_per_s / ms_per_s);
        return @intCast(u64, sec_ms + usec_ms);
    }
    var ts: os.timespec = undefined;
    //From what I can tell there's no reason clock_gettime
    //  should ever fail for us with CLOCK_REALTIME,
    //  seccomp aside.
    os.clock_gettime(os.CLOCK_REALTIME, &ts) catch unreachable;
    const sec_ms = @intCast(u64, ts.tv_sec) * ms_per_s;
    const nsec_ms = @divFloor(@intCast(u64, ts.tv_nsec), ns_per_s / ms_per_s);
    return sec_ms + nsec_ms;
}

/// Multiples of a base unit (nanoseconds)
pub const nanosecond = 1;
pub const microsecond = 1000 * nanosecond;
pub const millisecond = 1000 * microsecond;
pub const second = 1000 * millisecond;
pub const minute = 60 * second;
pub const hour = 60 * minute;

/// Divisions of a second
pub const ns_per_s = 1000000000;
pub const us_per_s = 1000000;
pub const ms_per_s = 1000;
pub const cs_per_s = 100;

/// Common time divisions
pub const s_per_min = 60;
pub const s_per_hour = s_per_min * 60;
pub const s_per_day = s_per_hour * 24;
pub const s_per_week = s_per_day * 7;

/// A monotonic high-performance timer.
/// Timer.start() must be called to initialize the struct, which captures
///   the counter frequency on windows and darwin, records the resolution,
///   and gives the user an opportunity to check for the existnece of
///   monotonic clocks without forcing them to check for error on each read.
/// .resolution is in nanoseconds on all platforms but .start_time's meaning
///   depends on the OS. On Windows and Darwin it is a hardware counter
///   value that requires calculation to convert to a meaninful unit.
pub const Timer = struct {
    ///if we used resolution's value when performing the
    ///  performance counter calc on windows/darwin, it would
    ///  be less precise
    frequency: switch (builtin.os) {
        .windows => u64,
        .macosx, .ios, .tvos, .watchos => os.darwin.mach_timebase_info_data,
        else => void,
    },
    resolution: u64,
    start_time: u64,

    const Error = error{TimerUnsupported};

    ///At some point we may change our minds on RAW, but for now we're
    ///  sticking with posix standard MONOTONIC. For more information, see:
    ///  https://github.com/ziglang/zig/pull/933
    const monotonic_clock_id = os.CLOCK_MONOTONIC;
    /// Initialize the timer structure.
    //This gives us an opportunity to grab the counter frequency in windows.
    //On Windows: QueryPerformanceCounter will succeed on anything >= XP/2000.
    //On Posix: CLOCK_MONOTONIC will only fail if the monotonic counter is not
    //  supported, or if the timespec pointer is out of bounds, which should be
    //  impossible here barring cosmic rays or other such occurrences of
    //  incredibly bad luck.
    //On Darwin: This cannot fail, as far as I am able to tell.
    pub fn start() Error!Timer {
        var self: Timer = undefined;

        if (builtin.os == .windows) {
            self.frequency = os.windows.QueryPerformanceFrequency();
            self.resolution = @divFloor(ns_per_s, self.frequency);
            self.start_time = os.windows.QueryPerformanceCounter();
        } else if (comptime std.Target.current.isDarwin()) {
            os.darwin.mach_timebase_info(&self.frequency);
            self.resolution = @divFloor(self.frequency.numer, self.frequency.denom);
            self.start_time = os.darwin.mach_absolute_time();
        } else {
            //On Linux, seccomp can do arbitrary things to our ability to call
            //  syscalls, including return any errno value it wants and
            //  inconsistently throwing errors. Since we can't account for
            //  abuses of seccomp in a reasonable way, we'll assume that if
            //  seccomp is going to block us it will at least do so consistently
            var ts: os.timespec = undefined;
            os.clock_getres(monotonic_clock_id, &ts) catch return error.TimerUnsupported;
            self.resolution = @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);

            os.clock_gettime(monotonic_clock_id, &ts) catch return error.TimerUnsupported;
            self.start_time = @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);
        }

        return self;
    }

    /// Reads the timer value since start or the last reset in nanoseconds
    pub fn read(self: *Timer) u64 {
        var clock = clockNative() - self.start_time;
        if (builtin.os == .windows) {
            return @divFloor(clock * ns_per_s, self.frequency);
        }
        if (comptime std.Target.current.isDarwin()) {
            return @divFloor(clock * self.frequency.numer, self.frequency.denom);
        }
        return clock;
    }

    /// Resets the timer value to 0/now.
    pub fn reset(self: *Timer) void {
        self.start_time = clockNative();
    }

    /// Returns the current value of the timer in nanoseconds, then resets it
    pub fn lap(self: *Timer) u64 {
        var now = clockNative();
        var lap_time = self.read();
        self.start_time = now;
        return lap_time;
    }

    fn clockNative() u64 {
        if (builtin.os == .windows) {
            return os.windows.QueryPerformanceCounter();
        }
        if (comptime std.Target.current.isDarwin()) {
            return os.darwin.mach_absolute_time();
        }
        var ts: os.timespec = undefined;
        os.clock_gettime(monotonic_clock_id, &ts) catch unreachable;
        return @intCast(u64, ts.tv_sec) * @as(u64, ns_per_s) + @intCast(u64, ts.tv_nsec);
    }
};

/// ISO 8601 compliant date representation.
pub const Date = struct {
    /// milliseconds, range 0 to 999
    millisecond: u16,

    /// seconds, range 0 to 60
    second: u8,

    /// minutes, range 0 to 59
    minute: u8,

    /// hours, range 0 to 23
    hour: u8,

    /// day of the month, range 1 to 31
    day: u8,

    /// day of the year, range 1 to 366
    year_day: u16,

    /// day of the week, enum Monday to Sunday
    week_day: Day,

    /// month, enum January to December
    month: Month,

    /// year, year 0000 is equal to 1 BCE
    year: i32,

    pub const Day = enum {
        Monday = 1,
        Tuesday = 2,
        Wednesday = 3,
        Thursday = 4,
        Friday = 5,
        Saturday = 6,
        Sunday = 7,
    };

    pub const Month = enum {
        January = 1,
        February = 2,
        March = 3,
        April = 4,
        May = 5,
        June = 6,
        July = 7,
        August = 8,
        September = 9,
        October = 10,
        November = 11,
        December = 12,
    };

    /// get current date
    pub fn now() Date {
        const time = milliTimestamp();
        return fromTimestamp(time);
    }

    /// Converts milliTimestamp to date
    pub fn fromTimestamp(time: u64) Date {
        // Ported from musl, which is licensed under the MIT license:
        // https://git.musl-libc.org/cgit/musl/tree/COPYRIGHT
        const days_in_month = [12]i8{ 31, 30, 31, 30, 31, 31, 30, 31, 30, 31, 31, 29 };
        // 2000-03-01 (mod 400 year, immediately after feb29
        const leapoch = 946684800 + 86400 * (31 + 29);
        const days_per_400y = 365 * 400 + 97;
        const days_per_100y = 365 * 100 + 24;
        const days_per_4y = 365 * 4 + 1;

        var date: Date = undefined;

        date.millisecond = @truncate(u16, time % 1000);

        var seconds = @intCast(i64, time / 1000) - leapoch;
        var days = @divTrunc(seconds, 86400);
        var rem_seconds = @truncate(i32, @rem(seconds, 86400));
        if (rem_seconds < 0) {
            rem_seconds += 86400;
            days -= 1;
        }

        var week_day = @rem((3 + days), 7);
        if (week_day < 0) {
            week_day += 7;
        }
        date.week_day = @intToEnum(Day, @intCast(u3, week_day));

        var qc_cycles = @divTrunc(days, days_per_400y);
        var rem_days = @intCast(i32, @rem(days, days_per_400y));
        if (rem_days < 0) {
            rem_days += days_per_400y;
            qc_cycles -= 1;
        }

        var c_cycles = @divTrunc(rem_days, days_per_100y);
        if (c_cycles == 4) {
            c_cycles -= 1;
        }
        rem_days -= c_cycles * days_per_100y;

        var q_cycles = @divTrunc(rem_days, days_per_4y);
        if (q_cycles == 25) {
            q_cycles -= 1;
        }
        rem_days -= q_cycles * days_per_4y;

        var rem_years = @divTrunc(rem_days, 365);
        if (rem_years == 4) {
            rem_years -= 1;
        }
        rem_days -= rem_years * 365;

        var leap: i32 = if (rem_years == 0 and (q_cycles != 0 or c_cycles == 0)) 1 else 0;
        var year_day = rem_days + 31 + 28 + leap;
        if (year_day >= 365 + leap) {
            year_day -= 365 + leap;
        }

        var years = rem_years + 4 * q_cycles + 100 * c_cycles + 400 * qc_cycles;

        var months: i32 = 0;
        while (days_in_month[@intCast(usize, months)] <= rem_days) : (months += 1) {
            rem_days -= days_in_month[@intCast(usize, months)];
        }

        if (months >= 10) {
            months -= 12;
            years += 1;
        }

        date.year = @intCast(i32, years + 2000);
        date.month = @intToEnum(Month, @intCast(u4, months + 3));
        date.day = @intCast(u8, rem_days + 1);
        date.year_day = @intCast(u16, year_day + 1);
        date.hour = @intCast(u8, @divTrunc(rem_seconds, 3600));
        date.minute = @intCast(u8, @rem(@divTrunc(rem_seconds, 60), 60));
        date.second = @intCast(u8, @rem(rem_seconds, 60));
        return date;
    }

    /// Converts date to milliTimestamp
    pub fn toTimestamp(date: Date) !u64 {
        if (date.year < 1970) {
            return error.Invalid;
        }

        const after_epoch = @intCast(u64, date.year - 1970);
        var leap_days = @divTrunc(after_epoch + 2, 4); // 1972 first leap year after 1970
        leap_days -= (after_epoch % 400) * 3; // 400 years
        leap_days -= (after_epoch % 100); // 100 years

        var time: u64 = after_epoch * 365 + leap_days;

        time += date.year_day - 1;

        time *= 24;
        time += date.hour;

        time *= 60;
        time += date.minute;

        time *= 60;
        time += @as(u64, date.second);

        time *= 1000;
        time += date.millisecond;

        return time;
    }
};

test "sleep" {
    sleep(1);
}

test "timestamp" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = 50;

    const time_0 = milliTimestamp();
    sleep(ns_per_ms);
    const time_1 = milliTimestamp();
    const interval = time_1 - time_0;
    testing.expect(interval > 0 and interval < margin);
}

test "Timer" {
    const ns_per_ms = (ns_per_s / ms_per_s);
    const margin = ns_per_ms * 150;

    var timer = try Timer.start();
    sleep(10 * ns_per_ms);
    const time_0 = timer.read();
    testing.expect(time_0 > 0 and time_0 < margin);

    const time_1 = timer.lap();
    testing.expect(time_1 >= time_0);

    timer.reset();
    testing.expect(timer.read() < time_1);
}

test "Date" {
    const date = Date.fromTimestamp(1560870105000);

    testing.expect(date.millisecond == 0);
    testing.expect(date.second == 45);
    testing.expect(date.minute == 1);
    testing.expect(date.hour == 15);
    testing.expect(date.day == 18);
    testing.expect(date.year_day == 169);
    testing.expect(date.week_day == .Tuesday);
    testing.expect(date.month == .June);
    testing.expect(date.year == 2019);

    const time = try date.toTimestamp();
    testing.expect(time == 1560870105000);
}
