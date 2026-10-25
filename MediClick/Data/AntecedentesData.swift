import Foundation

// MARK: - Pre-loaded checklist data for Historia Clínica sections

/// Antecedentes personales — checkboxes matching standard Argentine HC format
enum AntecedentesComunes {

    static let personales: [String] = [
        "HTA",
        "Diabetes tipo 2",
        "Diabetes tipo 1",
        "Sobrepeso / Obesidad",
        "Dislipemia",
        "Enfermedad coronaria",
        "Insuficiencia cardíaca",
        "ACV",
        "Arritmia / FA",
        "Enfermedad renal crónica",
        "Enfermedad respiratoria (asma, EPOC)",
        "Enfermedad tiroidea",
        "Enfermedad neurológica",
        "Enfermedad digestiva / hepática",
        "Enfermedad oncológica",
        "Enfermedad tromboembólica",
        "Enfermedad psiquiátrica",
        "Cirugías previas",
        "Internaciones previas",
        "Transfusiones",
        "Otros antecedentes",
    ]

    static let familiares: [String] = [
        "HTA",
        "Diabetes",
        "Dislipemia",
        "Enfermedad coronaria precoz",
        "ACV",
        "Cáncer de mama",
        "Cáncer de colon",
        "Cáncer de próstata",
        "Cáncer de pulmón",
        "Obesidad",
        "Enfermedad renal",
        "Enfermedad tiroidea",
        "Enfermedad autoinmune",
        "Enfermedad psiquiátrica",
        "Muerte súbita",
    ]
}

// MARK: - Examen físico por aparatos

struct ExamenFisicoItem: Identifiable, Hashable {
    let id: String  // unique key
    let label: String
    var hasTextField: Bool = false
    var placeholder: String = ""
}

enum ExamenFisicoData {

    static let items: [ExamenFisicoItem] = [
        ExamenFisicoItem(id: "estado_general", label: "Estado general y sensorio"),
        ExamenFisicoItem(id: "presion_arterial", label: "Presión arterial"),
        ExamenFisicoItem(id: "frecuencia_cardiaca", label: "Frecuencia cardíaca"),
        ExamenFisicoItem(id: "frecuencia_respiratoria", label: "Frecuencia respiratoria"),
        ExamenFisicoItem(id: "temperatura", label: "Temperatura"),
        ExamenFisicoItem(id: "spo2", label: "Saturación de oxígeno"),
        ExamenFisicoItem(id: "peso_talla", label: "Peso y talla"),
        ExamenFisicoItem(id: "imc", label: "IMC"),
        ExamenFisicoItem(id: "cintura", label: "Circunferencia de cintura"),
        ExamenFisicoItem(id: "cabeza_cuello", label: "Cabeza y cuello"),
        ExamenFisicoItem(id: "cardiovascular", label: "Cardiovascular"),
        ExamenFisicoItem(id: "respiratorio", label: "Respiratorio"),
        ExamenFisicoItem(id: "abdomen", label: "Abdomen"),
        ExamenFisicoItem(id: "neurologico", label: "Neurológico"),
        ExamenFisicoItem(id: "extremidades", label: "Extremidades y pulsos"),
        ExamenFisicoItem(id: "piel", label: "Piel y mucosas"),
        ExamenFisicoItem(id: "osteomuscular", label: "Osteomuscular"),
        ExamenFisicoItem(id: "genital", label: "Genitourinario"),
    ]
}

// MARK: - Revisión por sistemas

struct RevisionSistemasItem: Identifiable, Hashable {
    let id: String
    let label: String
    let symptoms: String  // descriptive symptoms for that system
}

enum RevisionSistemasData {

    static let items: [RevisionSistemasItem] = [
        RevisionSistemasItem(
            id: "generales",
            label: "Generales",
            symptoms: "fiebre, pérdida de peso, astenia"
        ),
        RevisionSistemasItem(
            id: "cardiovascular",
            label: "Cardiovascular",
            symptoms: "dolor torácico, palpitaciones, edemas, síncope"
        ),
        RevisionSistemasItem(
            id: "respiratorio",
            label: "Respiratorio",
            symptoms: "disnea, tos, expectoración"
        ),
        RevisionSistemasItem(
            id: "digestivo",
            label: "Digestivo",
            symptoms: "dolor abdominal, náuseas, cambios del tránsito"
        ),
        RevisionSistemasItem(
            id: "genitourinario",
            label: "Genitourinario",
            symptoms: "disuria, polaquiuria, hematuria"
        ),
        RevisionSistemasItem(
            id: "neurologico",
            label: "Neurológico",
            symptoms: "cefalea, déficit focal, mareos"
        ),
        RevisionSistemasItem(
            id: "endocrino",
            label: "Endocrino/metabólico",
            symptoms: "poliuria, polidipsia, intolerancia térmica"
        ),
        RevisionSistemasItem(
            id: "musculoesqueletico",
            label: "Musculoesquelético",
            symptoms: "artralgias, mialgias"
        ),
        RevisionSistemasItem(
            id: "piel",
            label: "Piel",
            symptoms: "lesiones, prurito, cambios de coloración"
        ),
        RevisionSistemasItem(
            id: "hematologico",
            label: "Hematológico",
            symptoms: "sangrado, equimosis, adenopatías"
        ),
        RevisionSistemasItem(
            id: "psiquiatrico",
            label: "Psiquiátrico",
            symptoms: "ánimo, sueño, ansiedad, ideación"
        ),
        RevisionSistemasItem(
            id: "ojos",
            label: "Ojos",
            symptoms: "visión borrosa, dolor ocular, sequedad"
        ),
        RevisionSistemasItem(
            id: "orl",
            label: "ORL",
            symptoms: "hipoacusia, otalgia, rinorrea, odinofagia"
        ),
    ]
}
