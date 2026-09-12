public enum RelaunchHandoff {
    /// The successor must be able to claim process-exclusive resources before
    /// the predecessor exits. A failed launch restores the current process.
    public static func start(release: () -> Void,
                             launch: (@escaping (Error?) -> Void) -> Void,
                             restore: @escaping () -> Void,
                             terminate: @escaping () -> Void,
                             onError: @escaping (Error) -> Void) {
        release()
        launch { error in
            if let error {
                restore()
                onError(error)
            } else {
                terminate()
            }
        }
    }
}
