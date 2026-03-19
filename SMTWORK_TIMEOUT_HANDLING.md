# SMTWork 超时处理机制 - 暂停队列模式

## 概述

当串口设备在指定超时时间内**未返回期望的响应**时，工作队列将**暂停处理**，而不是自动跳过到下一项。这确保了工作的完整性和可靠性。

## 关键行为变化

### 旧行为（已修改）
- ❌ 超时发生 → 自动跳过当前项 → 继续处理下一项
- 问题：未完成的工作被隐性忽略，导致生产数据不完整

### 新行为（已实现）
- ✅ 超时发生 → **暂停队列** → 等待手动干预
- 优势：工作必须显式处理（重试或跳过），确保没有"无声失败"

## 信号系统

### `queuePaused(int itemIndex, const QString &command)`
当队列因超时而暂停时触发，包含：
- `itemIndex`：失败的工作项索引
- `command`：失败的命令名称

使用示例：
```cpp
connect(&smtWork, QOverload<int, const QString &>::of(&SMTWork::queuePaused),
        this, [](int idx, const QString &cmd) {
    qWarning() << "工作队列在项目" << idx << "暂停，命令：" << cmd;
    // 可在此处弹出对话框或发送警报
});
```

## 手动恢复方法

### 1. 重试当前项 - `retryCurrentItem()`
重新发送相同命令给串口设备

```cpp
// UI 中的"重试"按钮点击处理
void onRetryButtonClicked() {
    smtWork.retryCurrentItem();
    qDebug() << "正在重试项目...";
}
```

**流程：**
1. 清除 `m_paused` 标志
2. 重新创建超时定时器
3. 重新发送命令到串口
4. 等待新的响应

### 2. 跳过当前项 - `skipCurrentItem()`
将当前失败项标记为已完成，继续处理队列中的下一项

```cpp
// UI 中的"跳过"按钮点击处理
void onSkipButtonClicked() {
    smtWork.skipCurrentItem();
    qDebug() << "已跳过失败项，继续队列处理...";
}
```

**流程：**
1. 清除 `m_paused` 标志
2. 停止当前项的超时定时器
3. 增加 `m_currentWorkItemIndex` 到下一项
4. 继续处理队列

## 完整使用示例

```cpp
// 初始化
SMTWork smtWork;
SerialPortManager serialPortManager;
smtWork.setSerialPortManager(&serialPortManager);

// 连接超时信号
connect(&smtWork, QOverload<int, const QString &>::of(&SMTWork::queuePaused),
        this, [this](int idx, const QString &cmd) {
    qCritical() << "[主程序] 工作项" << idx << "超时:" << cmd;
    
    // 示例：自动弹出对话框让用户选择
    int ret = QMessageBox::warning(nullptr, "工作超时",
        QString("项目 %1 超时:\n%2\n\n选择操作:").arg(idx).arg(cmd),
        QMessageBox::Retry | QMessageBox::Skip);
    
    if (ret == QMessageBox::Retry) {
        smtWork.retryCurrentItem();
    } else {
        smtWork.skipCurrentItem();
    }
});

// 添加任务
smtWork.addWorkItem("MOVE_TO_POS_1", "ok");    // 移动到位置1，期望响应 "ok"
smtWork.addWorkItem("PICK_COMPONENT", "ok");   // 拾取组件
smtWork.addWorkItem("PLACE_COMPONENT", "ok");  // 放置组件

// 启动队列处理
smtWork.start();
```

## 状态流程图

```
    ┌─────────────────────────┐
    │  启动工作队列           │
    │  (队列非空)             │
    └────────────┬────────────┘
                 │
                 ▼
    ┌─────────────────────────┐
    │  发送命令到串口         │
    │  启动超时定时器(5s)     │
    │  m_waitingForResponse=true
    └────────────┬────────────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    ✓ 收到期望     ✗ 超时或不符
      响应           │
        │            ▼
        │    ┌──────────────────────┐
        │    │  发出 timeoutOccurred │
        │    │  m_paused = true      │
        │    │  发出 queuePaused信号 │
        │    └─────────┬─────────────┘
        │              │
        │              ▼
        │         ┌─────────────────┐
        │         │  等待用户干预    │
        │         │  (UI处理)       │
        │         └────┬────────┬───┘
        │              │        │
        │              ▼        ▼
        │        重试    or    跳过
        │         │              │
        │         └──────┬───────┘
        │                │
        ▼                ▼
    ┌──────────────────────────┐
    │  m_currentWorkItemIndex++ │
    │  继续下一项              │
    └─────────────┬────────────┘
                  │
         ┌────────┴────────┐
         │                 │
    ▼ (有下一项)   ▼ (无下一项)
  继续循环      发出 workQueueCompleted
                  队列结束
```

## 与其他部分的集成

### SerialPortManager 虚拟设备
验证虚拟设备是否返回 `"ok\n"` 响应：

```cpp
// src/helper/SerialPortManager.cpp - emitVirtualEcho()
void SerialPortManager::emitVirtualEcho(const QString &text)
{
    // ... 前面的代码 ...
    
    // 虚拟设备返回 "ok" 而不是回显命令
    QString response = "ok\n";
    
    QTimer::singleShot(100, this, [this, response]() {
        emit dataReceived(response);
    });
}
```

### 调试日志
启用 SMTWork 日志来跟踪队列状态：

```cpp
// 在编译时应包含 QDebug 输出：
// [SMTWork] Queue paused due to timeout at index 0
// [SMTWork] Retrying current item at index 0: MOVE_TO_POS_1
// [SMTWork] Skipping item at index 0: MOVE_TO_POS_1
```

## 常见问题排查

### 问题：收到数据但队列仍在暂停
**原因：**
- 虚拟设备未返回 `"ok"`
- 响应格式不匹配（大小写、空格等）

**解决：**
检查 `onSerialDataReceived()` 中的响应验证：
```cpp
// 当前使用 contains() 进行大小写不敏感匹配
if (data.contains(item.expectedResponse, Qt::CaseInsensitive)) {
    // 这会匹配 "OK", "Ok", "ok" 等
}
```

### 问题：重试后仍然超时
**原因：**
- 设备实际上未连接
- 超时时间太短
- 设备响应很慢

**解决：**
- 增加 `WorkItem` 的 `timeout` 值
- 验证串口连接状态
- 检查设备日志

## 性能考虑

- **内存占用**：每个超时项额外存储一个 QTimer，通常 <1KB
- **CPU 占用**：暂停状态下零轮询，等待信号驱动
- **响应时间**：QTimer 精度通常 1-10ms（足以满足工业应用）

## 总结对比

| 特性 | 旧设计 | 新设计 |
|------|-------|--------|
| 超时处理 | 自动跳过 | 暂停等待 |
| 失败项处理 | 隐性忽略 | 显式干预 |
| 错误通知 | timeoutOccurred 信号 | timeoutOccurred + queuePaused 信号 |
| 手动干预 | 不支持 | retryCurrentItem() / skipCurrentItem() |
| 可靠性 | 低（可能丢失数据） | 高（确保完整处理） |
| 用户体验 | 无法追踪失败 | 清晰的失败指示和恢复选项 |

