# 验证记录 · 2026-09-12

环境：MacBook Pro / Apple M4 / Mac16,1，macOS 26.6.2，Swift 6.3.3。

## 已完成

- 非沙箱实读 HID 传感器：设备打开成功，report 1 返回 `[1, 122, 0]`，对应 122°。
- `bash scripts/test.sh`：9 项测试通过，0 失败、0 跳过。包含真实 Metal GPU 测试；另一次沙箱运行因无法访问 Metal 跳过 GPU 测试，该次不计入 GPU 验收。
- `bash scripts/build-app.sh`：release 编译、本机 ad-hoc 签名、`codesign --verify --deep --strict` 与 Info.plist 验证通过。
- 最终 app 执行 `--self-check`：包内 shader 资源与真实 Metal pipeline 初始化通过。
- GUI：打包应用实际启动，窗口布局与按钮正常；用户授权后初次构建显示实时 122°，收到桌面帧后预览按钮可用。
- 两位独立 Agent 完成对抗性审查并复查：修复设置被效果覆盖、菜单追踪期间 watchdog 暂停，以及构建资源目录问题；补充锁屏通知和首帧超时保护。

## 需要实际操作确认

- 最终构建重签名后的屏幕录制授权刷新。
- 实际连续开合时的感知延迟、平滑程度与开盖恢复。
- 预览期间没有递归捕获；菜单设置可见；⌘⇧Esc 全局暂停。
- 真正睡眠/唤醒、锁屏/解锁及外接显示器变化后的行为。

上述人工项目不能用 GPU 单元测试或读取一次传感器替代。未进行续航测试、HDR 匹配或不同 Mac 型号兼容性验收。
