import Testing

@testable import Knowledge

@Test(arguments: [
    "Bi-Color Pear Gourd", "Gourd - Dipper", "Luffa Gourd", "Cucuzzi Squash",
])
func gourdsAndLuffasAreNotSquash(name: String) {
    #expect(SquashClassification.classify(cultivarNamed: name) == .gourd)
}

@Test(arguments: [
    "Squash (Summer) - Melody Blend", "Zucchini Black Beauty", "Crookneck Squash",
    "Early Prolific Straightneck Squash", "White Scallop Squash",
    "Squash (Organic) - Black Beauty", "Lemon Squash",
])
func summerTypesClassifyToSummerSquash(name: String) {
    #expect(SquashClassification.classify(cultivarNamed: name) == .crop("summer-squash"))
}

@Test(arguments: [
    "Squash (Winter) - Guatemalan Blue", "Waltham Butternut Squash", "Delicata Squash",
    "Blue Hubbard Squash", "Kabocha Squash", "Sweet Dumpling Squash",
    "Gill's Golden Pippin Squash", "North Georgia Candy Roaster Squash",
    "Green Stripe Cushaw Squash", "Pumpkin - Cushaw Green-Striped",
])
func winterTypesClassifyToWinterSquash(name: String) {
    #expect(SquashClassification.classify(cultivarNamed: name) == .crop("winter-squash"))
}

@Test(arguments: [
    "Pumpkin - Jack Be Little", "Pumpkin (Organic) - Small Sugar",
    "Pumpkin - Musquee de Provence",
])
func vendorPumpkinsClassifyToThePumpkinCrop(name: String) {
    #expect(SquashClassification.classify(cultivarNamed: name) == .crop("pumpkin"))
}

@Test func unmarkedNamesStayUnknown() {
    #expect(SquashClassification.classify(cultivarNamed: "Marrow Mystery") == .unknown)
    #expect(SquashClassification.classify(cultivarNamed: "Ultra Nova") == .unknown)
}
