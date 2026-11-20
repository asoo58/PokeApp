import SwiftUI

/// Écran de connexion Firebase (email + mot de passe, ou Google).
struct LoginView: View {
    @Bindable var auth: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Compte") {
                    TextField("Adresse e-mail", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("Mot de passe (6 caractères minimum)", text: $password)
                }

                if let error = auth.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }

                Section {
                    Button {
                        Task {
                            if isSignUp {
                                await auth.signUp(email: email, password: password)
                            } else {
                                await auth.signIn(email: email, password: password)
                            }
                        }
                    } label: {
                        Text(isSignUp ? "Créer un compte" : "Se connecter")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(email.isEmpty || password.count < 6 || auth.isBusy)

                    Button {
                        isSignUp.toggle()
                        auth.errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Déjà un compte ? Se connecter"
                                      : "Pas encore de compte ? S'inscrire")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(auth.isBusy)
                }

                Section {
                    Button {
                        Task {
                            await auth.signInWithGoogle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Continuer avec Google")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(auth.isBusy)
                } footer: {
                    Text("Connexion sécurisée via Firebase Authentication.")
                }
            }
            .navigationTitle("PokéApp")
        }
    }
}
