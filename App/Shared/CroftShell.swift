import Design
import GardenModel
import SwiftUI

struct CroftShell: View {
    @State private var selection: AppSection?
    @State private var gardenStore: GardenStore
    @Environment(\.appStores) private var appStores
    @State private var captureStore = CaptureStore(stores: nil)
    @State private var captureReady = false
    @State private var propertyForm: PropertyDetailsForm?
    @State private var showsPropertySetup = false
    private let initialRoute: SectionRoute?

    init(
        gardenStore: GardenStore? = nil,
        captureStore: CaptureStore? = nil,
        initialSection: AppSection = .today,
        initialRoute: SectionRoute? = nil
    ) {
        _selection = State(initialValue: initialSection)
        _gardenStore = State(initialValue: gardenStore ?? .live())
        _captureStore = State(initialValue: captureStore ?? CaptureStore(stores: nil))
        _captureReady = State(initialValue: captureStore != nil)
        self.initialRoute = initialRoute
    }

    var body: some View {
        shell
            .sheet(isPresented: $showsPropertySetup) {
                propertyForm?.markPrompted()
            } content: {
                if let propertyForm {
                    PropertySetupSheet(form: propertyForm)
                }
            }
            .task {
                guard propertyForm == nil, let database = appStores?.database else {
                    return
                }
                let form = PropertyDetailsForm(
                    database: database,
                    defaults: PropertySetupDefaults(store: AppDefaultsStore.current),
                    fillCoordinate: PropertyLocationFill.system,
                    addressSearch: SystemAddressSearch(),
                    reverseGeocode: SystemAddressSearch.reverseGeocode,
                    minima: PropertyClimateHistory.system
                )
                form.load()
                propertyForm = form
                showsPropertySetup = form.shouldOfferSetup
            }
    }

    @ViewBuilder private var shell: some View {
        #if os(macOS)
            NavigationSplitView {
                List(selection: $selection) {
                    ForEach(AppSection.allCases) { section in
                        Label(section.title, systemImage: section.symbolName)
                            .listItemTint(section.domainColor)
                            .tag(section)
                    }
                }
                .navigationSplitViewColumnWidth(min: 180, ideal: 210)
                .navigationTitle("Croft")
            } detail: {
                sectionStack(for: selection ?? .today)
            }
            .frame(minWidth: 760, minHeight: 520)
        #else
            TabView {
                ForEach(AppSection.allCases) { section in
                    sectionStack(for: section)
                        .tabItem {
                            Label(section.title, systemImage: section.symbolName)
                        }
                }
            }
        #endif
    }

    private func sectionStack(for section: AppSection) -> some View {
        SectionStack(
            section: section,
            gardenStore: gardenStore,
            captureStore: captureStore,
            initialRoute: initialRoute
        )
        .modifier(CaptureSheetHost())
        .environment(captureStore)
        .environment(gardenStore)
        .task {
            guard !captureReady else {
                return
            }
            captureReady = true
            let store = CaptureStore(stores: appStores)
            store.onSaved = { gardenStore.refresh() }
            captureStore = store
        }
    }
}

struct SectionStack: View {
    let section: AppSection
    let gardenStore: GardenStore
    let captureStore: CaptureStore
    @State private var path: [SectionRoute]

    init(
        section: AppSection,
        gardenStore: GardenStore,
        captureStore: CaptureStore,
        initialRoute: SectionRoute? = nil
    ) {
        self.section = section
        self.gardenStore = gardenStore
        self.captureStore = captureStore
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationTitle(section.title)
                .navigationDestination(for: SectionRoute.self) { route in
                    SectionDetailView(route: route) { next in
                        path.append(next)
                    }
                    .croftScreenSurface()
                    .toolbar {
                        if case .planting(let plantingID) = route {
                            PlantingQuickActions(capture: captureStore, plantingID: plantingID)
                        }
                        CaptureMenu(capture: captureStore)
                    }
                    .environment(gardenStore)
                    .environment(captureStore)
                }
                .croftScreenSurface()
                .toolbar {
                    CaptureMenu(capture: captureStore)
                }
                .environment(gardenStore)
                .environment(captureStore)
        }
        .onChange(of: path, initial: true) { _, current in
            captureStore.visibleTarget = CaptureTargetResolver.target(for: current.last)
        }
        .onAppear {
            captureStore.visibleTarget = CaptureTargetResolver.target(for: path.last)
        }
    }

    @ViewBuilder private var home: some View {
        if section == .today {
            TodayView()
        } else {
            SectionHomeView(section: section) { route in
                path.append(route)
            }
        }
    }
}
