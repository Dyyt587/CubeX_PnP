# SMTWork 串口通信优化 - 使用文档

## 概述

优化后的 `SMTWork` 支持与串口设备进行请求-响应通信。当发送命令到串口设备后，work 会等待设备的响应（如 "ok"）才继续执行下一项工作。

## 核心特性

1. **工作队列**：按顺序执行多个串口命令
2. **响应等待**：每条命令发送后等待设备响应
3. **超时机制**：支持设置响应超时时间
4. **信号反馈**：提供多种信号用于跟踪工作状态

## API 文档

### 主要方法

#### setSerialPortManager(SerialPortManager *manager)
设置关联的串口管理器（通常在初始化时调用一次）
```cpp
smtWork.setSerialPortManager(&serialPortManager);
```

#### addWorkItem(const QString &command, const QString &expectedResponse = "ok")
添加工作项到队列
- `command`: 要发送到串口的命令
- `expectedResponse`: 期望收到的响应（默认为 "ok"，不区分大小写）

```cpp
smtWork.addWorkItem("MOVE_X 100", "ok");
smtWork.addWorkItem("HOME", "homed");
smtWork.addWorkItem("MOVE_Y 50", "ok");
```

#### clearWorkQueue()
清空工作队列
```cpp
smtWork.clearWorkQueue();
```

#### queuedItemCount() const
获取队列中待执行的工作项数量
```cpp
int count = smtWork.queuedItemCount();
```

### 属性访问

#### waitingForResponse (READ-ONLY)
检查是否正在等待响应
```cpp
bool waiting = smtWork.waitingForResponse();
```

## 信号

### commandSent(const QString &command)
当命令发送到串口时发射
```qml
Connections {
    target: smtWork
    function onCommandSent(command) {
        console.log("发送:" + command)
    }
}
```

### responseReceived(const QString &response)
当收到响应时发射
```qml
Connections {
    target: smtWork
    function onResponseReceived(response) {
        console.log("响应:" + response)
    }
}
```

### workItemCompleted(int index)
当单个工作项完成时发射
```qml
Connections {
    target: smtWork
    function onWorkItemCompleted(index) {
        console.log("工作项 " + index + " 完成")
    }
}
```

### workQueueCompleted()
当所有工作项完成时发射
```qml
Connections {
    target: smtWork
    function onWorkQueueCompleted() {
        console.log("所有工作项完成")
    }
}
```

### timeoutOccurred(const QString &command)
当响应超时时发射
```qml
Connections {
    target: smtWork
    function onTimeoutOccurred(command) {
        console.log("超时:" + command)
    }
}
```

### waitingForResponseChanged()
当等待响应状态改变时发射

## 使用示例

### C++ 示例

```cpp
// 初始化时
smtWork.setSerialPortManager(&serialPortManager);

// 添加命令到工作队列
smtWork.addWorkItem("MOVE_X 100", "ok");
smtWork.addWorkItem("MOVE_Y 50", "ok");
smtWork.addWorkItem("HOME", "homed");

// 连接信号用于监听进度
connect(&smtWork, &SMTWork::workQueueCompleted, this, [this]() {
    qDebug() << "所有运动命令执行完成";
});

connect(&smtWork, &SMTWork::timeoutOccurred, this, [this](const QString &cmd) {
    qDebug() << "命令超时:" << cmd;
});

// 开始执行队列
smtWork.start();
```

### QML 示例

```qml
import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    
    Connections {
        target: smtWork
        
        function onCommandSent(command) {
            console.log("[发送] " + command)
            statusText.text = "发送中: " + command
        }
        
        function onResponseReceived(response) {
            console.log("[响应] " + response)
        }
        
        function onWorkItemCompleted(index) {
            console.log("[完成] 工作项 " + index)
            progressBar.value = (index + 1) / smtWork.queuedItemCount() * 100
        }
        
        function onWorkQueueCompleted() {
            console.log("[完成] 所有工作项已执行")
            statusText.text = "所有命令执行完成"
            progressBar.value = 100
        }
        
        function onTimeoutOccurred(command) {
            console.log("[超时] " + command)
            statusText.text = "命令超时: " + command
        }
        
        function onWaitingForResponseChanged() {
            if (smtWork.waitingForResponse) {
                statusText.text = "等待响应..."
            }
        }
    }
    
    Column {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        Text {
            id: statusText
            text: "就绪"
            font.pixelSize: 14
        }
        
        ProgressBar {
            id: progressBar
            width: parent.width
            value: 0
        }
        
        Button {
            text: "添加运动命令"
            onClicked: {
                smtWork.addWorkItem("MOVE_X 100\n", "ok")
                smtWork.addWorkItem("MOVE_Y 50\n", "ok")
                smtWork.addWorkItem("HOME\n", "homed")
            }
        }
        
        Button {
            text: "开始执行"
            onClicked: smtWork.start()
        }
        
        Button {
            text: "暂停"
            onClicked: smtWork.pause()
        }
        
        Button {
            text: "清空队列"
            onClicked: smtWork.clearWorkQueue()
        }
    }
}
```

## 工作流程

```
添加工作项
      ↓
start() 被调用
      ↓
发送第1个命令到串口 → commandSent(cmd1)
      ↓
等待响应 (waitingForResponse = true) → waitingForResponseChanged()
      ↓
收到预期响应 (如 "ok")
      ↓
发射 responseReceived(response)
      ↓
发射 workItemCompleted(0)
      ↓
发送第2个命令 → commandSent(cmd2)
      ↓
... 重复上述过程 ...
      ↓
所有命令执行完成 → workQueueCompleted()
```

## 超时处理

每个工作项有一个 5 秒的默认超时时间。如果在此时间内未收到响应：
1. 发射 `timeoutOccurred(command)` 信号
2. 跳过该工作项
3. 继续处理下一个工作项

## 常见问题

### Q: 如何修改响应超时时间？
A: 使用 `WorkItem` 结构体的 `timeout` 字段（单位：毫秒）
```cpp
WorkItem item;
item.command = "MOVE_X 100";
item.expectedResponse = "ok";
item.timeout = 10000;  // 10 秒超时
```

### Q: 如何自定义响应匹配规则？
A: 目前使用简单的字符串包含匹配（不区分大小写）。如需复杂规则，可扩展 `onSerialDataReceived()` 方法。

### Q: 是否支持并发执行多个队列？
A: 不支持。每次只能执行一个工作队列。需要等待 `workQueueCompleted()` 再添加新队列。

### Q: 如何调试工作流程？
A: 查看 Qt 的调试输出，代码中使用 `qDebug()` 输出：
```
[SMTWork] Sending command: MOVE_X 100
[SMTWork] Received expected response: ok
[SMTWork] Sending command: MOVE_Y 50
```

## 版本历史

- v1.0 (2026-03-19): 初版，支持基本的串口命令队列和响应等待机制
