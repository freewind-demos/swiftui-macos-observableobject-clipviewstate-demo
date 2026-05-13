import SwiftUI

// 这是 demo 里的 tab 枚举。
enum MainTab: String, CaseIterable, Identifiable {
  // 正常历史列表。
  case history

  // 收藏列表。
  case favorites

  // 回收站列表。
  case trash

  // 让 Picker 能直接用。
  var id: Self { self }

  // 供界面显示的标题。
  var title: String {
    // 按 case 返回可读标题。
    switch self {
    case .history:
      return "History"
    case .favorites:
      return "Favorites"
    case .trash:
      return "Trash"
    }
  }
}

// 这是“前台记事板”。
@MainActor
final class ClipViewState: ObservableObject {
  // 它引用真实数据仓库，但自己不拥有业务真相。
  let store: ClipStore

  // 当前选中了哪些条目。
  @Published var selectedIDs: Set<String>

  // 当前键盘/预览焦点在哪个条目上。
  @Published var focusedID: String?

  // 当前看哪个 tab。
  @Published var currentTab: MainTab

  // 当前搜索词是什么。
  @Published var searchQuery: String

  // 初始化时把 store 接进来。
  init(
    store: ClipStore,
    selectedIDs: Set<String> = [],
    focusedID: String? = nil,
    currentTab: MainTab = .history,
    searchQuery: String = ""
  ) {
    // 保存数据仓库引用。
    self.store = store

    // 写入初始选中态。
    self.selectedIDs = selectedIDs

    // 写入初始焦点。
    self.focusedID = focusedID

    // 写入初始 tab。
    self.currentTab = currentTab

    // 写入初始搜索词。
    self.searchQuery = searchQuery
  }

  // 这是“当前界面能看到什么”。
  var visibleItems: [ClipItem] {
    // 先按 tab 过滤。
    store.items
      .filter { item in
        // 不同 tab 看不同数据范围。
        switch currentTab {
        case .history:
          return !item.isTrashed
        case .favorites:
          return !item.isTrashed && item.favorite
        case .trash:
          return item.isTrashed
        }
      }
      .filter { item in
        // 搜索为空时不过滤。
        guard !searchQuery.isEmpty else {
          return true
        }

        // 否则按标题或内容模糊匹配。
        return item.title.localizedCaseInsensitiveContains(searchQuery)
          || item.body.localizedCaseInsensitiveContains(searchQuery)
      }
  }

  // 当前选中的条目集合。
  var selectedItems: [ClipItem] {
    // 只从当前可见项里取选中项。
    visibleItems.filter { selectedIDs.contains($0.id) }
  }

  // 当前真正聚焦的条目。
  var focusedItem: ClipItem? {
    // 先按 focusedID 找。
    if let focusedID {
      // 返回当前焦点命中的可见项。
      return visibleItems.first(where: { $0.id == focusedID })
    }

    // 没焦点时退化成第 1 个选中项。
    return selectedItems.first
  }

  // 统一修正选择态，避免 tab/search 变化后指向失效项。
  func normalizeSelection() {
    // 当前可见 id 集合。
    let visibleIDs = Set(visibleItems.map(\.id))

    // 把选中态裁剪到可见范围内。
    selectedIDs = selectedIDs.intersection(visibleIDs)

    // 焦点如果已经不可见，就清掉。
    if let focusedID, !visibleIDs.contains(focusedID) {
      self.focusedID = nil
    }

    // 没焦点时，优先落到选中项，否则落到首项。
    if focusedID == nil {
      focusedID = selectedItems.first?.id ?? visibleItems.first?.id
    }
  }

  // 选中指定条目。
  func select(_ id: String) {
    // 单选模式只保留 1 个 id。
    selectedIDs = [id]

    // 焦点跟着选中项走。
    focusedID = id
  }

  // 选中首个可见项。
  func selectFirstVisible() {
    // 没有可见项就清空状态。
    guard let first = visibleItems.first else {
      selectedIDs.removeAll()
      focusedID = nil
      return
    }

    // 让首项成为单选目标。
    select(first.id)
  }

  // 把焦点向前或向后移动。
  func moveFocus(by offset: Int) {
    // 没有可见项就直接返回。
    guard !visibleItems.isEmpty else {
      return
    }

    // 找到当前焦点索引；没有则从 0 开始。
    let currentIndex = visibleItems.firstIndex { $0.id == focusedID } ?? 0

    // 把结果限制在合法区间。
    let nextIndex = min(max(currentIndex + offset, 0), visibleItems.count - 1)

    // 取出目标 id。
    let nextID = visibleItems[nextIndex].id

    // 焦点移动时顺便收敛成单选。
    select(nextID)
  }

  // 套 1 个“会议”预设，模拟用户点了若干控件后的结果。
  func applyMeetingPreset() {
    // 回到 history。
    currentTab = .history

    // 搜索会议。
    searchQuery = "会议"

    // 修正焦点。
    normalizeSelection()

    // 自动选第 1 个可见项。
    selectFirstVisible()
  }

  // 套 1 个“收藏”预设。
  func applyFavoritesPreset() {
    // 切到收藏。
    currentTab = .favorites

    // 清空搜索词，避免干扰。
    searchQuery = ""

    // 修正焦点。
    normalizeSelection()

    // 自动选第 1 个可见项。
    selectFirstVisible()
  }

  // 套 1 个“回收站”预设。
  func applyTrashPreset() {
    // 切到回收站。
    currentTab = .trash

    // 清空搜索词。
    searchQuery = ""

    // 修正焦点。
    normalizeSelection()

    // 自动选第 1 个可见项。
    selectFirstVisible()
  }

  // 重置成 demo 初始状态。
  func resetDemo() {
    // 回到 history。
    currentTab = .history

    // 清空搜索词。
    searchQuery = ""

    // 直接选第 1 项。
    selectFirstVisible()
  }

  // 模拟后台任务返回建议搜索词。
  func applyRemoteSuggestion(query: String) {
    // 为了可见，强制回到 history。
    currentTab = .history

    // 写入后台回来的建议词。
    searchQuery = query

    // 修正焦点。
    normalizeSelection()

    // 自动选第 1 个可见项。
    selectFirstVisible()
  }
}
