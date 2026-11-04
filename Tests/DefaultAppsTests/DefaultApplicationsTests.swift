import DefaultApps
import Foundation
import Testing
import UniformTypeIdentifiers

/// LaunchServices simulated, never the real setting of the Mac.
@Suite struct DefaultApplicationsTests {
    let me = URL(filePath: "/Applications/Example.app")
    let mail = InstalledApplication(
        url: URL(filePath: "/System/Applications/Mail.app"), bundleIdentifier: "com.apple.mail", name: "Mail")
    let installed = InstalledApplication(
        url: URL(filePath: "/Volumes/Builds/Example.app"), bundleIdentifier: "com.example.app", name: "Example")

    private func check(_ client: SimulatedDefaultApplications) -> DefaultApplicationCheck {
        DefaultApplicationCheck(client: client, applicationURL: me, bundleIdentifier: "com.example.app")
    }

    private func client(default app: InstalledApplication?) -> SimulatedDefaultApplications {
        SimulatedDefaultApplications(defaults: app.map { ["mailto": $0] } ?? [:])
    }

    @Test func theStatusNamesTheCurrentApp() async {
        #expect(await check(client(default: nil)).status(forScheme: "mailto") == .none)
        #expect(await check(client(default: mail)).status(forScheme: "mailto") == .other("Mail"))
        // Another copy of the app (a Debug build, the installed app): the same app for the user.
        #expect(await check(client(default: installed)).status(forScheme: "mailto") == .thisApp)
        let same = InstalledApplication(url: me, bundleIdentifier: nil, name: "Example")
        #expect(await check(client(default: same)).status(forScheme: "mailto") == .thisApp)
        #expect(await check(client(default: mail)).status(forScheme: "MAILTO") == .other("Mail"))
        #expect(DefaultApplicationStatus.thisApp.isThisApp && !DefaultApplicationStatus.unknown.isThisApp)
    }

    @Test func theUserChangingTheDefaultElsewhereIsSeenAtTheNextRead() async {
        let simulated = client(default: mail)
        #expect(await check(simulated).status(forScheme: "mailto") == .other("Mail"))
        simulated.setDefault(installed, forScheme: "mailto")
        #expect(await check(simulated).status(forScheme: "mailto") == .thisApp)
    }

    @Test func makingTheAppTheDefaultChangesTheStatusOrReportsTheRefusal() async throws {
        let simulated = SimulatedDefaultApplications(defaults: ["https": mail], installed: ["com.example.app": me])
        simulated.failNext(with: NSError(domain: NSOSStatusErrorDomain, code: -54))
        await #expect(throws: NSError.self) { try await check(simulated).makeDefault(forScheme: "https") }
        #expect(await check(simulated).status(forScheme: "https") == .other("Mail"))
        try await check(simulated).makeDefault(forScheme: "https")
        #expect(await check(simulated).status(forScheme: "https") == .thisApp)
    }

    @Test func contentTypesAndOpeningGoThroughTheSameClient() async throws {
        let simulated = SimulatedDefaultApplications(contentTypes: [UTType.html.identifier: mail], installed: ["com.apple.mail": mail.url])
        #expect(await simulated.defaultApplication(forContentType: .html) == mail)
        #expect(await simulated.defaultApplication(forContentType: .pdf) == nil)
        let url = try #require(await simulated.applicationURL(bundleIdentifier: "com.apple.mail"))
        try await simulated.openApplication(at: url)
        #expect(simulated.opened == [mail.url])
        simulated.setInstalled(nil, bundleIdentifier: "com.apple.mail")
        #expect(await simulated.applicationURL(bundleIdentifier: "com.apple.mail") == nil)
    }
}
