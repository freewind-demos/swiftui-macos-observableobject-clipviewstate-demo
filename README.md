# SwiftUI macOS ObservableObject ClipViewState Demo

## 简介

这是 1 个 macOS SwiftUI demo，专门演示 `@MainActor final class ClipViewState: ObservableObject { @Published ... }` 这套结构到底在干嘛。

你会看到 3 层东西一起工作：

1. `ClipStore`：像仓库货架，放真实数据。
2. `ClipViewState`：像前台记事板，只记“现在界面怎么看这批数据”。
3. SwiftUI View：像店员看到的屏幕，谁改了记事板，整个界面就一起同步。

## 快速开始

### 环境要求

- macOS 14+
- Xcode 15+
- XcodeGen

### 运行

```bash
cd /Users/peng.li/workspace/freewind-demos/swiftui-macos-observableobject-clipviewstate-demo

# 生成工程
xcodegen generate

# 编译
./scripts/build.sh

# 用 Xcode 打开
open ClipViewStateDemo.xcodeproj
```

### 开发循环

```bash
cd /Users/peng.li/workspace/freewind-demos/swiftui-macos-observableobject-clipviewstate-demo
./dev.sh
```

如果装了 `fswatch`，它会监听源码变更并自动重编、重启 app。

## 注意事项

- 这个 demo 故意把代码压到最少，只保留理解结构必需的部分。
- `ClipStore` 放“数据本体”。
- `ClipViewState` 不落盘、不碰文件系统、不做业务编排，只管界面查询态和选择态。

## 教程

### 1. 这套结构在解决什么问题

如果把“条目数据”“当前 tab”“搜索词”“当前选中项”“焦点项”全塞进 View：

- 状态会散
- 多个 View 容易各改各的
- 预览区、列表区、状态区容易不同步

所以常见做法是拆两层：

1. `ClipStore`
   放条目数组这种“业务数据”。
2. `ClipViewState`
   放 `selectedIDs`、`focusedID`、`currentTab`、`searchQuery` 这种“界面怎么看数据”的状态。

### 2. `@MainActor` 是干嘛

它的意思是：这个对象上的读写，都应该回主线程。

因为 SwiftUI 界面刷新本来就在主线程，所以：

- 用户点按钮改 `selectedIDs`
- 后台任务回调后改 `searchQuery`

都统一回主线程，更稳。

demo 里有个按钮会先在后台等 0.8 秒，再 `await uiState.applyRemoteSuggestion(query: "报销")`。

因为 `ClipViewState` 标了 `@MainActor`，这个更新会自动切回主线程执行。

### 3. `final class` 是干嘛

这里需要“同一个可变对象”被多个 View 共享。

如果它是 `struct`：

- 改一份可能只是改副本
- 多视图共享会别扭

用 `final class` 后：

- 大家盯着同一块“前台记事板”
- 左边列表选中变化
- 右边预览和右侧状态板立刻一起变

`final` 还顺便表达：这个对象不打算被继承，语义更收口。

### 4. `ObservableObject` 是干嘛

它像一个“会广播的状态容器”。

SwiftUI 视图订阅它后，只要对象里关键字段变化，界面就会自动刷新。

这里的关键不是“自动刷新”四个字本身，而是：

- 列表区
- 预览区
- 调试状态区

都能盯同一个对象，不用手搓通知链。

### 5. `@Published` 是干嘛

`@Published` 像“这个字段一改，就立刻摇铃通知”。

demo 里这些字段都用了它：

- `selectedIDs`
- `focusedID`
- `currentTab`
- `searchQuery`

比如你在列表里点“会议纪要”：

1. `uiState.select("meeting")`
2. `selectedIDs` 变了
3. `focusedID` 也变了
4. 列表高亮变
5. 预览内容变
6. 右侧状态板里的值也变

这就是 `ObservableObject + @Published` 的实际体感。

### 6. 为什么 `ClipViewState` 里要持有 `store`

因为它要基于真实数据，算出“当前界面可见什么”。

比如：

- 当前 tab 是 `favorites`
- 搜索词是 `会议`

那 `visibleItems` 就会从 `store.items` 里筛出“收藏且命中会议”的条目。

所以 `store` 像货架，`uiState` 像前台店员手上的筛选板。

货架没变，前台板子一变，看到的商品就变。

### 7. demo 里的生动类比

把整个 app 想成 1 家便利店：

- `ClipStore`：仓库货架，真货都在这里。
- `ClipViewState`：收银台记事板，写着“现在看收藏区”“搜索会议”“当前盯着哪件商品”。
- 左边列表：货架窗口。
- 中间预览：店员手里正拿着看的那件商品。
- 右边状态板：把记事板原文直接投在墙上。

你改的不是货本身，而是“店员现在怎么看货”时，最适合放在 `ClipViewState`。

### 8. 关键代码解读

先看核心骨架：

```swift
@MainActor
final class ClipViewState: ObservableObject {
  let store: ClipStore

  @Published var selectedIDs: Set<String>
  @Published var focusedID: String?
  @Published var currentTab: MainTab
  @Published var searchQuery: String
}
```

它表达的是：

1. 这是共享引用对象
2. 这是 UI 状态对象
3. 这些字段变化后要驱动界面刷新
4. 这些变化必须在主线程上发生

再看派生查询：

```swift
var visibleItems: [ClipItem] {
  store.items
    .filter { ...tab... }
    .filter { ...search... }
}
```

意思是：

- 真数据在 `store`
- 当前怎么看数据，在 `uiState`
- View 不自己散写筛选逻辑，只读 `visibleItems`

再看动作入口：

```swift
func select(_ id: String) {
  selectedIDs = [id]
  focusedID = id
}
```

意思是：

- View 不直接乱改多个字段
- 交互动作走 `uiState` 方法收口

## 操作

1. 运行 app。
2. 点左侧任意条目。
3. 看中间预览和右侧状态板一起变。
4. 切换 `History / Favorites / Trash`。
5. 改搜索词。
6. 点“模拟后台建议报销”，体会 `@MainActor` 把异步回调收回 UI 线程。
7. 点“切收藏标记”，体会 `store` 变后，`uiState.visibleItems` 也跟着重算。
