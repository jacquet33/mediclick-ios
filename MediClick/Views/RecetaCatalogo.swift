import SwiftUI

// MARK: - Catálogo oficial de medicamentos (GET /api/v1/medicamentos)

struct MedBusqueda: Decodable {
    struct Generico: Decodable, Identifiable {
        let droga: String
        let marcas: Int
        let presentaciones: Int
        var id: String { droga }
    }
    struct Marca: Decodable, Identifiable {
        let marca: String
        let droga: String
        let laboratorio: String?
        let presentaciones: Int
        let coberturaPami: String?
        var id: String { marca + "|" + droga }
    }
    let genericos: [Generico]
    let marcas: [Marca]
}

struct MedPresentacion: Decodable, Identifiable {
    let alfabeta: Int?
    let marca: String?
    let droga: String
    let presentacion: String
    let forma: String?
    let laboratorio: String?
    let coberturaPami: String?
    let laboratorios: Int?
    var id: String { "\(alfabeta ?? 0)|\(presentacion)|\(marca ?? "")" }
}

/// Lo que el médico eligió en el buscador
struct MedicamentoSeleccion {
    var droga: String
    var marca: String?
    var presentacion: String?
    var forma: String?
    var coberturaPami: String?
}

func capitalizarPrimera(_ t: String) -> String {
    guard let f = t.first else { return t }
    return f.uppercased() + t.dropFirst()
}

/// Buscador a pantalla completa: marca o droga → presentación (como RCTA)
struct MedicamentoSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    let esPami: Bool
    let onSelect: (MedicamentoSeleccion) -> Void
    let onManual: (String) -> Void

    @State private var query = ""
    @State private var resultado: MedBusqueda?
    @State private var buscando = false
    @FocusState private var foco: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.mediTextMuted)
                        TextField("Marca o droga: amoxidal, ibuprofeno…", text: $query)
                            .font(.system(size: 16))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($foco)
                            .submitLabel(.search)
                        if !query.isEmpty {
                            Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.mediTextMuted) }
                                .accessibilityLabel("Borrar búsqueda")
                        }
                    }
                    .padding(14)
                    .background(Color.mediSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mediTeal, lineWidth: 1.2))
                    .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            if query.trimmingCharacters(in: .whitespaces).count < 2 {
                                Text("Escribí al menos 2 letras del nombre comercial o de la droga.")
                                    .font(.system(size: 14)).foregroundStyle(Color.mediTextMuted)
                                    .frame(maxWidth: .infinity).padding(.top, 30)
                            } else if buscando && resultado == nil {
                                ProgressView().frame(maxWidth: .infinity).padding(.top, 30)
                            } else if let r = resultado, r.genericos.isEmpty && r.marcas.isEmpty {
                                Text("No encontramos \"\(query)\". Revisá cómo se escribe o cargalo a mano.")
                                    .font(.system(size: 14)).foregroundStyle(Color.mediTextMuted)
                                    .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 30)
                            } else if let r = resultado {
                                if !r.genericos.isEmpty {
                                    seccion("RECETAR POR NOMBRE GENÉRICO")
                                    ForEach(r.genericos) { g in
                                        NavigationLink {
                                            PresentacionesView(droga: g.droga, marca: nil, esPami: esPami) { sel in elegir(sel) }
                                        } label: {
                                            tarjeta(titulo: capitalizarPrimera(g.droga), sub: nil,
                                                    detalle: "Genérico · \(g.marcas) marca\(g.marcas == 1 ? "" : "s") · \(g.presentaciones) presentaciones",
                                                    chip: nil, generico: true)
                                        }
                                    }
                                }
                                if !r.marcas.isEmpty {
                                    seccion("MARCAS COMERCIALES")
                                    ForEach(r.marcas) { m in
                                        NavigationLink {
                                            PresentacionesView(droga: m.droga, marca: m.marca, esPami: esPami) { sel in elegir(sel) }
                                        } label: {
                                            tarjeta(titulo: m.marca, sub: m.droga,
                                                    detalle: [m.laboratorio, "\(m.presentaciones) presentación\(m.presentaciones == 1 ? "" : "es")"].compactMap { $0 }.joined(separator: " · "),
                                                    chip: esPami ? m.coberturaPami.map { "PAMI \($0)" } : nil, generico: false)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 20)
                    }

                    Button {
                        let t = query.trimmingCharacters(in: .whitespaces)
                        onManual(t.rangeOfCharacter(from: .decimalDigits) == nil ? capitalizarPrimera(t) : "")
                        dismiss()
                    } label: {
                        Text("No lo encuentro: cargar a mano").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.mediTeal)
                    .padding(.vertical, 12)
                }
            }
            .navigationTitle("Agregar medicamento")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Image(systemName: "xmark") }
                        .foregroundStyle(Color.mediText).accessibilityLabel("Cerrar")
                }
            }
            .task(id: query) { await buscar() }
            .onAppear { foco = true }
        }
    }

    private func elegir(_ sel: MedicamentoSeleccion) {
        onSelect(sel)
        dismiss()
    }

    private func buscar() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { resultado = nil; return }
        try? await Task.sleep(nanoseconds: 220_000_000) // espera a que termine de escribir
        if Task.isCancelled { return }
        buscando = true
        defer { buscando = false }
        if let r: MedBusqueda = try? await APIClient.shared.get("/api/v1/medicamentos", query: ["q": q, "limit": "40"]) {
            if !Task.isCancelled { resultado = r }
        }
    }

    private func seccion(_ t: String) -> some View {
        Text(t).font(.system(size: 11, weight: .bold)).tracking(0.6)
            .foregroundStyle(Color.mediTextMuted).padding(.top, 10).padding(.leading, 4)
    }

    private func tarjeta(titulo: String, sub: String?, detalle: String, chip: String?, generico: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.mediText)
                if let sub { Text(sub).font(.system(size: 14)).foregroundStyle(Color.mediText) }
                HStack(spacing: 6) {
                    Text(detalle).font(.system(size: 12)).foregroundStyle(Color.mediTextMuted)
                    if let chip { ChipCobertura(texto: chip) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Color.mediTextMuted)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(generico ? Color.mediSuccessSoft : Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.mediBorder.opacity(0.6), lineWidth: 0.5))
        .contentShape(Rectangle())
    }
}

struct ChipCobertura: View {
    let texto: String
    var body: some View {
        Text(texto).font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Color.mediSuccessSoft).foregroundStyle(Color.mediSuccess)
            .clipShape(Capsule())
    }
}

/// Paso 2: elegir la presentación ("16 mg comp. x 30", "jbe. x 100 ml")
struct PresentacionesView: View {
    let droga: String
    let marca: String?
    let esPami: Bool
    let onSelect: (MedicamentoSeleccion) -> Void

    @State private var lista: [MedPresentacion] = []
    @State private var cargando = true

    var body: some View {
        ZStack {
            MediBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(marca ?? capitalizarPrimera(droga)).font(.system(size: 18, weight: .bold))
                        Text(marca != nil ? droga : "Por nombre genérico: la farmacia puede dispensar cualquier marca")
                            .font(.system(size: 13)).foregroundStyle(Color.mediTextMuted)
                    }
                    .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.mediSurface).clipShape(RoundedRectangle(cornerRadius: 14))

                    Text("ELEGÍ LA PRESENTACIÓN").font(.system(size: 11, weight: .bold)).tracking(0.6)
                        .foregroundStyle(Color.mediTextMuted).padding(.top, 8).padding(.leading, 4)

                    if cargando { ProgressView().frame(maxWidth: .infinity).padding(.top, 20) }
                    ForEach(lista) { p in
                        Button {
                            onSelect(MedicamentoSeleccion(droga: p.droga, marca: marca, presentacion: p.presentacion, forma: p.forma, coberturaPami: p.coberturaPami))
                        } label: {
                            HStack {
                                Text(p.presentacion).font(.system(size: 16)).foregroundStyle(Color.mediText)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    if let lab = marca != nil ? p.laboratorio : ((p.laboratorios ?? 1) > 1 ? "\(p.laboratorios!) laboratorios" : p.laboratorio) {
                                        Text(lab).font(.system(size: 12)).foregroundStyle(Color.mediTextMuted)
                                    }
                                    if esPami, let c = p.coberturaPami { ChipCobertura(texto: "PAMI \(c)") }
                                }
                            }
                            .padding(14)
                            .background(Color.mediSurface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder.opacity(0.6), lineWidth: 0.5))
                        }
                    }
                    Button {
                        onSelect(MedicamentoSeleccion(droga: droga, marca: marca, presentacion: nil, forma: nil, coberturaPami: nil))
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Otra presentación").font(.system(size: 15, weight: .semibold))
                            Text("La escribís vos en la receta").font(.system(size: 12)).foregroundStyle(Color.mediTextMuted)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading).padding(14)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.mediBorder, style: StrokeStyle(lineWidth: 1, dash: [4])))
                    }
                    .foregroundStyle(Color.mediText)
                }
                .padding(16)
            }
        }
        .navigationTitle("Presentación")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            var q: [String: String?] = ["droga": droga]
            if let marca { q["marca"] = marca }
            lista = (try? await APIClient.shared.get("/api/v1/medicamentos/presentaciones", query: q)) ?? []
            cargando = false
        }
    }
}

// MARK: - Paciente con su cobertura

/// Búsqueda de pacientes por nombre o DNI, mostrando la cobertura de cada uno
struct PatientPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let patients: [LocalPatient]
    let onSelect: (LocalPatient) -> Void
    @State private var query = ""

    private var filtrados: [LocalPatient] {
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return patients }
        return patients.filter { p in
            let t = "\(p.firstName) \(p.lastName) \(p.dni ?? "") \(p.phone ?? "")".folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return q.split(separator: " ").allSatisfy { t.contains($0) }
        }
    }

    var body: some View {
        NavigationStack {
            List(filtrados) { p in
                Button {
                    onSelect(p); dismiss()
                } label: {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.fullName).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.mediText)
                            Text(p.dni.map { "DNI \($0)" } ?? "Sin DNI").font(.system(size: 12)).foregroundStyle(Color.mediTextMuted)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let os = p.insuranceProvider, !os.trimmingCharacters(in: .whitespaces).isEmpty {
                                ChipCobertura(texto: os)
                                Text(p.insuranceNumber.map { "Afiliado \($0)" } ?? "Sin nº de afiliado")
                                    .font(.system(size: 11)).foregroundStyle(p.insuranceNumber == nil ? Color.mediWarning : Color.mediTextMuted)
                            } else {
                                Text("Particular").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.mediTextMuted)
                            }
                        }
                    }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Nombre, apellido o DNI")
            .navigationTitle("Elegir paciente")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediTeal) } }
            .overlay { if filtrados.isEmpty { Text("Sin resultados. Probá con el DNI o el apellido.").foregroundStyle(Color.mediTextMuted) } }
        }
    }
}

/// Cobertura médica del paciente (obra social, plan y nº de afiliado), editable desde la receta
struct CoberturaCard: View {
    @Bindable var patient: LocalPatient
    @State private var plan: String = ""
    @State private var editando = false

    private var particular: Bool { (patient.insuranceProvider ?? "").trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Cobertura médica", systemImage: "cross.case.fill").font(.system(size: 14, weight: .semibold))
                Spacer()
                Button("Editar") { editando = true }.font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.mediTeal)
            }
            if particular {
                Text("Sin cobertura · Particular").font(.system(size: 15))
            } else {
                HStack(alignment: .top, spacing: 12) {
                    dato("COBERTURA", patient.insuranceProvider ?? "")
                    dato("PLAN", plan.isEmpty ? "—" : plan)
                    dato("Nº AFILIADO", patient.insuranceNumber ?? "Falta cargarlo", alerta: patient.insuranceNumber == nil)
                }
            }
        }
        .padding(14)
        .background(Color.mediBgSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.mediBorder, lineWidth: 0.5))
        .task(id: patient.id) { await cargarPlan() }
        .sheet(isPresented: $editando) {
            EditarCoberturaSheet(patient: patient, plan: plan) { nuevoPlan in plan = nuevoPlan }
        }
    }

    private func dato(_ t: String, _ v: String, alerta: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(t).font(.system(size: 10, weight: .medium)).tracking(0.4).foregroundStyle(Color.mediTextMuted)
            Text(v).font(.system(size: 14, weight: .semibold)).foregroundStyle(alerta ? Color.mediWarning : Color.mediText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private struct PacienteServidor: Decodable { let insuranceProvider: String?; let insurancePlan: String?; let insuranceNumber: String? }

    /// El plan no se guarda en el teléfono: se trae del servidor junto con lo último de la cobertura
    private func cargarPlan() async {
        guard let rid = patient.remoteId else { return }
        if let s: PacienteServidor = try? await APIClient.shared.get("/api/v1/patients/\(rid.uuidString.lowercased())") {
            plan = s.insurancePlan ?? ""
            if let os = s.insuranceProvider { patient.insuranceProvider = os.isEmpty ? nil : os }
            if let n = s.insuranceNumber { patient.insuranceNumber = n.isEmpty ? nil : n }
        }
    }
}

struct EditarCoberturaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var patient: LocalPatient
    let plan: String
    let onGuardado: (String) -> Void

    @State private var sinCobertura = false
    @State private var os = ""
    @State private var planTxt = ""
    @State private var numero = ""
    @State private var error: String?
    @State private var guardando = false

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Sin cobertura (particular)", isOn: $sinCobertura)
                if !sinCobertura {
                    Section("Cobertura") {
                        TextField("Obra social o prepaga (ej: OSDE, PAMI)", text: $os)
                        TextField("Plan (ej: 310, SMG20)", text: $planTxt)
                        TextField("Nº de afiliado", text: $numero).keyboardType(.numbersAndPunctuation)
                    }
                }
                if let error { Text(error).foregroundStyle(Color.mediDanger).font(.system(size: 13)) }
            }
            .navigationTitle("Cobertura médica")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(guardando ? "Guardando…" : "Guardar") { Task { await guardar() } }.disabled(guardando)
                }
            }
            .onAppear {
                os = patient.insuranceProvider ?? ""
                numero = patient.insuranceNumber ?? ""
                planTxt = plan
                sinCobertura = os.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
        .presentationDetents([.medium, .large])
    }

    private struct Cuerpo: Encodable { let insuranceProvider: String; let insurancePlan: String; let insuranceNumber: String }
    private struct Ok: Decodable {}

    private func guardar() async {
        let c = sinCobertura ? Cuerpo(insuranceProvider: "", insurancePlan: "", insuranceNumber: "")
            : Cuerpo(insuranceProvider: os.trimmingCharacters(in: .whitespaces), insurancePlan: planTxt.trimmingCharacters(in: .whitespaces), insuranceNumber: numero.trimmingCharacters(in: .whitespaces))
        if !sinCobertura && c.insuranceProvider.isEmpty { error = "Escribí la obra social o marcá \"Sin cobertura\""; return }
        guardando = true
        defer { guardando = false }
        if let rid = patient.remoteId {
            do {
                let _: Ok = try await APIClient.shared.put("/api/v1/patients/\(rid.uuidString.lowercased())", body: c)
            } catch {
                self.error = "No se pudo guardar. Revisá la conexión."
                return
            }
        }
        patient.insuranceProvider = c.insuranceProvider.isEmpty ? nil : c.insuranceProvider
        patient.insuranceNumber = c.insuranceNumber.isEmpty ? nil : c.insuranceNumber
        patient.updatedAt = Date()
        onGuardado(c.insurancePlan)
        dismiss()
    }
}
