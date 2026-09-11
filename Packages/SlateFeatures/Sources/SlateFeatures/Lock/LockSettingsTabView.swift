import SwiftUI
import SlateUI

/// Contenu de l'onglet "Verrouillage" des reglages (design P4, artboard A').
///
/// **Portee assumee, a signaler explicitement** : aucune fenetre de reglages
/// n'existe encore dans le code (elle est le sujet de la Phase 13) -- cette vue est
/// donc le contenu STRICT NECESSAIRE de l'onglet, prete a etre inseree dans une
/// `TabView`/`Settings` scene une fois cette fenetre construite. Elle n'est
/// deliberement PAS branchee dans `App/SlateApp.swift` (hors perimetre de cet agent,
/// voir `docs/12_verrouillage.md`).
///
/// **Ecart assume sur "Deverrouillage : Touch ID"** : le design montre un bouton a
/// bascule interactif, mais `LockService` n'expose aucun moyen de changer
/// `isBiometricsAllowed` SANS re-fournir le mot de passe en clair (`setPassword`,
/// seul point d'ecriture -- volontairement, pour ne jamais laisser un mot de passe en
/// clair transiter ailleurs qu'a sa definition). Rendre ce reglage desactive et
/// lisible seulement, plutot que de fabriquer une fausse interactivite qui ne
/// persisterait rien, est le choix honnete ; le vrai reglage reste modifiable via
/// "Modifier..." (redefinition complete du mot de passe).
public struct LockSettingsTabView: View {
    @Environment(\.lockService) private var lockService
    @AppStorage("lock.autoRelockThresholdSeconds") private var autoRelockThresholdSeconds: Double = 300
    @State private var isSetPasswordSheetPresented = false

    public init() {}

    public var body: some View {
        Form {
            LabeledContent(String(localized: "lock.settings.password.label", bundle: .module)) {
                HStack(spacing: Spacing.sm) {
                    Button(passwordButtonTitle) { isSetPasswordSheetPresented = true }
                    if lockService.isPasswordSet {
                        Text(String(localized: "lock.settings.password.set", bundle: .module))
                            .slateFont(SlateFont.caption)
                            .foregroundStyle(SlateColor.textSecondary)
                    }
                }
            }

            if lockService.isBiometricsAvailable {
                LabeledContent(String(localized: "lock.settings.unlock.label", bundle: .module)) {
                    Toggle(
                        String(localized: "lock.settings.unlock.touchID", bundle: .module),
                        isOn: .constant(lockService.isBiometricsAllowed)
                    )
                    .toggleStyle(.switch)
                    .disabled(true)
                }
            }

            LabeledContent(String(localized: "lock.settings.relock.label", bundle: .module)) {
                Picker(
                    String(localized: "lock.settings.relock.label", bundle: .module),
                    selection: $autoRelockThresholdSeconds
                ) {
                    ForEach(Self.relockOptions, id: \.seconds) { option in
                        Text(option.label).tag(option.seconds)
                    }
                }
                .labelsHidden()
            }
        }
        .padding(Spacing.lg)
        .frame(width: 460)
        .sheet(isPresented: $isSetPasswordSheetPresented) {
            SetPasswordSheet(
                isBiometricsAvailable: lockService.isBiometricsAvailable,
                onSubmit: { password, hint, allowBiometrics in
                    let succeeded = try? lockService.setPassword(password, hint: hint, allowBiometrics: allowBiometrics)
                    guard succeeded != nil else { return false }
                    isSetPasswordSheetPresented = false
                    return true
                },
                onCancel: { isSetPasswordSheetPresented = false }
            )
        }
    }

    private var passwordButtonTitle: String {
        lockService.isPasswordSet
            ? String(localized: "lock.settings.password.change", bundle: .module)
            : String(localized: "lock.settings.password.define", bundle: .module)
    }

    private static let relockOptions: [(seconds: Double, label: String)] = [
        (60, String(localized: "lock.settings.relock.oneMinute", bundle: .module)),
        (300, String(localized: "lock.settings.relock.fiveMinutes", bundle: .module)),
        (900, String(localized: "lock.settings.relock.fifteenMinutes", bundle: .module))
    ]
}

#Preview("LockSettingsTabView") {
    LockSettingsTabView()
}
