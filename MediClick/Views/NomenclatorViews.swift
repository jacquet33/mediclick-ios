import SwiftUI
import UniformTypeIdentifiers

struct NomenclatorListView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: BillingStore
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 12) {
                        if store.nomenclators.isEmpty && !store.isLoading {
                            EmptyStateMedi(
                                icon: "list.bullet.rectangle.portrait",
                                title: "Sin nomencladores",
                                subtitle: "Cargá los aranceles de tus convenios para poder facturar",
                                actionTitle: "Cargar nomenclador"
                            ) { showCreate = true }
                            .padding(.top, 50)
                        } else {
                            ForEach(store.nomenclators) { nom in
                                NomenclatorCard(nomenclator: nom, store: store)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nomencladores")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showCreate = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.mediPrimary)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreateNomenclatorView(store: store)
            }
            .task {
                await store.loadNomenclators()
                await store.loadInsurersInUse()
            }
        }
    }
}

struct NomenclatorCard: View {
    let nomenclator: NomenclatorVersion
    @Bindable var store: BillingStore
    @State private var showImport = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient.medi(
                            nomenclator.isCurrent
                            ? [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
                            : [.mediTextMuted, .mediTextSoft]
                        ))
                        .frame(width: 40, height: 40)
                    Image(systemName: "list.number")
                        .font(.system(size: 17))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(nomenclator.insurerName ?? nomenclator.name)
                        .font(.mediHeadline(15))
                        .foregroundStyle(Color.mediText)
                    Text(nomenclator.periodLabel)
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                }

                Spacer()

                if nomenclator.isCurrent {
                    MediBadge("Vigente", color: .mediSuccess)
                }
            }

            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(nomenclator.itemCount ?? 0)")
                        .font(.mediHeadline(16))
                        .foregroundStyle(Color.mediText)
                    Text("códigos")
                        .font(.caption2)
                        .foregroundStyle(Color.mediTextSoft)
                }

                if let uv = nomenclator.unitValue {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(uv.pesos)
                            .font(.mediHeadline(16))
                            .foregroundStyle(Color.mediText)
                        Text("valor galeno")
                            .font(.caption2)
                            .foregroundStyle(Color.mediTextSoft)
                    }
                }

                Spacer()
            }

            if let missing = nomenclator.itemsWithoutValue, missing > 0 {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.caption)
                    Text("\(missing) códigos sin valor")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.mediWarning)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mediWarning.opacity(0.09))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }

            Button {
                showImport = true
            } label: {
                Label("Importar planilla", systemImage: "square.and.arrow.down")
                    .font(.caption.weight(.semibold))
            }
            .buttonStyle(MediButtonStyle(isSecondary: true))
        }
        .mediElevated(padding: 16)
        .sheet(isPresented: $showImport) {
            ImportSheetView(nomenclatorId: nomenclator.id, store: store)
        }
    }
}

// MARK: - Crear versión

struct CreateNomenclatorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: BillingStore

    @State private var name = ""
    @State private var selectedInsurer: Insurer?
    @State private var validFrom = Date()
    @State private var unitValue = ""
    @State private var usesUnits = false

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Convenio", icon: "building.2.fill")

                            Menu {
                                ForEach(store.insurers) { ins in
                                    Button(ins.name) {
                                        selectedInsurer = ins
                                        if name.isEmpty { name = "Nomenclador \(ins.display)" }
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "cross.case.fill")
                                        .foregroundStyle(Color.mediPrimary)
                                    Text(selectedInsurer?.name ?? "Elegir obra social")
                                        .foregroundStyle(selectedInsurer == nil
                                                         ? Color.mediTextMuted : Color.mediText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                        .foregroundStyle(Color.mediPrimary)
                                }
                                .padding(16)
                                .background(Color.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.mediPrimary.opacity(0.15), lineWidth: 1)
                                )
                            }

                            MediTextField(icon: "textformat", placeholder: "Nombre", text: $name)
                        }
                        .mediElevated(padding: 18)

                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Vigencia", icon: "calendar")

                            DatePicker("Rige desde", selection: $validFrom, displayedComponents: .date)
                                .tint(Color.mediPrimary)
                                .foregroundStyle(Color.mediText)

                            Text("Las prestaciones anteriores a esta fecha se siguen valorizando con la versión previa")
                                .font(.caption2)
                                .foregroundStyle(Color.mediTextSoft)
                        }
                        .mediElevated(padding: 18)

                        VStack(alignment: .leading, spacing: 14) {
                            MediSectionHeader(title: "Valorización", icon: "dollarsign.circle.fill")

                            Toggle(isOn: $usesUnits) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Por galenos")
                                        .font(.mediCaption(15))
                                        .foregroundStyle(Color.mediText)
                                    Text("La planilla trae unidades en vez de importes")
                                        .font(.caption2)
                                        .foregroundStyle(Color.mediTextSoft)
                                }
                            }
                            .tint(Color.mediCyan)

                            if usesUnits {
                                MediTextField(icon: "function", placeholder: "Valor del galeno", text: $unitValue)
                                    .keyboardType(.decimalPad)
                            }
                        }
                        .mediElevated(padding: 18)

                        Button {
                            Task {
                                guard let ins = selectedInsurer else { return }
                                let uv = usesUnits ? Decimal(string: unitValue.replacingOccurrences(of: ",", with: ".")) : nil
                                if await store.createNomenclator(
                                    name: name, insurerId: ins.id,
                                    validFrom: validFrom, unitValue: uv
                                ) != nil {
                                    await store.loadNomenclators()
                                    dismiss()
                                }
                            }
                        } label: {
                            if store.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Label("Crear", systemImage: "checkmark.circle.fill")
                            }
                        }
                        .buttonStyle(MediButtonStyle())
                        .disabled(selectedInsurer == nil || name.isEmpty || store.isLoading)
                        .opacity(selectedInsurer == nil || name.isEmpty ? 0.6 : 1)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Nuevo nomenclador")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Color.mediPrimary)
                }
            }
        }
    }
}

// MARK: - Importar planilla

struct ImportSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let nomenclatorId: String
    @Bindable var store: BillingStore

    @State private var showPicker = false
    @State private var result: ImportResult?
    @State private var fileName: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let result {
                            resultView(result)
                        } else {
                            instructions
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(result == nil ? "Importar planilla" : "Importado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Cancelar" : "Listo") {
                        if result != nil {
                            Task { await store.loadNomenclators() }
                        }
                        dismiss()
                    }
                    .foregroundStyle(Color.mediPrimary)
                }
            }
            .fileImporter(
                isPresented: $showPicker,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                allowsMultipleSelection: false
            ) { outcome in
                handlePick(outcome)
            }
        }
    }

    private var instructions: some View {
        Group {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.medi([.mediCyan.opacity(0.18), .mediSky.opacity(0.06)]))
                        .frame(width: 88, height: 88)
                    Image(systemName: "tablecells")
                        .font(.system(size: 36, weight: .light))
                        .foregroundStyle(LinearGradient.medi([.mediCyan, .mediSky]))
                }

                Text("Subí la planilla del convenio")
                    .font(.mediTitle(19))
                    .foregroundStyle(Color.mediText)

                Text("Guardala como CSV desde Excel y elegila acá")
                    .font(.subheadline)
                    .foregroundStyle(Color.mediTextSoft)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)

            VStack(alignment: .leading, spacing: 12) {
                MediSectionHeader(title: "Qué columnas busca", icon: "info.circle")

                columnHint("Código", "codigo, cod, practica")
                columnHint("Descripción", "descripcion, detalle, denominacion")
                columnHint("Importe", "importe, valor, arancel")
                columnHint("Galenos", "unidades, galenos, honorarios")

                Text("No hace falta que estén en orden ni con el nombre exacto. Si falta alguna, te avisamos.")
                    .font(.caption2)
                    .foregroundStyle(Color.mediTextSoft)
                    .padding(.top, 4)
            }
            .mediElevated(padding: 18)

            if let fileName {
                HStack(spacing: 9) {
                    Image(systemName: "doc.fill").foregroundStyle(Color.mediPrimary)
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(Color.mediText)
                        .lineLimit(1)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mediBgSoft.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            Button {
                showPicker = true
            } label: {
                if store.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Label("Elegir archivo", systemImage: "folder")
                }
            }
            .buttonStyle(MediButtonStyle())
            .disabled(store.isLoading)
        }
    }

    private func resultView(_ r: ImportResult) -> some View {
        Group {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.medi([.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]))
                        .frame(width: 70, height: 70)
                    Image(systemName: "checkmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("\(r.inserted + r.updated) códigos")
                    .font(.mediTitle(22))
                    .foregroundStyle(Color.mediText)

                Text("\(r.inserted) nuevos · \(r.updated) actualizados")
                    .font(.subheadline)
                    .foregroundStyle(Color.mediTextSoft)
            }
            .frame(maxWidth: .infinity)
            .mediElevated(padding: 24)

            if !r.warnings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MediSectionHeader(title: "Atención", icon: "exclamationmark.triangle.fill")
                    ForEach(r.warnings, id: \.self) { w in
                        Text(w)
                            .font(.caption)
                            .foregroundStyle(Color.mediText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .mediElevated(padding: 18)
            }
        }
    }

    private func columnHint(_ label: String, _ options: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.mediText)
                .frame(width: 88, alignment: .leading)
            Text(options)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.mediTextSoft)
            Spacer(minLength: 0)
        }
    }

    private func handlePick(_ outcome: Result<[URL], Error>) {
        guard case .success(let urls) = outcome, let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else {
            store.errorMessage = "No se pudo abrir el archivo"
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        fileName = url.lastPathComponent

        guard let data = try? Data(contentsOf: url) else {
            store.errorMessage = "No se pudo leer el archivo"
            return
        }

        // Excel suele guardar en Latin-1
        let csv = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""

        guard !csv.isEmpty else {
            store.errorMessage = "El archivo está vacío o tiene una codificación que no reconocemos"
            return
        }

        Task {
            result = await store.importSheet(nomenclatorId: nomenclatorId, csv: csv)
        }
    }
}
