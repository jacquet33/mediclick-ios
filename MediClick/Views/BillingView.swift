import SwiftUI

// MARK: - Lista de lotes

struct BillingView: View {
    @State private var store = BillingStore()
    @State private var showBuild = false
    @State private var showNomenclators = false

    var body: some View {
        ZStack {
            MediBackground()

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 14) {
                    if store.isLoading && store.batches.isEmpty {
                        ProgressView().tint(Color.mediPrimary).padding(.top, 60)
                    } else if store.batches.isEmpty {
                        EmptyStateMedi(
                            icon: "doc.text.magnifyingglass",
                            title: "Sin lotes",
                            subtitle: "Armá el lote del mes con los turnos atendidos",
                            actionTitle: "Armar lote"
                        ) { showBuild = true }
                        .padding(.top, 50)
                    } else {
                        ForEach(store.batches) { batch in
                            NavigationLink {
                                BatchDetailView(batchId: batch.id, store: store)
                            } label: {
                                BatchCard(batch: batch)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("Facturación")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showNomenclators = true } label: {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundStyle(Color.mediPrimary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showBuild = true } label: {
                    ZStack {
                        Circle().fill(LinearGradient.mediHero).frame(width: 32, height: 32)
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showBuild) {
            BuildBatchView(store: store)
        }
        .sheet(isPresented: $showNomenclators) {
            NomenclatorListView(store: store)
        }
        .task { await store.loadBatches() }
        .refreshable { await store.loadBatches() }
        .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
            Button("Cerrar") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

struct BatchCard: View {
    let batch: BillingBatch

    private var statusColors: [Color] {
        switch batch.status {
        case "draft": return [.mediTextMuted, .mediTextSoft]
        case "audited": return batch.hasBlockers
            ? [.mediDanger, Color(red: 0.85, green: 0.25, blue: 0.30)]
            : [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
        case "submitted": return [.mediCyan, .mediPrimary]
        case "accepted", "paid": return [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
        case "rejected": return [.mediDanger, Color(red: 0.85, green: 0.25, blue: 0.30)]
        default: return [.mediTextMuted, .mediTextSoft]
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(LinearGradient.medi(statusColors))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(batch.insurerShort ?? batch.insurerName ?? "Financiador")
                        .font(.mediHeadline(16))
                        .foregroundStyle(Color.mediText)
                    Text(batch.periodLabel)
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                }

                Spacer()

                MediBadge(batch.statusLabel, color: statusColors[0])
            }

            Divider().overlay(Color.mediPrimary.opacity(0.1))

            HStack(spacing: 20) {
                metric("Prestaciones", "\(batch.itemCount ?? batch.totalItems ?? 0)")
                metric("Importe", batch.totalAmount.pesos)
                Spacer()
            }

            if batch.hasBlockers {
                HStack(spacing: 7) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                    Text("\(batch.blockedCount ?? 0) líneas van a ser rechazadas")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.mediDanger)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mediDanger.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            } else if (batch.warningCount ?? 0) > 0 {
                HStack(spacing: 7) {
                    Image(systemName: "info.circle.fill").font(.caption)
                    Text("\(batch.warningCount ?? 0) para revisar")
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(Color.mediWarning)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.mediWarning.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 9))
            }
        }
        .mediElevated(padding: 16)
    }

    private func metric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.mediHeadline(16))
                .foregroundStyle(Color.mediText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.mediTextSoft)
        }
    }
}

// MARK: - Armar lote

struct BuildBatchView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var store: BillingStore

    @State private var selectedInsurer: Insurer?
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var result: BuildBatchResult?

    private let months = ["Enero","Febrero","Marzo","Abril","Mayo","Junio",
                          "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]

    var body: some View {
        NavigationStack {
            ZStack {
                MediBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        if let result {
                            resultView(result)
                        } else {
                            formView
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(result == nil ? "Armar lote" : "Lote armado")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result == nil ? "Cancelar" : "Listo") {
                        if result != nil {
                            Task { await store.loadBatches() }
                        }
                        dismiss()
                    }
                    .foregroundStyle(Color.mediPrimary)
                }
            }
            .task { await store.loadInsurersInUse() }
        }
    }

    private var formView: some View {
        Group {
            VStack(alignment: .leading, spacing: 14) {
                MediSectionHeader(title: "Financiador", icon: "building.2.fill")

                if store.insurers.isEmpty {
                    Text("Todavía no hay pacientes con obra social cargada")
                        .font(.caption)
                        .foregroundStyle(Color.mediTextSoft)
                } else {
                    Menu {
                        ForEach(store.insurers) { ins in
                            Button(ins.name) { selectedInsurer = ins }
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
                }
            }
            .mediElevated(padding: 18)

            VStack(alignment: .leading, spacing: 14) {
                MediSectionHeader(title: "Período", icon: "calendar")

                Picker("Mes", selection: $month) {
                    ForEach(1...12, id: \.self) { m in
                        Text(months[m-1]).tag(m)
                    }
                }
                .pickerStyle(.menu)
                .tint(Color.mediPrimary)

                Stepper("Año: \(String(year))", value: $year, in: 2020...2030)
                    .tint(Color.mediPrimary)
                    .foregroundStyle(Color.mediText)
            }
            .mediElevated(padding: 18)

            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").font(.caption)
                    Text("Se toman los turnos marcados como completados")
                        .font(.caption)
                }
                .foregroundStyle(Color.mediTextSoft)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)

            Button {
                Task {
                    guard let ins = selectedInsurer else { return }
                    result = await store.buildBatch(
                        insurerId: ins.id, year: year, month: month
                    )
                }
            } label: {
                if store.isLoading {
                    ProgressView().tint(.white)
                } else {
                    Label("Armar lote", systemImage: "wand.and.stars")
                }
            }
            .buttonStyle(MediButtonStyle())
            .disabled(selectedInsurer == nil || store.isLoading)
            .opacity(selectedInsurer == nil ? 0.6 : 1)
        }
    }

    private func resultView(_ r: BuildBatchResult) -> some View {
        Group {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient.medi(
                            r.audit.canSubmit
                            ? [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
                            : [.mediWarning, Color(red: 0.95, green: 0.55, blue: 0.10)]
                        ))
                        .frame(width: 70, height: 70)
                    Image(systemName: r.audit.canSubmit ? "checkmark" : "exclamationmark")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(.white)
                }

                Text("\(r.itemsAdded) prestaciones")
                    .font(.mediTitle(22))
                    .foregroundStyle(Color.mediText)

                Text(r.audit.canSubmit
                     ? "El lote está listo para presentar"
                     : "Hay líneas que hay que corregir")
                    .font(.subheadline)
                    .foregroundStyle(Color.mediTextSoft)
            }
            .frame(maxWidth: .infinity)
            .mediElevated(padding: 24)

            HStack(spacing: 10) {
                auditChip("\(r.audit.ok)", "Correctas", .mediSuccess)
                auditChip("\(r.audit.warning)", "Revisar", .mediWarning)
                auditChip("\(r.audit.blocked)", "Bloqueadas", .mediDanger)
            }

            if !r.audit.findings.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    MediSectionHeader(title: "Qué encontramos", icon: "list.bullet.clipboard")
                    ForEach(r.audit.findings.prefix(6)) { f in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(f.count)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 24, minHeight: 22)
                                .background(Color.mediTextSoft)
                                .clipShape(Capsule())
                            Text(f.note)
                                .font(.caption)
                                .foregroundStyle(Color.mediText)
                            Spacer()
                        }
                    }
                }
                .mediElevated(padding: 18)
            }

            if !r.skipped.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    MediSectionHeader(title: "No se incluyeron", icon: "minus.circle", color: .mediWarning)
                    ForEach(r.skipped.prefix(5), id: \.self) { s in
                        Text("• \(s)")
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                    }
                }
                .mediElevated(padding: 18)
            }
        }
    }

    private func auditChip(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.mediNumber(24))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.mediTextSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
}
