import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct NoteMentionTests {
    @Test func detectsQueryOnlyAfterSpaceOrStart() {
        #expect(NoteMention.activeQuery(in: "@") == "")
        #expect(NoteMention.activeQuery(in: "Falar com @Ana") == "Ana")
        #expect(NoteMention.activeQuery(in: "email@exemplo") == nil)
        #expect(NoteMention.activeQuery(in: "@Ana já") == nil)
    }

    @Test func insertsTokenAndParsesItBack() throws {
        let token = NoteMention.token(label: "Plano [v2]", target: .note("abc"))
        #expect(token == "[@Plano (v2)](mynik://note/abc)")
        let text = NoteMention.replacingActiveQuery(in: "Ver @pla", with: token)
        #expect(text == "Ver [@Plano (v2)](mynik://note/abc) ")
        #expect(NoteMention.targets(in: text + "[@x](mynik://date/2026-11-21)") == [.note("abc"), .date("2026-11-21")])

        let rendered = NoteMarkdown.attributed(text)
        let link = try #require(rendered.runs.compactMap(\.link).first)
        #expect(NoteMention.target(from: link) == .note("abc"))
        #expect(NoteMention.target(from: try #require(URL(string: "mynik://mention/Casa%20Nova"))) == .title("Casa Nova"))
        #expect(NoteMention.target(from: try #require(URL(string: "https://exemplo.pt"))) == nil)
    }

    @Test func suggestsRelativeAndTypedDates() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Madrid")!
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 11, day: 21, hour: 10)))
        #expect(NoteMention.dateSuggestions(for: "", now: now, calendar: calendar).map(\.day)
                == ["2026-11-21", "2026-11-22", "2026-11-20"])
        #expect(NoteMention.dateSuggestions(for: "aman", now: now, calendar: calendar).map(\.label) == ["Amanhã"])
        #expect(NoteMention.dateSuggestions(for: "25/12", now: now, calendar: calendar).map(\.day) == ["2026-12-25"])
        #expect(NoteMention.dateSuggestions(for: "1/2/27", now: now, calendar: calendar).map(\.day) == ["2027-02-01"])
        #expect(NoteMention.dateSuggestions(for: "40/2", now: now, calendar: calendar).isEmpty)
    }

    @Test func findsBacklinksByIdAndTitle() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let target = NoteEditing.makeNote(title: "Viagem", in: context)
        let byID = NoteEditing.makeNote(title: "Diário", in: context)
        byID.sortedBlocks.first?.text = "Ler [@Viagem](mynik://note/\(target.uid))"
        let byTitle = NoteEditing.makeNote(title: "Ideias", in: context)
        byTitle.sortedBlocks.first?.text = "Ver [[viagem]]"
        let unrelated = NoteEditing.makeNote(title: "Outra", in: context)

        let backlinks = NoteMention.backlinks(to: target, among: [target, byID, byTitle, unrelated])
        #expect(Set(backlinks.map(\.title)) == ["Diário", "Ideias"])
    }
}
