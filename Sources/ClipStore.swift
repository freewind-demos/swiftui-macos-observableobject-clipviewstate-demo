import SwiftUI

// 这是“仓库货架”。
@MainActor
final class ClipStore: ObservableObject {
  // 真数据都放在这里。
  @Published var items: [ClipItem]

  // 初始化时注入条目数组。
  init(items: [ClipItem]) {
    // 保存初始数据。
    self.items = items
  }

  // 切换收藏状态，用来演示“数据层变化”。
  func toggleFavorite(id: String) {
    // 找到目标索引。
    guard let index = items.firstIndex(where: { $0.id == id }) else {
      // 没找到就直接返回。
      return
    }

    // 原地翻转收藏值。
    items[index].favorite.toggle()
  }

  // 生成 demo 初始数据。
  static func makeDemoStore() -> ClipStore {
    // 用几条不同状态的样本构造 1 个 store。
    ClipStore(
      items: [
        ClipItem(
          id: "meeting",
          title: "会议纪要",
          body: "周三评审：主菜单保留，右侧预览支持直接编辑。",
          favorite: true,
          isTrashed: false
        ),
        ClipItem(
          id: "invoice",
          title: "报销单",
          body: "差旅报销需要上传发票与行程单。",
          favorite: false,
          isTrashed: false
        ),
        ClipItem(
          id: "design",
          title: "设计草图",
          body: "新 popup 先保留搜索栏，再决定是否去掉内部热键。",
          favorite: true,
          isTrashed: false
        ),
        ClipItem(
          id: "trash-note",
          title: "旧临时文本",
          body: "这条已经进入回收站，只在 Trash 里出现。",
          favorite: false,
          isTrashed: true
        ),
      ]
    )
  }
}
