import SwiftUI
import SwiftData

struct PatientsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalPatient.lastName) private var patients: [LocalPatient]
    @State private var searchText = ""
    @State private var showNewPatient = false
    
    var filteredPatients: [LocalPatient] {
        if searchText.isEmpty { return patients }
        return patients.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText) ||
            ($0.dni ?? "").contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredPatients) { patient in
                    NavigationLink {
                        PatientDetailView(patient: patient)
                    } label: {
                        PatientRowView(patient: patient)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Buscar por nombre o DNI")
            .navigationTitle("Pacientes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showNewPatient = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .overlay {
                if patients.isEmpty {
                    ContentUnavailableView {
                        Label("Sin pacientes", systemImage: "person.2")
                    } description: {
                        Text("Agregá tu primer paciente")
                    } actions: {
                        Button("Agregar paciente") { showNewPatient = true }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .sheet(isPresented: $showNewPatient) {
                NewPatientView()
            }
        }
    }
}

// MARK: - Patient Row

struct PatientRowView: View {
    let patient: LocalPatient
    
    var body: some View {
        HStack(spacing: 12) {
            PatientAvatar(name: patient.fullName, size: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(patient.fullName)
                    .font(.body.weight(.medium))
                Text(patient.chronicConditions.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if let age = patient.age {
                    Text("\(age) años")
                        .font(.subheadline.weight(.medium))
                }
                Text(patient.insuranceProvider ?? "")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Patient Detail

struct PatientDetailView: View {
    let patient: LocalPatient
    @Query private var records: [LocalMedicalRecord]
    
    var body: some View {
        List {
            // Header
            Section {
                HStack(spacing: 16) {
                    PatientAvatar(name: patient.fullName, size: 60)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(patient.fullName)
                            .font(.title2.bold())
                        if let age = patient.age {
                            Text("\(age) años · DNI \(patient.dni ?? "—")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            
            // Contact
            Section("Contacto") {
                LabeledContent("Teléfono", value: patient.phone ?? "—")
                LabeledContent("Email", value: patient.email ?? "—")
                LabeledContent("Obra social", value: "\(patient.insuranceProvider ?? "—") \(patient.insuranceNumber ?? "")")
            }
            
            // Allergies
            if !patient.allergies.isEmpty {
                Section("Alergias") {
                    FlowLayout(items: patient.allergies) { allergy in
                        Text(allergy)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.red.opacity(0.1))
                            .foregroundStyle(.red)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Chronic conditions
            if !patient.chronicConditions.isEmpty {
                Section("Condiciones crónicas") {
                    FlowLayout(items: patient.chronicConditions) { condition in
                        Text(condition)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
            }
            
            // Emergency contact
            Section("Emergencia") {
                LabeledContent("Contacto", value: patient.emergencyContactName ?? "—")
                LabeledContent("Teléfono", value: patient.emergencyContactPhone ?? "—")
            }
            
            // Notes
            if let notes = patient.notes, !notes.isEmpty {
                Section("Notas") {
                    Text(notes)
                        .font(.body)
                }
            }
        }
        .navigationTitle("Ficha")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - New Patient

struct NewPatientView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var dni = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var dateOfBirth = Date()
    @State private var insuranceProvider = ""
    @State private var insuranceNumber = ""
    @State private var allergiesText = ""
    @State private var conditionsText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Datos personales") {
                    TextField("Nombre *", text: $firstName)
                    TextField("Apellido *", text: $lastName)
                    TextField("DNI", text: $dni).keyboardType(.numberPad)
                    TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                    TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                    DatePicker("Fecha de nacimiento", selection: $dateOfBirth, displayedComponents: .date)
                }
                Section("Obra social") {
                    TextField("Obra social / Prepaga", text: $insuranceProvider)
                    TextField("Nro. de afiliado", text: $insuranceNumber)
                }
                Section("Datos clínicos") {
                    TextField("Alergias (separar con coma)", text: $allergiesText)
                    TextField("Condiciones crónicas (separar con coma)", text: $conditionsText)
                }
                Section {
                    Button("Guardar paciente") { save() }
                        .frame(maxWidth: .infinity)
                        .disabled(firstName.isEmpty || lastName.isEmpty)
                }
            }
            .navigationTitle("Nuevo paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
    
    private func save() {
        let patient = LocalPatient(doctorId: UUID(), firstName: firstName, lastName: lastName)
        patient.dni = dni.isEmpty ? nil : dni
        patient.phone = phone.isEmpty ? nil : phone
        patient.email = email.isEmpty ? nil : email
        patient.dateOfBirth = dateOfBirth
        patient.insuranceProvider = insuranceProvider.isEmpty ? nil : insuranceProvider
        patient.insuranceNumber = insuranceNumber.isEmpty ? nil : insuranceNumber
        patient.allergies = allergiesText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        patient.chronicConditions = conditionsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        patient.syncStatus = .pendingUpload
        modelContext.insert(patient)
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Helpers

struct PatientAvatar: View {
    let name: String
    let size: CGFloat
    
    private var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.prefix(1) ?? ""
        let last = parts.dropFirst().first?.prefix(1) ?? ""
        return "\(first)\(last)".uppercased()
    }
    
    private var color: Color {
        let colors: [Color] = [.blue, .red, .green, .purple, .orange, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
    
    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.35, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color)
            .clipShape(Circle())
    }
}

struct FlowLayout<T: Hashable, Content: View>: View {
    let items: [T]
    let content: (T) -> Content
    
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}
