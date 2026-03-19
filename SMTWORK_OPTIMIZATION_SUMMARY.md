# SMTWork 优化方案 - 完整总结

## 📋 概述

为了实现 **work 向串口设备发送数据并等待设备返回 ok 后才继续执行下一项** 的需求，对 `SMTWork` 类进行了全面优化升级。现在支持工作队列、串口通信和响应等待机制。

## 🎯 核心改进

### 1. 工作队列系统
```
传统模式: 定时发送 tick() 信号 → 模糊的工作流程
新模式: 清晰的命令队列 → 顺序执行 → 条件等待 → 继续下一项
```

### 2. 串口通信集成
- 与 `SerialPortManager` 无缝集成
- 自动发送命令和接收响应
- 智能响应验证（大小写不敏感）

### 3. 响应等待机制
- 每条命令都有独立的超时管理
- 支持自定义期望响应内容
- 完善的超时处理和错误恢复

## 📁 修改的文件

### 1. **src/helper/SMTWork.h** (完全重写)

**新增数据结构:**
```cpp
struct WorkItem {
    QString command;              // 发送的命令，如 "MOVE_X 100\n"
    QString expectedResponse;     // 期望收到的响应，如 "ok"
    int timeout = 5000;           // 响应超时时间（毫秒）
};
```

**新增主要接口:**
- `setSerialPortManager(SerialPortManager *manager)` - 设置串口管理器
- `addWorkItem(const QString &command, const QString &expectedResponse = "ok")` - 添加工作项
- `clearWorkQueue()` - 清空队列
- `queuedItemCount() const` - 获取队列中的项目数

**新增属性:**
- `waitingForResponse` - 是否正在等待响应

**新增信号:**
- `commandSent(const QString &command)` - 命令已发送
- `responseReceived(const QString &response)` - 收到响应
- `workQueueCompleted()` - 队列全部完成
- `workItemCompleted(int index)` - 单项完成
- `timeoutOccurred(const QString &command)` - 响应超时

### 2. **src/helper/SMTWork.cpp** (完全重写)

**核心流程:**
```
1. 添加多个工作项到 m_workQueue
2. 调用 start() 启动处理
3. processNextWorkItem() 获取下一个未执行的项目
4. sendCurrentCommand() 发送命令到串口并启动超时定时器
5. onSerialDataReceived() 接收回复并验证
6. 若验证成功：发射完成信号，处理下一项
7. 若超时：发射超时信号，跳过该项继续
8. 队列全部处理完后发射 workQueueCompleted()
```

**关键实现:**
- `processNextWorkItem()` - 工作队列管理
- `sendCurrentCommand()` - 命令下发
- `onSerialDataReceived()` - 响应接收和验证
- `onResponseTimeout()` - 超时处理

### 3. **main.cpp** (修改)

**新增初始化代码:**
```cpp
// 连接 smtWork 和 serialPortManager
smtWork.setSerialPortManager(&serialPortManager);
```

这确保了 `SMTWork` 在初始化时就绑定到串口管理器上。

## 🔄 工作流程图

```
┌─────────────────────────────────────────────────┐
│  1. addWorkItem("cmd1", "ok")                    │
│     addWorkItem("cmd2", "ok")                    │
│     ...                                          │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  2. start() 被调用                               │
│     start running, processNextWorkItem()         │
└──────────────────┬──────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────┐
│  3. sendCurrentCommand()                         │
│     现在串口: "cmd1"                             │
│     发射: commandSent("cmd1")                    │
│     启动超时定点器: 5000ms                       │
│     设置 waitingForResponse = true               │
└──────────────────┬──────────────────────────────┘
                   │
       ┌───────────┴──────────────┐
       │                          │
       ▼                          ▼
   收到响应                  超时（5秒无响应）
       │                          │
       ▼                          ▼
┌──────────────────┐     ┌─────────────────────┐
│ 检查是否包含     │     │ 发射:               │
│ "ok" (不分大小写)│     │ timeoutOccurred()   │
│      │           │     │ 跳过该项            │
│   YES│    NO     │     │      │              │
│      │───┐       │     └──────┼──────────────┘
└──────┼───┼───────┘            │
       │   │                    │
       ▼   ▼                    │
   成功  忽略                   │
   (继续) (继续)               │
       │    │ ◄─────────────────┘
       └────┼─────────────────────┐
            │                     │
            ▼                    ▼
    发射完成信号          ┌──────────────────┐
    workItemCompleted()   │ 处理下一项        │
    响应已确认完成        │ processNext...()  │
            │             └──────────────────┘
            │                    │
            └────────┬───────────┘
                     │
                     ▼
          ┌─────────────────────┐
          │ 还有下一项？        │
          └──────┬──────┬───────┘
            YES  │      │  NO
                 ▼      ▼
            重复    workQueue
             循环   Completed()
                   发射完成信号
```

## 💻 使用示例

### 基础使用
```cpp
// 初始化（在 main.cpp 中已自动完成）
smtWork.setSerialPortManager(&serialPortManager);

// 添加命令
smtWork.addWorkItem("MOVE_X 100\n", "ok");
smtWork.addWorkItem("MOVE_Y 50\n", "ok");
smtWork.addWorkItem("HOME\n", "homed");

// 监听进度
connect(&smtWork, &SMTWork::workQueueCompleted, [](){ 
    qDebug() << "所有命令执行完成";
});

// 启动
smtWork.start();
```

### QML 集成
```qml
Button {
    text: "执行工序"
    onClicked: {
        smtWork.clearWorkQueue()
        smtWork.addWorkItem("PICK\n", "ok")
        smtWork.addWorkItem("PLACE\n", "ok")
        smtWork.start()
    }
}

Connections {
    target: smtWork
    
    function onCommandSent(command) {
        statusText.text = "执行: " + command
    }
    
    function onWorkItemCompleted(index) {
        progressBar.value = (index + 1) / smtWork.queuedItemCount() * 100
    }
    
    function onWorkQueueCompleted() {
        statusText.text = "完成"
    }
    
    function onTimeoutOccurred(cmd) {
        statusText.text = "超时: " + cmd
    }
}
```

## 🚀 新增文件

### 1. SMTWork_SERIAL_USAGE.md
完整的 API 文档和详细使用说明

### 2. SMTWorkIntegrationExample.cpp
包含 4 个实际应用示例：
- 简单运动控制
- 复杂生产工序
- 带重试机制的容错流程
- 连续生产模式

## ✅ 特性清单

- [x] 工作队列支持
- [x] 串口命令发送
- [x] 响应等待机制
- [x] 超时处理
- [x] 信号反馈系统
- [x] 错误恢复
- [x] QML 集成
- [x] C++ 集成
- [x] 完整文档
- [x] 使用示例

## 🔍 关键改进点

| 功能 | 之前 | 之后 |
|------|------|------|
| 工作方式 | 定时 tick | 队列执行 |
| 串口通信 | 无 | 完全集成 |
| 响应验证 | 无 | 自动验证 |
| 超时处理 | 无 | 智能超时 |
| 错误恢复 | 无 | 自动恢复 |
| 反馈机制 | 单一 | 多种信号 |

## 🛠️ 编译要求

- Qt 6.0+ (使用现代 Qt 特性)
- 支持 C++17 及以上
- 需要 SerialPortManager 类

## 📝 配置建议

在项目的 `CMakeLists.txt` 中确保包含：
```cmake
find_package(Qt6 COMPONENTS Core Gui Qml Quick SerialPort REQUIRED)
```

## 🔧 后续扩展建议

1. **自定义响应匹配规则** - 支持正则表达式
2. **响应超时重试机制** - 自动重试失败的命令
3. **命令队列持久化** - 保存未执行的队列
4. **性能监控** - 记录命令执行统计
5. **并发队列支持** - 支持多个并行队列

## 📞 使用支持

所有新增的接口都已通过 `Q_INVOKABLE` 声明，支持 QML 直接调用。

### QML 中可用的操作：
- `smtWork.addWorkItem(cmd, response)`
- `smtWork.clearWorkQueue()`
- `smtWork.queuedItemCount()`
- `smtWork.start()`
- `smtWork.pause()`
- `smtWork.stop()`
- `smtWork.stepOnce()`

### 可监听的信号：
- `commandSent(command)`
- `responseReceived(response)`
- `workItemCompleted(index)`
- `workQueueCompleted()`
- `timeoutOccurred(command)`
- `waitingForResponseChanged()`

## 版本信息

- **优化版本**: 2.0
- **优化日期**: 2026-03-19
- **兼容性**: 向后兼容（额外功能不影响原 tick() 信号）
