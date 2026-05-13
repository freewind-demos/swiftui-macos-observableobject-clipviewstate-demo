import SwiftUI

// 这是主界面。
struct ContentView: View {
  // 直接观察仓库，感知条目变化。
  @ObservedObject var store: ClipStore

  // 直接观察 UI 状态，感知选择态与查询态变化。
  @ObservedObject var uiState: ClipViewState

  // 这是局部 loading 标记，只为演示异步建议按钮。
  @State private var isLoadingSuggestion = false

  // 组织整体布局。
  var body: some View {
    // 用纵向布局包住标题与三栏内容。
    VStack(alignment: .leading, spacing: 16) {
      // 顶部说明卡。
      headerCard

      // 主体三栏：列表、预览、状态板。
      HStack(alignment: .top, spacing: 16) {
        // 左边展示“货架里当前可见什么”。
        shelfPanel

        // 中间展示“店员当前盯着哪件货”。
        previewPanel

        // 右边把状态对象直接摊开给你看。
        statePanel
      }
    }
    // 给页面留边距。
    .padding(20)
    // 设定窗口最小可读尺寸。
    .frame(minWidth: 1200, minHeight: 760)
    // 首次出现时补 1 次默认选择。
    .task {
      // 只有第一次无选中时才补首项。
      if uiState.selectedIDs.isEmpty {
        uiState.selectFirstVisible()
      }
    }
  }

  // 顶部讲清“仓库”和“记事板”的分工。
  private var headerCard: some View {
    // 用纵向卡片展示概念。
    VStack(alignment: .leading, spacing: 10) {
      // 主标题。
      Text("ClipViewState 是前台记事板，不是仓库货架")
        .font(.system(size: 26, weight: .bold))

      // 1 句结论。
      Text("ClipStore 放真实条目；ClipViewState 放当前 tab、搜索词、选中项、焦点项。谁改记事板，列表、预览、状态板一起变。")
        .foregroundStyle(.secondary)

      // 用 3 个小标签强化记忆。
      HStack(spacing: 10) {
        badge("ClipStore = 真数据")
        badge("ClipViewState = UI 查询态")
        badge("@Published = 改了就广播")
      }
    }
    // 卡片内边距。
    .padding(18)
    // 背景用系统材质，避免自定义风格过多。
    .background(.thinMaterial)
    // 补圆角。
    .clipShape(RoundedRectangle(cornerRadius: 16))
  }

  // 左栏：操作区 + 列表区。
  private var shelfPanel: some View {
    // 用卡片承载。
    VStack(alignment: .leading, spacing: 14) {
      // 左栏标题。
      Text("左栏：货架窗口")
        .font(.headline)

      // tab 切换。
      Picker("Tab", selection: $uiState.currentTab) {
        // 枚举所有 tab。
        ForEach(MainTab.allCases) { tab in
          // 显示标题并绑定值。
          Text(tab.title).tag(tab)
        }
      }
      // 用 segmented 更贴近原场景。
      .pickerStyle(.segmented)
      // tab 改了就修正选择态。
      .onChange(of: uiState.currentTab) { _, _ in
        uiState.normalizeSelection()
      }

      // 搜索框。
      TextField("输入关键词，例如 会议 / 报销", text: $uiState.searchQuery)
        .textFieldStyle(.roundedBorder)
        // 搜索词改了也要修正选择态。
        .onChange(of: uiState.searchQuery) { _, _ in
          uiState.normalizeSelection()
        }

      // 一排预设按钮，帮助你更快体会状态联动。
      HStack {
        Button("会议预设") {
          uiState.applyMeetingPreset()
        }

        Button("收藏预设") {
          uiState.applyFavoritesPreset()
        }

        Button("回收站预设") {
          uiState.applyTrashPreset()
        }
      }

      // 第二排动作按钮。
      HStack {
        Button("上一个") {
          uiState.moveFocus(by: -1)
        }

        Button("下一个") {
          uiState.moveFocus(by: 1)
        }

        Button("重置") {
          uiState.resetDemo()
        }
      }

      // 模拟后台线程给出建议搜索词。
      Button(isLoadingSuggestion ? "后台建议中..." : "模拟后台建议“报销”") {
        // 避免重复点击。
        guard !isLoadingSuggestion else {
          return
        }

        // 先置 loading。
        isLoadingSuggestion = true

        // 故意放到后台任务里，演示 @MainActor 回主线程更新。
        Task.detached {
          // 模拟网络等待。
          try? await Task.sleep(for: .milliseconds(800))

          // 回主 actor 改 uiState。
          await uiState.applyRemoteSuggestion(query: "报销")

          // 回主 actor 改局部 loading。
          await MainActor.run {
            isLoadingSuggestion = false
          }
        }
      }

      // 给出当前列表含义。
      Text("这里读的是 uiState.visibleItems。也就是：真数据在 store，怎么筛在 uiState。")
        .font(.footnote)
        .foregroundStyle(.secondary)

      // 可见条目列表。
      ScrollView {
        // 纵向排每 1 行。
        LazyVStack(spacing: 10) {
          // 遍历当前可见项。
          ForEach(uiState.visibleItems) { item in
            // 每行都是可点卡片。
            Button {
              uiState.select(item.id)
            } label: {
              itemRow(item: item)
            }
            // 去掉默认按钮样式。
            .buttonStyle(.plain)
          }
        }
      }
      // 给列表留出高度。
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // 左栏内边距。
    .padding(18)
    // 卡片背景。
    .background(.regularMaterial)
    // 圆角。
    .clipShape(RoundedRectangle(cornerRadius: 16))
    // 固定一个舒服的宽度。
    .frame(width: 360)
  }

  // 中栏：预览区。
  private var previewPanel: some View {
    // 用卡片承载内容。
    VStack(alignment: .leading, spacing: 14) {
      // 标题。
      Text("中栏：店员手里的那件货")
        .font(.headline)

      // 如果有聚焦项，就展示细节。
      if let item = uiState.focusedItem {
        // 标题与标记行。
        HStack {
          Text(item.title)
            .font(.title2.weight(.semibold))

          if item.favorite {
            Text("已收藏")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.yellow.opacity(0.2))
              .clipShape(Capsule())
          }

          if item.isTrashed {
            Text("回收站")
              .font(.caption)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.red.opacity(0.15))
              .clipShape(Capsule())
          }
        }

        // 详情正文。
        Text(item.body)
          .font(.body)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(14)
          .background(Color.primary.opacity(0.04))
          .clipShape(RoundedRectangle(cornerRadius: 12))

        // 用 1 个按钮演示 store 变更。
        Button("切收藏标记") {
          store.toggleFavorite(id: item.id)
          uiState.normalizeSelection()
        }

        // 直接解释这一刻发生了什么。
        insightCard(
          title: "你刚刚体验到的事",
          body: "点左栏条目时，改的是 uiState.selectedIDs / focusedID。点“切收藏标记”时，改的是 store.items。两边一分工，界面就不会把数据层和选择层揉成一团。"
        )
      } else {
        // 没有聚焦项时提示用户先操作。
        insightCard(
          title: "当前没有焦点项",
          body: "这通常是因为当前 tab + 搜索词把结果筛空了。改的依然是记事板，不是货架。"
        )
      }

      // 补 1 段关于 final class 的直觉解释。
      insightCard(
        title: "为什么这里用 final class",
        body: "因为左栏、中栏、右栏要共享同 1 份可变状态。它不是一次性快照，而是整块会被大家一起盯着的白板。"
      )
    }
    // 中栏内边距。
    .padding(18)
    // 卡片背景。
    .background(.regularMaterial)
    // 圆角。
    .clipShape(RoundedRectangle(cornerRadius: 16))
    // 占主空间。
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // 右栏：状态板。
  private var statePanel: some View {
    // 用纵向栈展示实时字段。
    VStack(alignment: .leading, spacing: 14) {
      // 标题。
      Text("右栏：把 ClipViewState 原文贴墙上")
        .font(.headline)

      // 解释 ObservableObject 的体感。
      Text("这些值都来自同 1 个 ObservableObject。任意 1 个 @Published 字段变，整面墙会一起刷新。")
        .font(.footnote)
        .foregroundStyle(.secondary)

      // 逐项展示关键字段。
      stateRow(name: "currentTab", value: uiState.currentTab.rawValue)
      stateRow(name: "searchQuery", value: uiState.searchQuery.isEmpty ? "\"\"" : uiState.searchQuery)
      stateRow(name: "selectedIDs", value: uiState.selectedIDs.sorted().description)
      stateRow(name: "focusedID", value: uiState.focusedID ?? "nil")
      stateRow(name: "visibleItems.count", value: "\(uiState.visibleItems.count)")
      stateRow(name: "selectedItems.count", value: "\(uiState.selectedItems.count)")
      stateRow(name: "store.items.count", value: "\(store.items.count)")

      // 额外贴 1 段 @MainActor 说明。
      insightCard(
        title: "@MainActor 在这里的作用",
        body: "后台建议按钮故意在 detached task 里 sleep，再 await 回 uiState。也就是说：异步结果来了，真正改 UI 状态时仍会切回主线程。"
      )

      // 再贴 1 段为何要分层。
      insightCard(
        title: "别把什么都塞进 View",
        body: "如果把 tab、搜索、选中、焦点都散在多个 View 的 @State 里，联动会很快失控。把它们收口到 ClipViewState 后，View 负责展示，状态对象负责协调。"
      )

      // 让右栏占满高度。
      Spacer(minLength: 0)
    }
    // 右栏内边距。
    .padding(18)
    // 卡片背景。
    .background(.regularMaterial)
    // 圆角。
    .clipShape(RoundedRectangle(cornerRadius: 16))
    // 固定右栏宽度。
    .frame(width: 330)
  }

  // 构造单行条目卡片。
  private func itemRow(item: ClipItem) -> some View {
    // 判断这一行是否被当前 uiState 选中。
    let isSelected = uiState.selectedIDs.contains(item.id)

    // 返回 1 个纵向信息块。
    return VStack(alignment: .leading, spacing: 6) {
      // 标题与角标。
      HStack {
        Text(item.title)
          .font(.headline)

        if item.favorite {
          Text("收藏")
            .font(.caption2)
            .foregroundStyle(.orange)
        }

        if item.isTrashed {
          Text("回收站")
            .font(.caption2)
            .foregroundStyle(.red)
        }

        Spacer(minLength: 0)
      }

      // 内容摘要。
      Text(item.body)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .lineLimit(2)

      // 补 1 行技术解说。
      Text(isSelected ? "当前行已命中 selectedIDs" : "点我会改 uiState.select(...)")
        .font(.caption)
        .foregroundStyle(isSelected ? .blue : .secondary)
    }
    // 卡片内边距。
    .padding(12)
    // 选中时高亮背景。
    .background(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.03))
    // 补边框，让选择态更清楚。
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
    )
    // 圆角。
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // 构造右栏状态行。
  private func stateRow(name: String, value: String) -> some View {
    // 用纵向展示名字和值。
    VStack(alignment: .leading, spacing: 4) {
      // 字段名。
      Text(name)
        .font(.caption)
        .foregroundStyle(.secondary)

      // 字段值。
      Text(value)
        .font(.system(.body, design: .monospaced))
        .textSelection(.enabled)
    }
  }

  // 构造说明卡片。
  private func insightCard(title: String, body: String) -> some View {
    // 用纵向排标题和正文。
    VStack(alignment: .leading, spacing: 8) {
      // 卡片标题。
      Text(title)
        .font(.headline)

      // 卡片正文。
      Text(body)
        .foregroundStyle(.secondary)
    }
    // 卡片内边距。
    .padding(14)
    // 卡片背景。
    .background(Color.primary.opacity(0.04))
    // 圆角。
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  // 顶部小标签。
  private func badge(_ text: String) -> some View {
    // 用胶囊承载短语。
    Text(text)
      .font(.caption.weight(.medium))
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.primary.opacity(0.06))
      .clipShape(Capsule())
  }
}
