import Testing

@testable import PlantCatalog

struct VarietalNameTests {
    @Test func stripsAPlainCropPrefix() {
        #expect(VarietalName.bare("Basil - Blue Spice", cropNames: ["Basil"]) == "Blue Spice")
        #expect(VarietalName.bare("Basil - Cardinal", cropNames: ["Basil"]) == "Cardinal")
    }

    @Test func stripsAQualifiedCropPrefixAndKeepsTheQualifier() {
        #expect(
            VarietalName.bare("Tomato (Organic) - Roma", cropNames: ["Tomato"])
                == "Roma (Organic)")
        #expect(
            VarietalName.bare("Bean (Bush) - Blue Lake 274", cropNames: ["Bean"])
                == "Blue Lake 274 (Bush)")
    }

    @Test func keepsAQualifierThatItselfContainsADash() {
        #expect(
            VarietalName.bare("Bean (Organic - Bush) - Provider", cropNames: ["Bean"])
                == "Provider (Organic - Bush)")
    }

    @Test func stripsAPrefixThatExtendsTheCropWord() {
        #expect(
            VarietalName.bare("Hot Pepper - Serrano", cropNames: ["Pepper"]) == "Serrano")
        #expect(
            VarietalName.bare("Chinese Cabbage - Michihili", cropNames: ["Cabbage"])
                == "Michihili")
    }

    @Test func matchesAnyProvidedCropName() {
        #expect(
            VarietalName.bare("Sweetcorn - Glass Gem", cropNames: ["Corn", "Sweetcorn"])
                == "Glass Gem")
    }

    @Test func keepsTrademarkSymbolsInTheVarietalName() {
        #expect(
            VarietalName.bare("Tomato - Kitchen Minis™ 'Siam'", cropNames: ["Tomato"])
                == "Kitchen Minis™ 'Siam'")
    }

    @Test func keepsHyphensInsideTheVarietalName() {
        #expect(
            VarietalName.bare("Hot Pepper - Pot-a-Peno", cropNames: ["Pepper"])
                == "Pot-a-Peno")
        #expect(
            VarietalName.bare("Corn - Grow Your Own Popcorn", cropNames: ["Corn"])
                == "Grow Your Own Popcorn")
    }

    @Test func leavesNamesWithoutACropPrefixAlone() {
        #expect(VarietalName.bare("Brandywine", cropNames: ["Tomato"]) == "Brandywine")
        #expect(
            VarietalName.bare("Blue Lake Bush Bean", cropNames: ["Bean"])
                == "Blue Lake Bush Bean")
        #expect(
            VarietalName.bare("Aunt Molly's Ground Cherry", cropNames: ["Tomato"])
                == "Aunt Molly's Ground Cherry")
    }

    @Test func requiresTheWholeCropWordInThePrefix() {
        #expect(
            VarietalName.bare("Peach Melba - Rosette", cropNames: ["Pea"])
                == "Peach Melba - Rosette")
    }

    @Test func leavesADashOnlyNameAlone() {
        #expect(VarietalName.bare("Tomato - ", cropNames: ["Tomato"]) == "Tomato - ")
        #expect(VarietalName.bare(" - Roma", cropNames: ["Tomato"]) == " - Roma")
    }
}
