import SwiftUI

// 这是 demo 的应用入口。
@main
struct ClipViewStateDemoApp: App {
  // 用 StateObject 持有 1 份共享 store。
  @StateObject private var store: ClipStore

  // 用 StateObject 持有 1 份共享 uiState。
  @StateObject private var uiState: ClipViewState

  // 先手动组装依赖，保证二者引用同 1 份 store。
  init() {
    // 先创建数据仓库。
    let store = ClipStore.makeDemoStore()

    // 把同 1 份 store 注入给属性包装器。
    _store = StateObject(wrappedValue: store)

    // 再创建 UI 状态对象。
    _uiState = StateObject(wrappedValue: ClipViewState(store: store))
  }

  // 定义主窗口。
  var body: some Scene {
    // 使用单窗口承载 demo。
    Window("ClipViewState Demo", id: "main") {
      // 把 store 与 uiState 一起传入内容视图。
      ContentView(store: store, uiState: uiState)
    }
    // 给个更舒服的默认尺寸。
    .defaultSize(width: 1320, height: 860)
  }
}
