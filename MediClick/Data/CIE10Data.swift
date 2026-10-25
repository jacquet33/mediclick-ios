import Foundation

// MARK: - CIE-10 Common Codes for Argentine Medical Practice
// Sources: OMS CIE-10 official classification, DocVilla primary care codes,
// VeroScribe common codes, and Argentine health ministry nomenclator.

struct CIE10Code: Identifiable, Hashable {
    let id: String  // The code itself, e.g. "J06.9"
    let description: String

    var displayText: String { "\(id) - \(description)" }
}

/// Pre-loaded CIE-10 codes most commonly used in general/internal medicine.
enum CIE10Database {

    static func search(_ query: String) -> [CIE10Code] {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        // Prioritize code matches first, then description matches
        let codeMatches = allCodes.filter { $0.id.lowercased().hasPrefix(q) }
        let descMatches = allCodes.filter { code in
            !code.id.lowercased().hasPrefix(q)
            && (code.id.lowercased().contains(q) || code.description.lowercased().contains(q))
        }
        return codeMatches + descMatches
    }

    static let allCodes: [CIE10Code] = [
        // ── A: Infecciosas y parasitarias ──
        CIE10Code(id: "A09", description: "Diarrea y gastroenteritis infecciosa"),
        CIE10Code(id: "A15.0", description: "Tuberculosis pulmonar"),
        CIE10Code(id: "A49.9", description: "Infección bacteriana no especificada"),
        CIE10Code(id: "A69.2", description: "Enfermedad de Lyme"),

        // ── B: Otras infecciosas ──
        CIE10Code(id: "B00.9", description: "Infección por herpes simple"),
        CIE10Code(id: "B02.9", description: "Herpes zóster sin complicaciones"),
        CIE10Code(id: "B34.9", description: "Infección viral no especificada"),
        CIE10Code(id: "B35.1", description: "Tiña de uñas (onicomicosis)"),
        CIE10Code(id: "B37.0", description: "Candidiasis bucal"),
        CIE10Code(id: "B37.3", description: "Candidiasis vulvovaginal"),
        CIE10Code(id: "B86", description: "Escabiosis (sarna)"),

        // ── C-D: Neoplasias y sangre ──
        CIE10Code(id: "C50.9", description: "Tumor maligno de mama"),
        CIE10Code(id: "C61", description: "Tumor maligno de próstata"),
        CIE10Code(id: "D25.9", description: "Leiomioma uterino (mioma)"),
        CIE10Code(id: "D50.9", description: "Anemia ferropénica"),
        CIE10Code(id: "D64.9", description: "Anemia no especificada"),
        CIE10Code(id: "D69.6", description: "Trombocitopenia no especificada"),

        // ── E: Endocrinas, nutricionales y metabólicas ──
        CIE10Code(id: "E03.9", description: "Hipotiroidismo no especificado"),
        CIE10Code(id: "E04.9", description: "Bocio no tóxico no especificado"),
        CIE10Code(id: "E05.9", description: "Hipertiroidismo (tirotoxicosis)"),
        CIE10Code(id: "E10", description: "Diabetes mellitus tipo 1"),
        CIE10Code(id: "E11", description: "Diabetes mellitus tipo 2"),
        CIE10Code(id: "E11.6", description: "Diabetes tipo 2 con complicaciones"),
        CIE10Code(id: "E11.9", description: "Diabetes tipo 2 sin complicaciones"),
        CIE10Code(id: "E13", description: "Otra diabetes mellitus especificada"),
        CIE10Code(id: "E55.9", description: "Déficit de vitamina D"),
        CIE10Code(id: "E66.0", description: "Obesidad por exceso de calorías"),
        CIE10Code(id: "E66.9", description: "Obesidad no especificada"),
        CIE10Code(id: "E78.0", description: "Hipercolesterolemia pura"),
        CIE10Code(id: "E78.1", description: "Hipertrigliceridemia pura"),
        CIE10Code(id: "E78.2", description: "Hiperlipidemia mixta (dislipemia)"),
        CIE10Code(id: "E78.5", description: "Dislipemia no especificada"),
        CIE10Code(id: "E79.0", description: "Hiperuricemia (gota)"),
        CIE10Code(id: "E87.6", description: "Hipopotasemia"),

        // ── F: Trastornos mentales ──
        CIE10Code(id: "F10.1", description: "Consumo perjudicial de alcohol"),
        CIE10Code(id: "F17.1", description: "Tabaquismo (dependencia de tabaco)"),
        CIE10Code(id: "F32.0", description: "Episodio depresivo leve"),
        CIE10Code(id: "F32.1", description: "Episodio depresivo moderado"),
        CIE10Code(id: "F32.9", description: "Episodio depresivo no especificado"),
        CIE10Code(id: "F33.0", description: "Trastorno depresivo recurrente"),
        CIE10Code(id: "F41.0", description: "Trastorno de pánico"),
        CIE10Code(id: "F41.1", description: "Trastorno de ansiedad generalizada"),
        CIE10Code(id: "F41.9", description: "Trastorno de ansiedad no especificado"),
        CIE10Code(id: "F43.0", description: "Reacción al estrés agudo"),
        CIE10Code(id: "F43.1", description: "Trastorno de estrés postraumático"),
        CIE10Code(id: "F51.0", description: "Insomnio no orgánico"),
        CIE10Code(id: "F90.9", description: "TDAH no especificado"),

        // ── G: Sistema nervioso ──
        CIE10Code(id: "G40.9", description: "Epilepsia no especificada"),
        CIE10Code(id: "G43.9", description: "Migraña no especificada"),
        CIE10Code(id: "G44.2", description: "Cefalea tensional"),
        CIE10Code(id: "G47.0", description: "Insomnio"),
        CIE10Code(id: "G47.3", description: "Apnea obstructiva del sueño"),
        CIE10Code(id: "G54.1", description: "Lumbociatalgia"),
        CIE10Code(id: "G56.0", description: "Síndrome del túnel carpiano"),

        // ── H: Ojo y oído ──
        CIE10Code(id: "H10.9", description: "Conjuntivitis no especificada"),
        CIE10Code(id: "H40.9", description: "Glaucoma no especificado"),
        CIE10Code(id: "H52.1", description: "Miopía"),
        CIE10Code(id: "H66.9", description: "Otitis media no especificada"),
        CIE10Code(id: "H81.1", description: "Vértigo paroxístico benigno"),

        // ── I: Sistema circulatorio ──
        CIE10Code(id: "I10", description: "Hipertensión arterial esencial"),
        CIE10Code(id: "I11.9", description: "Cardiopatía hipertensiva sin IC"),
        CIE10Code(id: "I12.9", description: "Enfermedad renal hipertensiva"),
        CIE10Code(id: "I20.9", description: "Angina de pecho no especificada"),
        CIE10Code(id: "I21.9", description: "Infarto agudo de miocardio"),
        CIE10Code(id: "I25.1", description: "Cardiopatía ateroesclerótica"),
        CIE10Code(id: "I25.9", description: "Cardiopatía isquémica crónica"),
        CIE10Code(id: "I48", description: "Fibrilación y aleteo auricular"),
        CIE10Code(id: "I48.9", description: "Fibrilación auricular no especificada"),
        CIE10Code(id: "I50.9", description: "Insuficiencia cardíaca no especificada"),
        CIE10Code(id: "I63.9", description: "ACV isquémico"),
        CIE10Code(id: "I64", description: "ACV no especificado"),
        CIE10Code(id: "I73.9", description: "Enfermedad vascular periférica"),
        CIE10Code(id: "I80.2", description: "Trombosis venosa profunda"),
        CIE10Code(id: "I83.9", description: "Várices en miembros inferiores"),
        CIE10Code(id: "I84.9", description: "Hemorroides"),

        // ── J: Sistema respiratorio ──
        CIE10Code(id: "J00", description: "Resfrío común (rinofaringitis aguda)"),
        CIE10Code(id: "J01.9", description: "Sinusitis aguda"),
        CIE10Code(id: "J02.9", description: "Faringitis aguda"),
        CIE10Code(id: "J03.9", description: "Amigdalitis aguda"),
        CIE10Code(id: "J06.9", description: "Infección respiratoria alta aguda"),
        CIE10Code(id: "J11", description: "Gripe (influenza)"),
        CIE10Code(id: "J15.9", description: "Neumonía bacteriana"),
        CIE10Code(id: "J18.9", description: "Neumonía no especificada"),
        CIE10Code(id: "J20.9", description: "Bronquitis aguda"),
        CIE10Code(id: "J30.4", description: "Rinitis alérgica no especificada"),
        CIE10Code(id: "J30.9", description: "Rinitis alérgica"),
        CIE10Code(id: "J44.1", description: "EPOC con exacerbación aguda"),
        CIE10Code(id: "J44.9", description: "EPOC no especificada"),
        CIE10Code(id: "J45.9", description: "Asma no especificada"),

        // ── K: Sistema digestivo ──
        CIE10Code(id: "K04.7", description: "Absceso periapical dental"),
        CIE10Code(id: "K21.0", description: "ERGE con esofagitis"),
        CIE10Code(id: "K21.9", description: "ERGE sin esofagitis"),
        CIE10Code(id: "K25.9", description: "Úlcera gástrica"),
        CIE10Code(id: "K26.9", description: "Úlcera duodenal"),
        CIE10Code(id: "K29.0", description: "Gastritis aguda hemorrágica"),
        CIE10Code(id: "K29.7", description: "Gastritis no especificada"),
        CIE10Code(id: "K30", description: "Dispepsia funcional"),
        CIE10Code(id: "K35.8", description: "Apendicitis aguda"),
        CIE10Code(id: "K40.9", description: "Hernia inguinal"),
        CIE10Code(id: "K57.3", description: "Enfermedad diverticular"),
        CIE10Code(id: "K58.9", description: "Síndrome de intestino irritable"),
        CIE10Code(id: "K59.0", description: "Constipación (estreñimiento)"),
        CIE10Code(id: "K70.3", description: "Cirrosis hepática alcohólica"),
        CIE10Code(id: "K76.0", description: "Hígado graso (esteatosis hepática)"),
        CIE10Code(id: "K80.2", description: "Colelitiasis (cálculos biliares)"),
        CIE10Code(id: "K85.9", description: "Pancreatitis aguda"),

        // ── L: Piel ──
        CIE10Code(id: "L02.9", description: "Absceso cutáneo / forúnculo"),
        CIE10Code(id: "L03.9", description: "Celulitis no especificada"),
        CIE10Code(id: "L20.9", description: "Dermatitis atópica"),
        CIE10Code(id: "L23.9", description: "Dermatitis de contacto alérgica"),
        CIE10Code(id: "L30.9", description: "Dermatitis no especificada"),
        CIE10Code(id: "L40.0", description: "Psoriasis vulgar"),
        CIE10Code(id: "L50.9", description: "Urticaria"),
        CIE10Code(id: "L70.0", description: "Acné vulgar"),

        // ── M: Sistema musculoesquelético ──
        CIE10Code(id: "M10.9", description: "Gota no especificada"),
        CIE10Code(id: "M13.9", description: "Artritis no especificada"),
        CIE10Code(id: "M15.9", description: "Artrosis generalizada"),
        CIE10Code(id: "M17.9", description: "Gonartrosis (artrosis de rodilla)"),
        CIE10Code(id: "M19.9", description: "Artrosis no especificada"),
        CIE10Code(id: "M25.5", description: "Dolor articular"),
        CIE10Code(id: "M54.2", description: "Cervicalgia"),
        CIE10Code(id: "M54.4", description: "Lumbociatalgia"),
        CIE10Code(id: "M54.5", description: "Lumbalgia"),
        CIE10Code(id: "M62.8", description: "Contractura muscular"),
        CIE10Code(id: "M75.1", description: "Síndrome del manguito rotador"),
        CIE10Code(id: "M79.1", description: "Mialgia"),
        CIE10Code(id: "M79.3", description: "Tendinitis no especificada"),
        CIE10Code(id: "M81.9", description: "Osteoporosis no especificada"),

        // ── N: Sistema genitourinario ──
        CIE10Code(id: "N10", description: "Pielonefritis aguda"),
        CIE10Code(id: "N18.9", description: "Enfermedad renal crónica"),
        CIE10Code(id: "N20.0", description: "Cálculo renal (litiasis renal)"),
        CIE10Code(id: "N30.0", description: "Cistitis aguda"),
        CIE10Code(id: "N39.0", description: "Infección urinaria no especificada"),
        CIE10Code(id: "N40", description: "Hiperplasia prostática benigna"),
        CIE10Code(id: "N76.0", description: "Vaginitis aguda"),
        CIE10Code(id: "N92.0", description: "Menstruación excesiva y frecuente"),
        CIE10Code(id: "N94.6", description: "Dismenorrea no especificada"),

        // ── O: Embarazo ──
        CIE10Code(id: "O80", description: "Parto espontáneo único"),
        CIE10Code(id: "Z34", description: "Supervisión de embarazo normal"),

        // ── R: Síntomas y signos ──
        CIE10Code(id: "R00.0", description: "Taquicardia no especificada"),
        CIE10Code(id: "R05", description: "Tos"),
        CIE10Code(id: "R06.0", description: "Disnea"),
        CIE10Code(id: "R07.4", description: "Dolor torácico no especificado"),
        CIE10Code(id: "R10.4", description: "Dolor abdominal no especificado"),
        CIE10Code(id: "R10.9", description: "Dolor abdominal inespecífico"),
        CIE10Code(id: "R11", description: "Náuseas y vómitos"),
        CIE10Code(id: "R19.7", description: "Diarrea no especificada"),
        CIE10Code(id: "R42", description: "Mareo y desvanecimiento"),
        CIE10Code(id: "R50.9", description: "Fiebre no especificada"),
        CIE10Code(id: "R51", description: "Cefalea"),
        CIE10Code(id: "R53", description: "Malestar y fatiga"),
        CIE10Code(id: "R53.8", description: "Otra fatiga / astenia"),
        CIE10Code(id: "R55", description: "Síncope y colapso"),
        CIE10Code(id: "R63.4", description: "Pérdida anormal de peso"),
        CIE10Code(id: "R73.0", description: "Hiperglucemia (prediabetes)"),

        // ── S-T: Traumatismos ──
        CIE10Code(id: "S93.4", description: "Esguince de tobillo"),
        CIE10Code(id: "T14.0", description: "Traumatismo superficial"),
        CIE10Code(id: "T78.4", description: "Reacción alérgica no especificada"),

        // ── Z: Factores y contacto con servicios ──
        CIE10Code(id: "Z00.0", description: "Examen general de salud (control)"),
        CIE10Code(id: "Z01.0", description: "Examen de ojos y visión"),
        CIE10Code(id: "Z01.1", description: "Examen de oídos y audición"),
        CIE10Code(id: "Z10", description: "Examen de salud ocupacional"),
        CIE10Code(id: "Z12.1", description: "Screening de colon"),
        CIE10Code(id: "Z12.3", description: "Screening de mama"),
        CIE10Code(id: "Z12.4", description: "Screening de cuello uterino"),
        CIE10Code(id: "Z13.1", description: "Screening de diabetes"),
        CIE10Code(id: "Z13.2", description: "Screening de lípidos"),
        CIE10Code(id: "Z13.3", description: "Screening de depresión"),
        CIE10Code(id: "Z13.6", description: "Screening cardiovascular"),
        CIE10Code(id: "Z23", description: "Vacunación de rutina"),
        CIE10Code(id: "Z30.0", description: "Asesoramiento anticonceptivo"),
        CIE10Code(id: "Z71.1", description: "Persona con temor de enfermedad"),
        CIE10Code(id: "Z71.3", description: "Consejería dietaria"),
        CIE10Code(id: "Z76.0", description: "Emisión de receta repetida"),
        CIE10Code(id: "Z79.4", description: "Uso prolongado de insulina"),
        CIE10Code(id: "Z79.8", description: "Uso prolongado de otro medicamento"),
        CIE10Code(id: "Z87.8", description: "Antecedente personal de otra enfermedad"),
        CIE10Code(id: "Z96.6", description: "Presencia de implante articular"),

        // ── U: Especiales ──
        CIE10Code(id: "U07.1", description: "COVID-19"),
    ]
}
