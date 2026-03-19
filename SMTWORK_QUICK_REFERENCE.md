# SMTWork 快速参考 (Quick Reference)

## 🚀 30秒快速开始

```cpp
// 1. 初始化（已在 main.cpp 中完成）
smtWork.setSerialPortManager(&serialPortManager);

// 2. 添加命令
smtWork.addWorkItem("MOVE_X 100\n", "ok");
smtWork.addWorkItem("VACUUM_ON\n", "ok");

// 3. 启动
smtWork.start();
```

## 📋 常用操作速查表

| 操作 | 代码 | 说明 |
|------|------|------|
| 添加命令 | `addWorkItem("cmd\n", "ok")` | 默认超时5秒 |
| 清空队列 | `clearWorkQueue()` | 立即停止 |
| 查看队列 | `queuedItemCount()` | 返回剩余项数 |
| 启动执行 | `start()` | 开始处理队列 |
| 暂停 | `pause()` | 停止定时器 |
| 停止 | `stop()` | 同 pause() |
| 执行一次 | `stepOnce()` | 发送一次 tick |
| 检查状态 | `waitingForResponse()` | 是否等待中 |
| 检查运行 | `running()` | 是否运行中 |

## 📡 常用信号速查表

| 信号 | 参数 | 何时触发 |
|------|------|---------|
| `commandSent` | `(QString cmd)` | 命令已发送 |
| `responseReceived` | `(QString resp)` | 收到预期响应 |
| `workItemCompleted` | `(int index)` | 单项完成 |
| `workQueueCompleted` | `()` | 全部完成 |
| `timeoutOccurred` | `(QString cmd)` | 响应超时 |
| `waitingForResponseChanged` | `()` | 等待状态变化 |

## 🎯 典型场景示例

### 场景1: 简单的坐标移动
```cpp
smtWork.addWorkItem("MOVE 100,200\n", "ok");
smtWork.addWorkItem("HOME\n", "homed");
smtWork.start();
```

### 场景2: 设备初始化
```cpp
smtWork.addWorkItem("INIT\n", "ready");
smtWork.addWorkItem("VERSION\n", "v1.0");
smtWork.addWorkItem("STATUS\n", "ok");
smtWork.start();
```

### 场景3: 带进度的操作
```cpp
connect(&smtWork, &SMTWork::workItemCompleted, 
    [](int idx) { 
        qDebug() << "进度:" << (idx+1) << "/3"; 
    });

smtWork.addWorkItem("STEP1\n", "ok");
smtWork.addWorkItem("STEP2\n", "ok");
smtWork.addWorkItem("STEP3\n", "ok");
smtWork.start();
```

## ⚙️ 高级配置

### 自定义超时时间
```cpp
WorkItem item;
item.command = "LONG_OPERATION\n";
item.expectedResponse = "done";
item.timeout = 15000;  // 15秒

// 注意：当前API不支持直接传入WorkItem
// 如需自定义超时，请联系开发人员添加接口
```

### 响应重试逻辑
```cpp
int retryCount = 0;
connect(&smtWork, &SMTWork::timeoutOccurred,
    [&](const QString &cmd) {
        if (++retryCount < 3) {
            smtWork.addWorkItem(cmd, "ok");  // 重新添加
            smtWork.start();
        }
    });
```

## 🔍 调试技巧

### 打开完整日志
在代码中使用 `qDebug()`，输出包括：
```
[SMTWork] Sending command: MOVE_X 100
[SMTWork] Received expected response: ok
[SMTWork] Response timeout for command: LONG_OP
```

### 检查队列状态
```cpp
qDebug() << "队列项数:" << smtWork.queuedItemCount();
qDebug() << "正在等待:" << smtWork.waitingForResponse();
qDebug() << "正在运行:" << smtWork.running();
```

### 模拟测试
```cpp
// 使用虚拟串口进行测试
// serial.connectPort("[虚拟调试设备] DEBUG-ECHO", 115200);
```

## ⚠️ 常见错误

| 错误 | 症状 | 解决方案 |
|------|------|--------|
| 串口不连接 | "Serial port not connected" | 先执行 `serialPortManager.connectPort(...)` |
| 无响应信号 | 应该完成的命令卡住 | 检查期望响应是否与设备实际回复匹配 |
| 超时过频 | 经常超时 | 延长超时时间或检查设备是否正常 |
| 信号未触发 | Connections 不工作 | 检查信号名是否拼写正确 |

## 📱 QML 完整示例

```qml
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10
        
        TextEdit {
            id: commandInput
            Layout.fillWidth: true
            height: 40
            placeholderText: "输入命令，如: MOVE X 100"
            text: "MOVE X 100\n"
        }
        
        Button {
            text: "添加到队列"
            onClicked: smtWork.addWorkItem(commandInput.text, "ok")
        }
        
        Row {
            Button { text: "启动"; onClicked: smtWork.start() }
            Button { text: "暂停"; onClicked: smtWork.pause() }
            Button { text: "清空"; onClicked: smtWork.clearWorkQueue() }
        }
        
        ProgressBar {
            id: progressBar
            Layout.fillWidth: true
            value: 0.0
        }
        
        TextArea {
            id: logView
            Layout.fillWidth: true
            Layout.fillHeight: true
            readOnly: true
            text: "日志...\n"
        }
    }
    
    Connections {
        target: smtWork
        
        function onCommandSent(cmd) {
            logView.text += "[发送] " + cmd + "\n"
        }
        
        function onResponseReceived(resp) {
            logView.text += "[收到] " + resp + "\n"
        }
        
        function onWorkItemCompleted(index) {
            progressBar.value = (index + 1) / smtWork.queuedItemCount()
        }
        
        function onWorkQueueCompleted() {
            logView.text += "[完成] 所有命令已执行\n"
            progressBar.value = 1.0
        }
        
        function onTimeoutOccurred(cmd) {
            logView.text += "[超时] " + cmd + "\n"
        }
    }
}
```

## 📞 技术支持

- **文档**: 见 `SMTWork_SERIAL_USAGE.md`
- **示例**: 见 `SMTWorkIntegrationExample.cpp`
- **总结**: 见 `SMTWORK_OPTIMIZATION_SUMMARY.md`

---
**最后更新**: 2026-03-19
**版本**: 2.0
