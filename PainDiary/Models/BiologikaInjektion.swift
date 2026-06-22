import Foundation
import SwiftData

@Model final class BiologikaInjektion {
    var datum: Date = Date()
    var praeparat: String = ""
    var dosierungMg: Double = 0
    var chargenNummer: String = ""
    var injektionsstelle: String = ""
    var naechsteDosis: Date? = nil
    var notizen: String = ""

    init(datum: Date = .now, praeparat: String = "") {
        self.datum = datum
        self.praeparat = praeparat
    }

    static let gaengigesPraeparate = [
        "Adalimumab (Humira)", "Etanercept (Enbrel)", "Secukinumab (Cosentyx)",
        "Tocilizumab (Actemra)", "Abatacept (Orencia)", "Rituximab (MabThera)",
        "Ixekizumab (Taltz)", "Guselkumab (Tremfya)", "Ustekinumab (Stelara)",
        "Baricitinib (Olumiant)", "Tofacitinib (Xeljanz)", "Upadacitinib (Rinvoq)",
    ]

    static let injektionsStellen = [
        "Bauch links", "Bauch rechts", "Oberschenkel links", "Oberschenkel rechts",
        "Oberarm links", "Oberarm rechts",
    ]
}
