import Account
import AppAccount
import DesignSystem
import Env
import Models
import Network
import SwiftUI
import Timeline

struct SettingsTabs: View {
  @EnvironmentObject private var pushNotifications: PushNotificationsService
  @EnvironmentObject private var preferences: UserPreferences
  @EnvironmentObject private var client: Client
  @EnvironmentObject private var currentInstance: CurrentInstance
  @EnvironmentObject private var appAccountsManager: AppAccountsManager
  @EnvironmentObject private var theme: Theme

  @StateObject private var routerPath = RouterPath()

  @State private var addAccountSheetPresented = false

  @Binding var popToRootTab: Tab

  var body: some View {
    NavigationStack(path: $routerPath.path) {
      Form {
        appSection
        accountsSection
        generalSection
      }
      .scrollContentBackground(.hidden)
      .background(theme.secondaryBackgroundColor)
      .navigationTitle(Text("settings.title"))
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(theme.primaryBackgroundColor, for: .navigationBar)
      .withAppRouter()
      .withSheetDestinations(sheetDestinations: $routerPath.presentedSheet)
    }
    .onAppear {
      routerPath.client = client
    }
    .task {
      if appAccountsManager.currentAccount.oauthToken != nil {
        await currentInstance.fetchCurrentInstance()
      }
    }
    .withSafariRouter()
    .environmentObject(routerPath)
    .onChange(of: $popToRootTab.wrappedValue) { popToRootTab in
      if popToRootTab == .notifications {
        routerPath.path = []
      }
    }
  }

  private var accountsSection: some View {
    Section("settings.section.accounts") {
      ForEach(appAccountsManager.availableAccounts) { account in
        AppAccountView(viewModel: .init(appAccount: account))
      }
      .onDelete { indexSet in
        if let index = indexSet.first {
          let account = appAccountsManager.availableAccounts[index]
          if let token = account.oauthToken {
            Task {
              await pushNotifications.deleteSubscriptions(accounts: [.init(server: account.server, token: token)])
            }
          }
          appAccountsManager.delete(account: account)
        }
      }
      addAccountButton
    }
    .listRowBackground(theme.primaryBackgroundColor)
  }

  @ViewBuilder
  private var generalSection: some View {
    Section("settings.section.general") {
      NavigationLink(destination: PushNotificationsView()) {
        Label("settings.general.push-notifications", systemImage: "bell.and.waves.left.and.right")
      }
      if let instanceData = currentInstance.instance {
        NavigationLink(destination: InstanceInfoView(instance: instanceData)) {
          Label("settings.general.instance", systemImage: "server.rack")
        }
      }
      NavigationLink(destination: DisplaySettingsView()) {
        Label("settings.general.display", systemImage: "paintpalette")
      }
      NavigationLink(destination: remoteLocalTimelinesView) {
        Label("settings.general.remote-timelines", systemImage: "dot.radiowaves.right")
      }
      if !ProcessInfo.processInfo.isiOSAppOnMac {
        Picker(selection: $preferences.preferredBrowser) {
          ForEach(PreferredBrowser.allCases, id: \.rawValue) { browser in
            switch browser {
            case .inAppSafari:
              Text("settings.general.browser.in-app").tag(browser)
            case .safari:
              Text("settings.general.browser.system").tag(browser)
            }
          }
        } label: {
          Label("settings.general.browser", systemImage: "network")
        }
      }
    }
    .listRowBackground(theme.primaryBackgroundColor)
  }

  private var appSection: some View {
    Section {
      if !ProcessInfo.processInfo.isiOSAppOnMac {
        NavigationLink(destination: IconSelectorView()) {
          Label {
            Text("settings.app.icon")
          } icon: {
            if let icon = IconSelectorView.Icon(string: UIApplication.shared.alternateIconName ?? "AppIcon") {
              Image(uiImage: .init(named: icon.iconName)!)
                .resizable()
                .frame(width: 25, height: 25)
                .cornerRadius(4)
            }
          }
        }
      }

      Link(destination: URL(string: "https://github.com/Dimillian/IceCubesApp")!) {
        Label("settings.app.source", systemImage: "link")
      }
      .tint(theme.labelColor)

      NavigationLink(destination: SupportAppView()) {
        Label("settings.app.support", systemImage: "wand.and.stars")
      }
      
      if let reviewURL = URL(string: "https://apps.apple.com/app/id\(AppInfo.appStoreAppId)?action=write-review") {
        Link(destination: reviewURL) {
          Label("Rate Ice Cubes", systemImage: "link")
        }
        .tint(theme.labelColor)
      }
    } header: {
        Text("settings.section.app")
    } footer: {
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            Text("App Version: \(appVersion)").frame(maxWidth: .infinity, alignment: .center)
        }
    }
    .listRowBackground(theme.primaryBackgroundColor)
  }

  private var addAccountButton: some View {
    Button {
      addAccountSheetPresented.toggle()
    } label: {
      Text("settings.account.add")
    }
    .sheet(isPresented: $addAccountSheetPresented) {
      AddAccountView()
    }
  }

  private var remoteLocalTimelinesView: some View {
    Form {
      ForEach(preferences.remoteLocalTimelines, id: \.self) { server in
        Text(server)
      }.onDelete { indexes in
        if let index = indexes.first {
          _ = preferences.remoteLocalTimelines.remove(at: index)
        }
      }
      .listRowBackground(theme.primaryBackgroundColor)
      Button {
        routerPath.presentedSheet = .addRemoteLocalTimeline
      } label: {
        Label("settings.timeline.add", systemImage: "badge.plus.radiowaves.right")
      }
      .listRowBackground(theme.primaryBackgroundColor)
    }
    .navigationTitle("settings.general.remote-timelines")
    .scrollContentBackground(.hidden)
    .background(theme.secondaryBackgroundColor)
  }
}
