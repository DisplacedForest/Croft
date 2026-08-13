import Design
import SwiftUI

struct CroftShell: View {
    @State private var selection: AppSection? = .today

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
        SectionStack(section: section)
            .tint(section.domainColor)
    }
}

private struct SectionStack: View {
    let section: AppSection
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            home
                .navigationTitle(section.title)
                .navigationDestination(for: SectionRoute.self) { route in
                    SectionDetailView(route: route)
                }
                .background(Color.surfacePrimary)
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
