import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct DocumentTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10)) ?? .now
    }

    private func inDays(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: now) ?? now
    }

    @Test func statusFollowsExpiryAndReminderWindow() {
        #expect(DocumentStatus.of(expiry: nil, remindDaysBefore: 60, now: now, calendar: calendar) == .noExpiry)
        #expect(DocumentStatus.of(expiry: inDays(-1), remindDaysBefore: 60, now: now, calendar: calendar) == .expired)
        #expect(DocumentStatus.of(expiry: inDays(45), remindDaysBefore: 60, now: now, calendar: calendar) == .expiringSoon)
        #expect(DocumentStatus.of(expiry: inDays(45), remindDaysBefore: 30, now: now, calendar: calendar) == .valid)
        #expect(DocumentStatus.expired < DocumentStatus.expiringSoon)
    }

    @Test func describesExpiry() {
        #expect(DocumentStatus.describe(expiry: inDays(0), now: now, calendar: calendar) == "Expira hoje")
        #expect(DocumentStatus.describe(expiry: inDays(12), now: now, calendar: calendar) == "Expira em 12 dias")
        #expect(DocumentStatus.describe(expiry: inDays(-3), now: now, calendar: calendar) == "Expirou há 3 dias")
        #expect(DocumentStatus.describe(expiry: inDays(400), now: now, calendar: calendar).hasPrefix("Válido até"))
    }

    @Test func masksAllButTheLastCharacters() {
        #expect(DocumentNumber.masked("Y1234567Z") == "•••• 67Z")
        #expect(DocumentNumber.masked("AB") == "••••")
        #expect(DocumentNumber.masked("  ") == "")
    }

    @Test func agendaUsesTheChosenReminder() throws {
        let residence = PersonalDocument(kind: .residence, title: "TIE", expiryDate: inDays(50))
        residence.remindDaysBefore = 90
        let undated = PersonalDocument(kind: .healthCard)
        let items = LifeAgenda.documentItems([residence, undated])

        let item = try #require(items.first)
        #expect(items.count == 1)
        #expect(item.title == "TIE")
        #expect(item.dueWord == "Expira")
        #expect(item.isVisible(from: now, calendar: calendar))
        #expect(item.describe(from: now, calendar: calendar) == "Expira em 50 dias")

        let reminders = AgendaReminderPlanner(calendar: calendar).reminders(for: items, now: now)
        // O aviso de 90 dias já passou: ficam 7 dias antes e o próprio dia.
        #expect(reminders.map(\.title) == ["TIE: expira em 7 dias", "TIE: expira hoje"])
    }

    @Test func deletingDocumentDeletesPhotos() throws {
        let container = try ModelContainerFactory.make(inMemory: true)
        let context = container.mainContext
        let passport = PersonalDocument(kind: .passport, number: "FX123456")
        context.insert(passport)
        let photo = DocumentPhoto(imageData: Data([0xFF, 0xD8]))
        context.insert(photo)
        photo.document = passport
        try context.save()
        #expect(passport.sortedPhotos.count == 1)

        context.delete(passport)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<DocumentPhoto>()) == 0)
    }
}
