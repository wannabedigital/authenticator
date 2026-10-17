import SwiftUI

struct EditAccountView: View {
    @Environment(VaultStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let account: OTPAccount
    let profileID: Profile.ID

    @State private var issuer: String
    @State private var name: String

    init(account: OTPAccount, profileID: Profile.ID) {
        self.account = account
        self.profileID = profileID
        _issuer = State(initialValue: account.issuer)
        _name = State(initialValue: account.name)
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("Аккаунт") {
                    TextField("Сервис", text: $issuer)
                    TextField("Аккаунт", text: $name)
                }
            }
            .formStyle(.grouped)
            .clippedAboveSheetFooter()

            SheetFooter(
                confirmTitle: "Сохранить",
                canConfirm: !(issuer.trimmed.isEmpty && name.trimmed.isEmpty)
            ) {
                store.renameAccount(account.id, in: profileID, issuer: issuer.trimmed, name: name.trimmed)
                dismiss()
            }
        }
        .frame(width: 400)
    }
}
