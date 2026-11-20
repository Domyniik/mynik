import Foundation
import SwiftData

/// Junta os prazos dos módulos de vida (carro, documentos, carreira).
enum LifeAgenda {
    /// Todos os itens com data, de todos os módulos.
    static func allItems(in context: ModelContext, now: Date = .now) -> [AgendaItem] {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        let documents = (try? context.fetch(FetchDescriptor<PersonalDocument>())) ?? []
        let applications = (try? context.fetch(FetchDescriptor<JobApplication>())) ?? []
        let courses = (try? context.fetch(FetchDescriptor<Course>())) ?? []
        return carItems(vehicles, now: now) + documentItems(documents) + careerItems(applications, courses: courses)
    }

    /// Follow-ups das candidaturas ativas e certificados a expirar.
    static func careerItems(_ applications: [JobApplication], courses: [Course]) -> [AgendaItem] {
        let followUps = applications.compactMap { application -> AgendaItem? in
            guard application.status.isActive, let date = application.followUpDate else { return nil }
            return AgendaItem(
                id: "career-followup-\(application.uid)",
                title: "Follow-up: \(application.company)",
                detail: application.role,
                date: date,
                symbolName: "briefcase",
                source: .career,
                dueWord: "Contactar",
                horizonDays: 2,
                remindDaysBefore: [0]
            )
        }
        let certificates = courses.compactMap { course -> AgendaItem? in
            guard let expiry = course.expiresAt else { return nil }
            return AgendaItem(
                id: "career-certificate-\(course.uid)",
                title: course.title,
                detail: course.provider.isEmpty ? "Certificado" : "Certificado · \(course.provider)",
                date: expiry,
                symbolName: "graduationcap",
                source: .career,
                dueWord: "Expira",
                horizonDays: 60,
                remindDaysBefore: [60, 7, 0]
            )
        }
        return followUps + certificates
    }

    /// Documentos com validade: aparecem na tela Hoje a partir do aviso escolhido.
    static func documentItems(_ documents: [PersonalDocument]) -> [AgendaItem] {
        documents.compactMap { document in
            guard let expiry = document.expiryDate else { return nil }
            return AgendaItem(
                id: "document-\(document.uid)",
                title: document.displayTitle,
                detail: document.kind.title,
                date: expiry,
                symbolName: document.kind.symbolName,
                source: .document,
                dueWord: "Expira",
                horizonDays: document.remindDaysBefore,
                remindDaysBefore: [document.remindDaysBefore, 7, 0]
            )
        }
    }

    /// Prazos do carro (ITV, seguro, imposto) e próximas manutenções.
    static func carItems(_ vehicles: [Vehicle], now: Date = .now) -> [AgendaItem] {
        vehicles.flatMap { vehicle -> [AgendaItem] in
            let deadlines = (vehicle.deadlines ?? []).map { deadline in
                AgendaItem(
                    id: "car-deadline-\(deadline.uid)",
                    title: deadline.displayTitle,
                    detail: vehicle.displayName,
                    date: deadline.dueDate,
                    symbolName: deadline.kind.symbolName,
                    source: .car,
                    remindDaysBefore: [30, 7, 0]
                )
            }
            return deadlines + maintenanceItems(vehicle, now: now)
        }
    }

    /// A manutenção mais recente de cada tipo, se tiver a próxima marcada.
    private static func maintenanceItems(_ vehicle: Vehicle, now: Date) -> [AgendaItem] {
        let latestByKind = Dictionary(grouping: vehicle.maintenanceRecords ?? [], by: \.kind)
            .compactMap { $0.value.max { $0.date < $1.date } }
        return latestByKind.compactMap { record in
            if let next = record.nextDueDate {
                return AgendaItem(
                    id: "car-maintenance-\(record.uid)",
                    title: record.displayTitle,
                    detail: vehicle.displayName,
                    date: next,
                    symbolName: record.kind.symbolName,
                    source: .car,
                    dueWord: "Próxima",
                    horizonDays: 14,
                    remindDaysBefore: [7, 0]
                )
            }
            let remaining = record.nextDueOdometer - vehicle.currentOdometer
            guard record.nextDueOdometer > 0, remaining <= 1_000 else { return nil }
            let km = abs(remaining).formatted(.number.locale(.app))
            return AgendaItem(
                id: "car-maintenance-\(record.uid)",
                title: record.displayTitle,
                detail: remaining > 0 ? "\(vehicle.displayName) · faltam \(km) km" : "\(vehicle.displayName) · passou \(km) km",
                date: now,
                symbolName: record.kind.symbolName,
                source: .car,
                dueWord: "Próxima",
                remindDaysBefore: []
            )
        }
    }
}
