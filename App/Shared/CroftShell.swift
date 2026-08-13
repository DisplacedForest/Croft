import Design
import SwiftUI

struct CroftShell: View {
    @State private var selection: AppSection?
    @State private var gardenStore: GardenStore
    @Environment(\.appStores) private var appStores
    @State private var captureStore = CaptureStore(stores: nil)
    @State private var captureReady = false
    private let initialRoute: SectionRoute?

    init(
        gardenStore: GardenStore? = nil,
        initialSection: AppSection = .today,
        initialRoute: SectionRoute? = nil
    ) {
        _selection = State(initialValue: initialSection)
        _gardenStore = State(initialValue: gardenStore ?? .live())
        self.initialRoute = initialRoute
    }

    var body: some View {
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
        .toolbar {
            CaptureMenu()
                .environment(captureStore)
        }
        .modifier(CaptureSheetHost())
        .environment(captureStore)
        .environment(gardenStore)
        .tint(section.domainColor)
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
    @State private var path: NavigationPath

    init(
        section: AppSection,
        gardenStore: GardenStore,
        captureStore: CaptureStore,
        initialRoute: SectionRoute? = nil
    ) {
        self.section = section
        self.gardenStore = gardenStore
        self.captureStore = captureStore
        var path = NavigationPath()
        if let initialRoute {
            path.append(initialRoute)
        }
        _path = State(initialValue: path)
    }

    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationTitle(section.title)
                .navigationDestination(for: SectionRoute.self) { route in
                    SectionDetailView(route: route) { next in
                        path.append(next)
                    }
                    .environment(gardenStore)
                    .environment(captureStore)
                }
                .background(Color.surfacePrimary)
                .environment(gardenStore)
                .environment(captureStore)
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
