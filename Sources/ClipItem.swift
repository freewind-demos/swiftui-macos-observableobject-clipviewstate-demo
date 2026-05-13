import Foundation

// 这是 demo 里的最小条目模型。
struct ClipItem: Identifiable, Hashable {
  // 用稳定 id 模拟真实项目里的条目主键。
  let id: String

  // 标题用于左侧列表显示。
  let title: String

  // 详情用于中间预览区显示。
  let body: String

  // 是否已收藏。
  var favorite: Bool

  // 是否已进回收站。
  var isTrashed: Bool
}
