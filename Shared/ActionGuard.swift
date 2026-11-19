import Foundation

/// Exécute une action au plus une fois pendant une fenêtre de temps.
///
/// Sert à absorber les double-clics, les tapes frénétiques et les événements
/// dupliqués : plusieurs clics rapprochés produisent exactement le même
/// résultat qu'un seul.
///
/// Type valeur (et non une classe) : sa désallocation ne passe pas par
/// `swift_task_deinitOnExecutorImpl`, qui plante sur le runtime iOS 26.3
/// lorsque SwiftUI recrée rapidement un view model (taps multiples sur
/// l'icône de l'app, par exemple).
struct DebouncedAction {
    private let interval: TimeInterval
    private let now: () -> Date
    private var lastExecutions: [String: Date] = [:]

    /// - Parameters:
    ///   - interval: fenêtre d'ignorance après une exécution (en secondes).
    ///   - now: fonction de date injectable pour rendre le comportement testable.
    init(interval: TimeInterval = 0.35, now: @escaping () -> Date = Date.init) {
        self.interval = interval
        self.now = now
    }

    /// Tente d'exécuter `action`.
    ///
    /// La clé permet d'avoir une fenêtre séparée par élément : taper deux
    /// Pokémon différents rapidement ne doit pas bloquer le second.
    ///
    /// - Returns: `true` si l'action a été exécutée, `false` si le clic a été ignoré.
    @discardableResult
    mutating func run(key: String = "default", _ action: () -> Void) -> Bool {
        let current = now()

        if let last = lastExecutions[key], current.timeIntervalSince(last) < interval {
            return false
        }

        lastExecutions[key] = current
        action()
        return true
    }

    /// Autorise à nouveau une exécution immédiate (utile après une erreur réseau).
    mutating func reset(key: String? = nil) {
        if let key {
            lastExecutions.removeValue(forKey: key)
        } else {
            lastExecutions.removeAll()
        }
    }
}

/// Empêche deux tâches asynchrones identiques de tourner en parallèle.
///
/// Contrairement à `DebouncedAction`, ce garde ne se base pas sur l'horloge :
/// il ignore tous les appels tant que le premier n'est pas terminé.
final class SingleFlightAction: @unchecked Sendable {
    private let lock = NSLock()
    private var isRunning = false

    /// Le verrou est manipulé dans une méthode synchrone : pas d'appel à
    /// `lock()`/`unlock()` depuis un contexte `async` (interdit en Swift 6).
    private func withState<T>(_ body: (inout Bool) -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body(&isRunning)
    }

    /// Exécute `operation` seulement si aucune opération n'est déjà en cours.
    func run(_ operation: @escaping () async -> Void) async {
        let acquired = withState { flag -> Bool in
            guard !flag else { return false }
            flag = true
            return true
        }
        guard acquired else { return }

        defer { withState { $0 = false } }
        await operation()
    }

    /// Indique si une opération est actuellement en cours.
    var running: Bool { withState { $0 } }
}
