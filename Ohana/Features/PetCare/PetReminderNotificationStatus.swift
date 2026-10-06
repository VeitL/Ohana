import SwiftUI
import UserNotifications

/// Reads permission without prompting. Enabling a plan owns the permission request.
struct PetReminderNotificationStatus: View {
    @Environment(AppServices.self) private var appServices
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.ohanaAppLanguageCode) private var appLanguage
    @State private var denied = false

    var body: some View {
        Group {
            if denied {
                Label(PetCareExperienceCopy(l: L10n(appLanguage)).notificationsOff, systemImage: "bell.slash")
                    .font(.caption)
                    .foregroundStyle(Color.ohanaSecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("pet-reminder-notifications-off")
            }
        }
        .task(id: scenePhase) {
            denied = await appServices.userNotifications.authorizationStatus() == .denied
        }
    }
}
