import SwiftUI

struct BatchDetailView: View {
    let batchId: String
    @Bindable var store: BillingStore

    @State private var detail: BillingBatchDetail?
    @State private var audit: AuditResult?
    @State private var filter: LineFilter = .all
    @State private var exportURL: URL?
    @State private var showSubmit = false
    @State private var batchNumber = ""

    enum LineFilter: String, CaseIterable {
        case all = "Todas"
        case blocked = "Bloqueadas"
        case warning = "Revisar"
        case ok = "Correctas"
    }

    private var filtered: [BillingItem] {
        guard let items = detail?.items else { return [] }
        switch filter {
        case .all: return items
        case .blocked: return items.filter { $0.auditStatus == "blocked" }
        case .warning: return items.filter { $0.auditStatus == "warning" }
        case .ok: return items.filter { $0.auditStatus == "ok" }
        }
    }

    private var blockedCount: Int {
        detail?.items.filter { $0.isBlocked }.count ?? 0
    }

    var body: some View {
        ZStack {
            MediBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    if let detail {
                        header(detail)

                        if let audit {
                            auditSummary(audit)
                        }

                        filterBar

                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { item in
                                LineCard(item: item) {
                                    Task {
                                        if await store.removeItem(batchId: batchId, itemId: item.id) {
                                            await reload()
                                        }
                                    }
                                }
                            }
                        }

                        if filtered.isEmpty {
                            Text(filter == .blocked
                                 ? "No hay líneas bloqueadas"
                                 : "Nada para mostrar")
                                .font(.subheadline)
                                .foregroundStyle(Color.mediTextSoft)
                                .padding(.vertical, 30)
                        }

                        actions(detail)
                    } else {
                        ProgressView().tint(Color.mediPrimary).padding(.top, 80)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(detail.map { "\($0.insurerName ?? "Lote")" } ?? "Lote")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(item: Binding(
            get: { exportURL.map { ShareItem(url: $0) } },
            set: { _ in exportURL = nil }
        )) { item in
            ShareSheet(items: [item.url])
        }
        .alert("Presentar lote", isPresented: $showSubmit) {
            TextField("Nro de lote (opcional)", text: $batchNumber)
            Button("Cancelar", role: .cancel) {}
            Button("Presentar") {
                Task {
                    if await store.submit(batchId, batchNumber: batchNumber.isEmpty ? nil : batchNumber) {
                        await reload()
                        await store.loadBatches()
                    }
                }
            }
        } message: {
            Text("Se marca como presentado ante la obra social. Después no se puede modificar.")
        }
        .alert("Error", isPresented: .constant(store.errorMessage != nil)) {
            Button("Cerrar") { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    // ─── Secciones ────────────────────────────────────────

    private func header(_ d: BillingBatchDetail) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(periodLabel(d.periodYear, d.periodMonth))
                        .font(.mediTitle(22))
                        .foregroundStyle(.white)
                    Text(d.insurerName ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(d.totalAmount.pesos)
                        .font(.mediNumber(24))
                        .foregroundStyle(.white)
                    Text("\(d.totalItems ?? d.items.count) prestaciones")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
        }
        .padding(20)
        .background(ZStack { LinearGradient.mediHero; LinearGradient.mediShine })
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.25), lineWidth: 1))
        .shadow(color: .mediPrimary.opacity(0.3), radius: 18, y: 8)
    }

    private func auditSummary(_ a: AuditResult) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            MediSectionHeader(
                title: a.canSubmit ? "Listo para presentar" : "Hay que corregir",
                icon: a.canSubmit ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
            )

            if !a.findings.isEmpty {
                ForEach(a.findings.prefix(5)) { f in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(f.count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 22, minHeight: 20)
                            .background(Color.mediTextSoft)
                            .clipShape(Capsule())
                        Text(f.note)
                            .font(.caption)
                            .foregroundStyle(Color.mediText)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
            }
        }
        .mediElevated(padding: 18)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(LineFilter.allCases, id: \.self) { f in
                    let count = countFor(f)
                    Button {
                        withAnimation(.spring(response: 0.3)) { filter = f }
                    } label: {
                        HStack(spacing: 6) {
                            Text(f.rawValue)
                                .font(.caption.weight(.semibold))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.caption2.weight(.bold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(filter == f ? .white.opacity(0.25) : colorFor(f).opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(filter == f ? .white : colorFor(f))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(filter == f ? colorFor(f) : Color.mediBgSoft)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(colorFor(f).opacity(0.15), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func actions(_ d: BillingBatchDetail) -> some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    audit = await store.audit(batchId)
                    await reload()
                }
            } label: {
                Label("Volver a auditar", systemImage: "arrow.clockwise")
            }
            .buttonStyle(MediButtonStyle(isSecondary: true))

            Button {
                Task { exportURL = await store.exportCsv(batchId) }
            } label: {
                Label("Exportar CSV", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(MediButtonStyle(isSecondary: true))

            if d.status == "draft" || d.status == "audited" {
                Button {
                    showSubmit = true
                } label: {
                    Label(
                        blockedCount > 0
                        ? "Corregí \(blockedCount) líneas primero"
                        : "Marcar como presentado",
                        systemImage: blockedCount > 0 ? "lock.fill" : "paperplane.fill"
                    )
                }
                .buttonStyle(MediButtonStyle(
                    colors: [.mediSuccess, Color(red: 0.10, green: 0.65, blue: 0.48)]
                ))
                .disabled(blockedCount > 0)
                .opacity(blockedCount > 0 ? 0.55 : 1)
            }
        }
        .padding(.top, 6)
    }

    // ─── Helpers ──────────────────────────────────────────

    private func reload() async {
        detail = await store.loadBatch(batchId)
    }

    private func countFor(_ f: LineFilter) -> Int {
        guard let items = detail?.items else { return 0 }
        switch f {
        case .all: return items.count
        case .blocked: return items.filter { $0.auditStatus == "blocked" }.count
        case .warning: return items.filter { $0.auditStatus == "warning" }.count
        case .ok: return items.filter { $0.auditStatus == "ok" }.count
        }
    }

    private func colorFor(_ f: LineFilter) -> Color {
        switch f {
        case .all: return .mediPrimary
        case .blocked: return .mediDanger
        case .warning: return .mediWarning
        case .ok: return .mediSuccess
        }
    }

    private func periodLabel(_ y: Int, _ m: Int) -> String {
        let months = ["","Enero","Febrero","Marzo","Abril","Mayo","Junio",
                      "Julio","Agosto","Septiembre","Octubre","Noviembre","Diciembre"]
        return "\(m >= 1 && m <= 12 ? months[m] : "\(m)") \(y)"
    }
}

// MARK: - Línea del lote

struct LineCard: View {
    let item: BillingItem
    let onDelete: () -> Void

    @State private var expanded = false

    private var accent: Color {
        item.isBlocked ? .mediDanger : item.hasWarning ? .mediWarning : .mediSuccess
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) { expanded.toggle() }
            } label: {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(accent)
                        .frame(width: 3, height: 40)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.patientName)
                            .font(.mediCaption(15))
                            .foregroundStyle(Color.mediText)
                        HStack(spacing: 6) {
                            Text(item.nomenclatorCode)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Color.mediPrimary)
                            Text(item.serviceDate, format: .dateTime.day().month(.abbreviated))
                                .font(.caption2)
                                .foregroundStyle(Color.mediTextSoft)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(item.totalAmount.pesos)
                            .font(.mediCaption(15))
                            .foregroundStyle(Color.mediText)
                        if item.isBlocked {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.mediDanger)
                        } else if item.hasWarning {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(Color.mediWarning)
                        }
                    }
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            if expanded {
                VStack(alignment: .leading, spacing: 10) {
                    Divider().overlay(Color.mediPrimary.opacity(0.1))

                    if let desc = item.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundStyle(Color.mediTextSoft)
                    }

                    HStack(spacing: 16) {
                        detailField("Afiliado", item.affiliateNumber ?? "—")
                        detailField("Diagnóstico", item.diagnosisCode ?? "—")
                    }

                    if let notes = item.auditNotes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 7) {
                            ForEach(notes, id: \.self) { note in
                                HStack(alignment: .top, spacing: 7) {
                                    Image(systemName: item.isBlocked
                                          ? "xmark.circle.fill" : "info.circle.fill")
                                        .font(.system(size: 12))
                                        .foregroundStyle(accent)
                                    Text(note)
                                        .font(.caption)
                                        .foregroundStyle(Color.mediText)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(accent.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button(role: .destructive, action: onDelete) {
                        Label("Quitar del lote", systemImage: "trash")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(Color.mediDanger)
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 14)
            }
        }
        .background(Color.mediSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(item.isBlocked ? accent.opacity(0.3) : Color.mediPrimary.opacity(0.12),
                        lineWidth: item.isBlocked ? 1.5 : 1)
        )
        .shadow(color: .mediPrimary.opacity(0.06), radius: 8, y: 3)
    }

    private func detailField(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color.mediTextMuted)
            Text(value)
                .font(.caption)
                .foregroundStyle(Color.mediText)
        }
    }
}

// MARK: - Compartir

struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
