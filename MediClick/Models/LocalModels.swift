// ============================================================
// MediClick - iOS Local Database (SwiftData)
// Offline-first: SQLite local + sync con PostgreSQL via REST
// Compatible: iOS 17+ (SwiftData) / iOS 15-16 fallback Core Data
// ============================================================

import Foundation
import SwiftData

// MARK: - Sync Protocol

/// Cada modelo sincronizable implementa este protocolo
protocol Syncable {
    var id: UUID { get }
    var remoteId: UUID? { get set }
    var syncStatus: SyncStatus { get set }
    var lastSyncedAt: Date? { get set }
    var updatedAt: Date { get set }
}

enum SyncStatus: String, Codable {
    case synced         // Sincronizado con el servidor
    case pendingUpload  // Creado/editado local, pendiente de subir
    case pendingDelete  // Marcado para borrar en servidor
    case conflict       // Conflicto de versiones
}

// MARK: - Doctor (usuario logueado, cache local)

@Model
final class LocalDoctor {
    @Attribute(.unique) var id: UUID
    var email: String
    var firstName: String
    var lastName: String
    var phone: String?
    var medicalLicense: String
    var specialty: String
    var avatarUrl: String?
    var role: String
    
    // Auth tokens (almacenados en Keychain, aquí solo referencia)
    @Transient var accessToken: String?
    @Transient var refreshToken: String?
    
    var lastLoginAt: Date?
    var createdAt: Date
    
    init(id: UUID, email: String, firstName: String, lastName: String,
         medicalLicense: String, specialty: String = "Clínica médica") {
        self.id = id
        self.email = email
        self.firstName = firstName
        self.lastName = lastName
        self.medicalLicense = medicalLicense
        self.specialty = specialty
        self.role = "doctor"
        self.createdAt = Date()
    }
}

// MARK: - Patient

@Model
final class LocalPatient: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var doctorId: UUID
    var dni: String?
    var firstName: String
    var lastName: String
    var email: String?
    var phone: String?
    var dateOfBirth: Date?
    var gender: String
    var bloodType: String
    var address: String?
    var city: String?
    var province: String?
    var emergencyContactName: String?
    var emergencyContactPhone: String?
    var insuranceProvider: String?
    var insuranceNumber: String?
    var allergies: [String]
    var chronicConditions: [String]
    var notes: String?
    var isActive: Bool
    var createdAt: Date
    
    // Relaciones
    @Relationship(deleteRule: .cascade, inverse: \LocalAppointment.patient)
    var appointments: [LocalAppointment]?
    
    @Relationship(deleteRule: .cascade, inverse: \LocalPrescription.patient)
    var prescriptions: [LocalPrescription]?
    
    @Relationship(deleteRule: .cascade, inverse: \LocalMedicalRecord.patient)
    var medicalRecords: [LocalMedicalRecord]?
    
    @Relationship(deleteRule: .cascade, inverse: \LocalConversation.patient)
    var conversations: [LocalConversation]?
    
    var fullName: String { "\(firstName) \(lastName)" }
    var initials: String { "\(firstName.prefix(1))\(lastName.prefix(1))" }
    
    var age: Int? {
        guard let dob = dateOfBirth else { return nil }
        return Calendar.current.dateComponents([.year], from: dob, to: Date()).year
    }
    
    init(doctorId: UUID, firstName: String, lastName: String) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.doctorId = doctorId
        self.firstName = firstName
        self.lastName = lastName
        self.gender = "not_specified"
        self.bloodType = "unknown"
        self.allergies = []
        self.chronicConditions = []
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Appointment

@Model
final class LocalAppointment: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var doctorId: UUID
    var patient: LocalPatient?
    
    var date: Date
    var startTime: Date
    var endTime: Date
    var status: String          // pending, confirmed, in_progress, completed, cancelled, no_show
    var reason: String?
    var notes: String?
    var isFirstVisit: Bool
    var reminderSent: Bool
    var cancelledAt: Date?
    var cancelledReason: String?
    var createdAt: Date
    
    /// Hora formateada "09:30"
    var formattedStartTime: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: startTime)
    }
    
    init(doctorId: UUID, patient: LocalPatient, date: Date, startTime: Date, endTime: Date) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.doctorId = doctorId
        self.patient = patient
        self.date = date
        self.startTime = startTime
        self.endTime = endTime
        self.status = "pending"
        self.isFirstVisit = false
        self.reminderSent = false
        self.createdAt = Date()
    }
}

// MARK: - Medical Record (Historia Clínica)

@Model
final class LocalMedicalRecord: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var patient: LocalPatient?
    var doctorId: UUID
    var appointmentId: UUID?
    var date: Date
    
    var chiefComplaint: String       // Motivo de consulta
    var presentIllness: String?      // Enfermedad actual
    
    // Signos vitales como JSON serializado
    var vitalSignsData: Data?        // {bp, hr, temp, rr, spo2, weight, height}
    var physicalExam: String?
    
    var diagnosis: String
    var diagnosisCode: String?       // CIE-10
    var treatmentPlan: String?
    
    var labOrders: [String]
    var imagingOrders: [String]
    var privateNotes: String?
    
    var createdAt: Date
    
    init(patient: LocalPatient, doctorId: UUID, chiefComplaint: String, diagnosis: String) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.patient = patient
        self.doctorId = doctorId
        self.date = Date()
        self.chiefComplaint = chiefComplaint
        self.diagnosis = diagnosis
        self.labOrders = []
        self.imagingOrders = []
        self.createdAt = Date()
    }
}

// MARK: - Prescription (Receta)

@Model
final class LocalPrescription: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var doctorId: UUID
    var patient: LocalPatient?
    var medicalRecordId: UUID?
    
    var status: String              // active, expired, cancelled
    var diagnosis: String
    var diagnosisCode: String?      // CIE-10
    var issuedAt: Date
    var expiresAt: Date
    var digitalSignature: String?
    var verificationCode: String?
    var notes: String?
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \LocalPrescriptionItem.prescription)
    var items: [LocalPrescriptionItem]?
    
    var isExpired: Bool { expiresAt < Date() }
    
    init(doctorId: UUID, patient: LocalPatient, diagnosis: String, expiresAt: Date) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.doctorId = doctorId
        self.patient = patient
        self.status = "active"
        self.diagnosis = diagnosis
        self.issuedAt = Date()
        self.expiresAt = expiresAt
        self.createdAt = Date()
    }
}

// MARK: - Prescription Item (Medicamento)

@Model
final class LocalPrescriptionItem {
    @Attribute(.unique) var id: UUID
    var prescription: LocalPrescription?
    
    var medicationName: String
    var dosage: String              // "10mg"
    var frequency: String           // "1 comp cada 12hs"
    var duration: String?           // "30 días"
    var quantity: Int?
    var instructions: String?
    var sortOrder: Int
    
    init(prescription: LocalPrescription, medicationName: String, dosage: String, frequency: String) {
        self.id = UUID()
        self.prescription = prescription
        self.medicationName = medicationName
        self.dosage = dosage
        self.frequency = frequency
        self.sortOrder = 0
    }
}

// MARK: - Conversation

@Model
final class LocalConversation: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var doctorId: UUID
    var patient: LocalPatient?
    
    var lastMessageText: String?
    var lastMessageAt: Date?
    var doctorUnreadCount: Int
    var isActive: Bool
    var createdAt: Date
    
    @Relationship(deleteRule: .cascade, inverse: \LocalMessage.conversation)
    var messages: [LocalMessage]?
    
    init(doctorId: UUID, patient: LocalPatient) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.doctorId = doctorId
        self.patient = patient
        self.doctorUnreadCount = 0
        self.isActive = true
        self.createdAt = Date()
    }
}

// MARK: - Message

@Model
final class LocalMessage: Syncable {
    @Attribute(.unique) var id: UUID
    var remoteId: UUID?
    var syncStatus: SyncStatus
    var lastSyncedAt: Date?
    var updatedAt: Date
    
    var conversation: LocalConversation?
    var senderType: String          // "doctor" | "patient"
    var senderId: UUID
    var messageType: String         // text, image, file, prescription, appointment
    var content: String
    var attachmentUrl: String?
    var attachmentName: String?
    var prescriptionId: UUID?
    var appointmentId: UUID?
    var isRead: Bool
    var readAt: Date?
    var createdAt: Date
    
    init(conversation: LocalConversation, senderType: String, senderId: UUID, content: String) {
        self.id = UUID()
        self.syncStatus = .pendingUpload
        self.updatedAt = Date()
        self.conversation = conversation
        self.senderType = senderType
        self.senderId = senderId
        self.messageType = "text"
        self.content = content
        self.isRead = false
        self.createdAt = Date()
    }
}

// MARK: - Notification

@Model
final class LocalNotification {
    @Attribute(.unique) var id: UUID
    var recipientId: UUID
    var type: String
    var title: String
    var body: String
    var dataJson: Data?
    var isRead: Bool
    var readAt: Date?
    var createdAt: Date
    
    init(recipientId: UUID, type: String, title: String, body: String) {
        self.id = UUID()
        self.recipientId = recipientId
        self.type = type
        self.title = title
        self.body = body
        self.isRead = false
        self.createdAt = Date()
    }
}

// MARK: - SwiftData Container Setup

@MainActor
func createModelContainer() throws -> ModelContainer {
    let schema = Schema([
        LocalDoctor.self,
        LocalPatient.self,
        LocalAppointment.self,
        LocalMedicalRecord.self,
        LocalPrescription.self,
        LocalPrescriptionItem.self,
        LocalConversation.self,
        LocalMessage.self,
        LocalNotification.self,
    ])
    
    let config = ModelConfiguration(
        "MediClick",
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true
    )
    
    return try ModelContainer(for: schema, configurations: [config])
}
