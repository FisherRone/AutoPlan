import Testing
import Foundation
import AutoPlan

struct RelativeDateParserTests {

    // 2026-05-23 是周六 (weekday=7)
    // 周一起始 (firstWeekday=2): 本周 = 5/18(一) ~ 5/24(日)
    // 周日起始 (firstWeekday=1): 本周 = 5/17(日) ~ 5/23(六)

    private func parse(_ string: String, firstWeekday: Int = 2) -> Date? {
        RelativeDateParser.parse(string, firstWeekday: firstWeekday)
    }

    private func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    // MARK: - +Nweek 带时间

    @Test func plusOneWeekSunday() {
        let result = parse("2026-05-23 +1week sunday 12:00")
        #expect(format(result!) == "2026-05-31 12:00")
    }

    @Test func plusTwoWeekMonday() {
        let result = parse("2026-05-23 +2week monday 08:00")
        #expect(format(result!) == "2026-06-01 08:00")
    }

    @Test func plusOneWeekFriday() {
        let result = parse("2026-05-23 +1week friday 14:30")
        #expect(format(result!) == "2026-05-29 14:30")
    }

    // MARK: - -Nweek 带时间

    @Test func minusOneWeekFriday() {
        let result = parse("2026-05-23 -1week friday 10:00")
        #expect(format(result!) == "2026-05-15 10:00")
    }

    @Test func minusTwoWeekTuesday() {
        let result = parse("2026-05-23 -2week tuesday")
        #expect(format(result!) == "2026-05-05 00:00")
    }

    // MARK: - +0week

    @Test func plusZeroWeekSaturday() {
        let result = parse("2026-05-23 +0week saturday")
        #expect(format(result!) == "2026-05-23 00:00")
    }

    @Test func plusZeroWeekMonday() {
        let result = parse("2026-05-23 +0week monday 9:00")
        #expect(format(result!) == "2026-05-18 09:00")
    }

    // MARK: - 省略周偏移（= 本周）

    @Test func noWeekOffsetWednesday() {
        let result = parse("2026-05-23 wednesday")
        #expect(format(result!) == "2026-05-20 00:00")
    }

    @Test func noWeekOffsetFriday() {
        let result = parse("2026-05-23 friday")
        #expect(format(result!) == "2026-05-22 00:00")
    }

    @Test func noWeekOffsetMonday() {
        let result = parse("2026-05-23 monday")
        #expect(format(result!) == "2026-05-18 00:00")
    }

    // MARK: - 数字和 week 之间有空格

    @Test func spaceBetweenNumberAndWeek() {
        let result = parse("2026-05-23 +1 week sunday 12:00")
        #expect(format(result!) == "2026-05-31 12:00")
    }

    @Test func zeroWeekWithSpace() {
        let result = parse("2026-05-23 +0 week monday 9:00")
        #expect(format(result!) == "2026-05-18 09:00")
    }

    // MARK: - 星期缩写

    @Test func abbreviatedWeekday() {
        let result = parse("2026-05-23 +1week sun 12:00")
        #expect(format(result!) == "2026-05-31 12:00")
    }

    // MARK: - 周日起始 (firstWeekday=1)
    // 周日起始: 5/23(六)所在周 = 5/17(日) ~ 5/23(六)
    // +1week = 5/24(日) ~ 5/30(六)

    @Test func sundayStartPlusOneWeekSunday() {
        let result = parse("2026-05-23 +1week sunday 12:00", firstWeekday: 1)
        #expect(format(result!) == "2026-05-24 12:00")
    }

    @Test func sundayStartNoOffsetFriday() {
        let result = parse("2026-05-23 friday", firstWeekday: 1)
        #expect(format(result!) == "2026-05-22 00:00")
    }

    // MARK: - 不匹配时回退到标准格式

    @Test func fallbackToStandardFormat() {
        let result = Date.parse("2026-05-25 09:00")
        #expect(format(result!) == "2026-05-25 09:00")
    }

    @Test func fallbackToDateOnly() {
        let result = Date.parse("2026-05-25")
        #expect(format(result!) == "2026-05-25 00:00")
    }

    // MARK: - 无效输入

    @Test func invalidStringReturnsNil() {
        #expect(Date.parse("") == nil)
        #expect(Date.parse(nil) == nil)
    }

    @Test func invalidWeekdayReturnsNil() {
        #expect(parse("2026-05-23 +1week funday 12:00") == nil)
    }
}
