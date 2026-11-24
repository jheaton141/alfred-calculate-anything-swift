import Foundation

/// Built-in language packs (ported from the PHP lang files), embedded so the binary needs no resource bundle.
enum LanguagePacks {
    static let json: [String: String] = ["en_EN": en, "es_ES": es, "sv_SE": sv]

    static let en = #"""
    {
      "copy_number": "Action this item to copy this number to the clipboard",
      "copy_raw": "Action this item to copy the amount with no format",
      "copy_with_unit": "Action this item to copy this value with unit to the clipboard",
      "error_div_zero": "Cannot divide by zero",
      "error_math_domain": "Invalid input",
      "vat_result": "VAT of %@ = %@",
      "vat_subtitle": "VAT of %@",
      "vat_plus": "%@ plus VAT = %@",
      "vat_minus": "%@ minus VAT = %@",
      "vat_minus_subtitle": "%@ minus %@ of VAT",
      "vat_empty": "Enter a value to process",
      "percentage_result": "%@ is %@ of %@",
      "percentage_increase": "The percentage increase from %@ to %@ is %@",
      "percentage_decrease": "The percentage decrease from %@ to %@ is %@",
      "difference_subtitle": "Time difference between %@ and %@",
      "until_subtitle": "%@ until %@",
      "since_subtitle": "%@ since %@",
      "notvalid_subtitle": "Enter a valid date",
      "format_subtitle": "Format %@",
      "rates_unavailable": "Exchange rates unavailable",
      "cached_rates_from": "cached rates from"
    }
    """#

    static let es = #"""
    {
      "copy_number": "Presiona enter para copiar el valor al clipboard",
      "copy_raw": "Presiona enter para copiar el valor al clipboard sin formato",
      "copy_with_unit": "Presiona enter para copiar el valor al clipboard con formato completo",
      "error_div_zero": "No se puede dividir entre cero",
      "error_math_domain": "Entrada no válida",
      "vat_result": "IVA de %@ = %@",
      "vat_subtitle": "IVA del %@",
      "vat_plus": "%@ más IVA = %@",
      "vat_minus": "%@ menos IVA = %@",
      "vat_minus_subtitle": "%@ menos %@ de IVA",
      "vat_empty": "Ingresa un valor para procesar",
      "percentage_result": "%@ es %@ de %@",
      "percentage_increase": "El incremento en porcentaje de %@ a %@ es de %@",
      "percentage_decrease": "El decremento en porcentaje de %@ a %@ es de %@",
      "difference_subtitle": "Diferencia de tiempo entre %@ y %@",
      "until_subtitle": "%@ faltantes hasta el %@",
      "since_subtitle": "%@ desde el %@",
      "notvalid_subtitle": "Ingresa una fecha válida",
      "format_subtitle": "Formato %@",
      "rates_unavailable": "Tipos de cambio no disponibles",
      "cached_rates_from": "tipos en caché del"
    }
    """#

    static let sv = #"""
    {
      "copy_number": "Kopiera värdet till urklipp",
      "copy_raw": "Kopiera utan formattering till urklipp",
      "copy_with_unit": "Kopiera med enhet till urklipp",
      "error_div_zero": "Kan inte dividera med noll",
      "error_math_domain": "Ogiltig inmatning",
      "vat_result": "%@ moms = %@",
      "vat_subtitle": "%@ moms",
      "vat_plus": "%@ plus moms = %@",
      "vat_minus": "%@ minus moms = %@",
      "vat_minus_subtitle": "%@ minus %@ moms",
      "vat_empty": "Fyll i ett korrekt värde",
      "percentage_result": "%@ är %@ av %@",
      "percentage_increase": "Den procentuella ökningen från %@ till %@ är %@",
      "percentage_decrease": "Den procentuella minskningen från %@ till %@ är %@",
      "difference_subtitle": "Tidsskillnaden mellan %@ och %@",
      "until_subtitle": "%@ till %@",
      "since_subtitle": "%@ sedan %@",
      "notvalid_subtitle": "Fyll i ett korrekt datum",
      "format_subtitle": "Formatera %@",
      "rates_unavailable": "Växelkurser otillgängliga",
      "cached_rates_from": "cachade kurser från"
    }
    """#
}
