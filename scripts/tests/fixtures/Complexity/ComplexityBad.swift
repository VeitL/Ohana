struct ComplexityBad {
    func tooManyParameters(_ a: Int, _ b: Int, _ c: Int, _ d: Int) -> Int {
        a + b + c + d
    }

    func tooLongAndComplex(_ value: Int) -> Int {
        var result = value
        if value > 0 { result += 1 }
        if value > 1 { result += 1 }
        if value > 2 { result += 1 }
        if value > 3 { result += 1 }
        if value > 4 { result += 1 }
        return result
    }
}
