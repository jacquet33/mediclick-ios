import Foundation
import UIKit

// MARK: - WhatsApp Helper

enum WhatsAppHelper {

    /// Normaliza un número telefónico argentino al formato internacional
    /// que usa WhatsApp: 549XXXXXXXXXX (sin +, sin 0, sin 15)
    static func normalizeArgPhone(_ raw: String) -> String {
        // Quitar todo excepto dígitos
        var digits = raw.filter(\.isNumber)

        // Si ya empieza con 549 y tiene 13 dígitos → listo
        if digits.hasPrefix("549") && digits.count == 13 {
            return digits
        }

        // Si empieza con +54 o 54
        if digits.hasPrefix("54") {
            digits = String(digits.dropFirst(2))
        }

        // Quitar 9 de celular si quedó al inicio
        if digits.hasPrefix("9") && digits.count == 11 {
            digits = String(digits.dropFirst(1))
        }

        // Quitar 0 de código de área
        if digits.hasPrefix("0") {
            digits = String(digits.dropFirst(1))
        }

        // Quitar 15 del número local
        // El 15 aparece después del código de área (2-4 dígitos)
        // Ej: 343-15-4XXXXXX → quitar el 15
        if digits.count >= 10 {
            // Buscar 15 en posiciones típicas (después de 2, 3 o 4 dígitos de área)
            for areaLen in 2...4 {
                let idx = digits.index(digits.startIndex, offsetBy: areaLen)
                let after = digits[idx...]
                if after.hasPrefix("15") && digits.count == areaLen + 2 + 8 {
                    digits = String(digits.prefix(areaLen)) + String(after.dropFirst(2))
                    break
                }
            }
        }

        return "549\(digits)"
    }

    /// Genera la URL de WhatsApp con mensaje pre-armado
    static func url(phone: String, message: String = "") -> URL? {
        let normalized = normalizeArgPhone(phone)
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = message.isEmpty
            ? "https://wa.me/\(normalized)"
            : "https://wa.me/\(normalized)?text=\(encoded)"
        return URL(string: urlString)
    }

    /// Abre WhatsApp con el número y mensaje dados
    static func open(phone: String, message: String = "") {
        guard let url = url(phone: phone, message: message) else { return }
        UIApplication.shared.open(url)
    }

    /// Mensaje pre-armado para recordatorio de turno
    static func appointmentMessage(
        patientName: String,
        date: String,
        time: String,
        doctorName: String = ""
    ) -> String {
        var msg = "Hola \(patientName), le recordamos su turno el \(date) a las \(time)"
        if !doctorName.isEmpty {
            msg += " con \(doctorName)"
        }
        msg += ". ¿Confirma su asistencia? TuConsultorioOnline"
        return msg
    }
}
