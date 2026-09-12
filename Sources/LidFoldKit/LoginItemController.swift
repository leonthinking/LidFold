import Combine
import ServiceManagement

protocol LoginItemService {
    var status: SMAppService.Status { get }
    func register() throws
    func unregister() async throws
}

struct SystemLoginItemService: LoginItemService {
    var status: SMAppService.Status { SMAppService.mainApp.status }
    func register() throws { try SMAppService.mainApp.register() }
    func unregister() async throws { try await SMAppService.mainApp.unregister() }
}

final class LoginItemController: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var busy = false
    @Published private(set) var error: String?
    private let service: LoginItemService

    init(service: LoginItemService = SystemLoginItemService()) {
        self.service = service
        status = service.status
    }

    var registered: Bool { status == .enabled || status == .requiresApproval }

    func refresh() { status = service.status }

    @MainActor func setEnabled(_ enabled: Bool) async {
        guard !busy else { return }
        busy = true
        error = nil
        defer { refresh(); busy = false }
        do {
            if enabled {
                if service.status != .enabled && service.status != .requiresApproval { try service.register() }
            } else if service.status == .enabled || service.status == .requiresApproval {
                try await service.unregister()
            }
        } catch { self.error = "无法更新登录项：\(error.localizedDescription)" }
    }

    func openSystemSettings() { SMAppService.openSystemSettingsLoginItems() }
}
