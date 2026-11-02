import SwiftUI

/// Días con atención del médico, según su agenda (GET /api/v1/schedules/days).
struct DiasAtencion: Decodable {
    let weekdays: [Int]          // 0 = domingo … 6 = sábado
    let blockedDates: [String]   // YYYY-MM-DD (feriados, ausencias)
}

/// Calendario mensual que muestra en gris y no deja elegir los días sin atención.
struct MediDayPicker: View {
    @Binding var selection: Date
    var weekdays: Set<Int>?          // nil = todavía no se cargó la agenda: se permiten todos los días
    var blocked: Set<String> = []
    var minDate: Date = Calendar.current.startOfDay(for: Date())

    @State private var month: Date = Date()
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "es_AR")
        c.firstWeekday = 1
        return c
    }()
    private static let iso: DateFormatter = {
        let f = DateFormatter(); f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX"); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let titulo: DateFormatter = {
        let f = DateFormatter(); f.locale = Locale(identifier: "es_AR"); f.dateFormat = "LLLL yyyy"; return f
    }()

    func habilitado(_ d: Date) -> Bool {
        if d < minDate { return false }
        guard let w = weekdays else { return true }
        let dow = cal.component(.weekday, from: d) - 1
        return w.contains(dow) && !blocked.contains(Self.iso.string(from: d))
    }

    private var dias: [Date?] {
        guard let inicio = cal.date(from: cal.dateComponents([.year, .month], from: month)),
              let rango = cal.range(of: .day, in: .month, for: inicio) else { return [] }
        let vacios = cal.component(.weekday, from: inicio) - 1
        return Array(repeating: nil, count: vacios) + rango.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: inicio) }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button { cambiar(-1) } label: { Image(systemName: "chevron.left") }
                    .disabled(cal.isDate(month, equalTo: minDate, toGranularity: .month))
                Spacer()
                Text(Self.titulo.string(from: month).capitalized).font(.headline).foregroundStyle(Color.mediText)
                Spacer()
                Button { cambiar(1) } label: { Image(systemName: "chevron.right") }
            }
            .foregroundStyle(Color.mediPrimary)

            let cols = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
            LazyVGrid(columns: cols, spacing: 6) {
                ForEach(["D", "L", "M", "M", "J", "V", "S"].indices, id: \.self) { i in
                    Text(["D", "L", "M", "M", "J", "V", "S"][i]).font(.caption2.weight(.semibold)).foregroundStyle(Color.mediTextMuted)
                }
                ForEach(Array(dias.enumerated()), id: \.offset) { _, d in
                    if let d {
                        let ok = habilitado(d)
                        let sel = cal.isDate(d, inSameDayAs: selection)
                        Button {
                            selection = d
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        } label: {
                            Text("\(cal.component(.day, from: d))")
                                .font(.subheadline.weight(sel ? .bold : .regular))
                                .frame(maxWidth: .infinity, minHeight: 38)
                                .foregroundStyle(sel ? Color.white : (ok ? Color.mediText : Color.mediTextMuted.opacity(0.45)))
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(sel ? Color.mediPrimary : Color.clear)
                                )
                                .overlay(
                                    cal.isDateInToday(d) && !sel
                                    ? RoundedRectangle(cornerRadius: 10).stroke(Color.mediPrimary.opacity(0.4), lineWidth: 1) : nil
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!ok)
                        .accessibilityLabel(ok ? "Día \(cal.component(.day, from: d))" : "Día \(cal.component(.day, from: d)), sin atención")
                    } else {
                        Color.clear.frame(height: 38)
                    }
                }
            }
            if weekdays != nil {
                Text("Los días en gris no tienen atención.")
                    .font(.caption).foregroundStyle(Color.mediTextMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { month = selection }
    }

    private func cambiar(_ n: Int) {
        if let m = cal.date(byAdding: .month, value: n, to: month) { withAnimation(.easeInOut(duration: 0.2)) { month = m } }
    }

    /// Primer día con atención desde hoy (para preseleccionar).
    func primerDiaHabil(desde: Date = Date()) -> Date? {
        var d = cal.startOfDay(for: desde)
        for _ in 0..<120 { if habilitado(d) { return d }; d = cal.date(byAdding: .day, value: 1, to: d)! }
        return nil
    }
}
