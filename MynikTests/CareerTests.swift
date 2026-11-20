import Foundation
import SwiftData
import Testing
@testable import Mynik

@MainActor
struct CareerTests {
    private let calendar = Calendar(identifier: .gregorian)
    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 20, hour: 10)) ?? .now
    }

    private func inDays(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: now) ?? now
    }

    @Test func statsCountActiveInterviewsAndResponses() {
        let stats = CareerStats(statuses: [.applied, .applied, .interviewing, .offer, .rejected, .noResponse, .accepted, .applied])
        #expect(stats.total == 8)
        #expect(stats.active == 5)
        #expect(stats.interviews == 1)
        #expect(stats.offers == 2)
        // Entrevista, proposta, recusa e aceite contam como resposta.
        #expect(stats.responded == 4)
        #expect(stats.responseRate == 0.5)
        #expect(CareerStats(statuses: []).responseRate == nil)
    }

    @Test func closingAnApplicationClearsTheFollowUp() {
        let application = JobApplication(company: "Glovo", role: "iOS", followUpDate: inDays(3))
        application.status = .interviewing
        #expect(application.followUpDate != nil)
        application.status = .rejected
        #expect(application.followUpDate == nil)
        #expect(application.status == .rejected)
    }

    @Test func linksWithoutSchemeOpenAsHTTPS() {
        let application = JobApplication(company: "Cabify", role: "Mobile")
        application.link = "jobs.cabify.com/123"
        #expect(application.url?.absoluteString == "https://jobs.cabify.com/123")
        application.link = "  "
        #expect(application.url == nil)
    }

    @Test func completingACourseSetsProgress() {
        let course = Course(title: "Swift", status: .inProgress)
        course.progress = 0.4
        course.status = .completed
        #expect(course.progress == 1)
        #expect(course.completedAt != nil)
        course.status = .inProgress
        #expect(course.completedAt == nil)
    }

    @Test func agendaShowsDueFollowUpsAndExpiringCertificates() throws {
        let due = JobApplication(company: "Glovo", role: "iOS Developer", followUpDate: inDays(1))
        let later = JobApplication(company: "Cabify", role: "Mobile", followUpDate: inDays(10))
        let closed = JobApplication(company: "Idealista", role: "Swift", status: .rejected)
        let certificate = Course(title: "AWS Cloud Practitioner", provider: "AWS", status: .completed)
        certificate.expiresAt = inDays(45)

        let items = LifeAgenda.careerItems([due, later, closed], courses: [certificate])
        #expect(items.count == 3)
        let visible = items.upcoming(from: now, calendar: calendar)
        #expect(visible.map(\.title) == ["Follow-up: Glovo", "AWS Cloud Practitioner"])
        let followUp = try #require(visible.first)
        #expect(followUp.describe(from: now, calendar: calendar) == "Contactar amanhã")
        #expect(followUp.detail == "iOS Developer")
    }
}
