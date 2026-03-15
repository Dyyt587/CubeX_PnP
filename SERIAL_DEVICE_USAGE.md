# 串口设备使用文档

更新时间：2026-03-15

## 1. 功能概述

当前项目的串口模块已支持以下能力：

- 串口列表扫描与刷新
- 串口连接/断开
- 自动重连（UI 开关）
- 发送数据并自动写入控制台
- 接收数据缓存与按需读取
- 统一控制台消息信号（发送/接收/系统消息）

主要代码位置：

- `src/helper/SerialPortManager.h`
- `src/helper/SerialPortManager.cpp`
- `QML/page/DeviceConnectionPage.qml`
- `QML/component/SerialConnectionPanel.qml`

## 2. 界面使用（操作人员）

入口页面：设备连接页。

### 2.1 连接串口

1. 在“串口”下拉框选择目标 COM 口
2. 在“波特率”下拉框选择参数（默认 115200）
3. 点击“连接”
4. 连接成功后，状态会变为“已连接”

### 2.2 发送数据

1. 在“输入要发送的数据”输入框内填写内容
2. 按回车或点击“发送”
3. 控制台会显示发送记录

### 2.3 查看接收数据

- 串口有新数据时，控制台会自动追加显示

### 2.4 自动重连

1. 勾选“自动重连”
2. 当非手动断开且串口异常断开时，系统会定时尝试重连
3. 设备恢复后会自动重连并提示

说明：若用户手动点击“断开连接”，不会触发自动重连。

## 3. 开发接口（槽机制）

`SerialPortManager` 提供了可直接调用的槽接口。

### 3.1 发送并写控制台

函数：`sendWithConsole(const QString &text)`

行为：

- 发送串口数据
- 发送成功后自动触发控制台消息信号（`[发送] ...`）

返回值：

- `true`：发送成功
- `false`：发送失败（并通过错误信号上报）

### 3.2 读取接收缓冲区

函数：`readBufferedData()`

行为：

- 读取当前接收缓冲区所有内容
- 读取后会清空缓冲区（一次性消费）

返回值：

- `QString`：缓冲区文本内容

### 3.3 清空接收缓冲区

函数：`clearBufferedData()`

行为：

- 主动清空接收缓冲

### 3.4 控制台消息信号

信号：`consoleMessage(const QString &message)`

建议：

- UI 层统一监听该信号并追加到控制台，避免分散拼接日志逻辑

## 4. 信号与数据流

### 4.1 接收流程

1. 底层串口触发 `readyRead`
2. 读取数据并写入内部缓冲区
3. 发出 `dataReceived(text)`
4. 同时发出 `consoleMessage("[接收] " + text)`

### 4.2 发送流程

1. UI 或外部调用 `sendWithConsole(text)`
2. 内部调用 `sendData(text)`
3. 成功后发出 `consoleMessage("[发送] " + text)`

## 5. QML 调用示例

```qml
Connections {
    target: serialPortManager
    function onConsoleMessage(message) {
        // 统一追加到控制台文本
        root.controllerConsoleText += (root.controllerConsoleText ? "\n" : "") + message
    }
}

function sendText(text) {
    if (!serialPortManager.connected)
        return
    serialPortManager.sendWithConsole(text)
}

function readBufferOnce() {
    const data = serialPortManager.readBufferedData()
    if (data.length > 0) {
        // 在此处理读取到的数据
        console.log(data)
    }
}
```

## 6. C++ 调用示例

```cpp
// 发送并记录控制台
serialPortManager->sendWithConsole("M105\n");

// 读取并消费接收缓冲区
const QString rx = serialPortManager->readBufferedData();
if (!rx.isEmpty()) {
    qDebug() << "RX:" << rx;
}
```

## 7. 常见问题排查

### 7.1 无法连接串口

检查项：

- COM 口是否被其他软件占用
- 波特率是否与设备一致
- Windows 权限是否允许访问串口设备

### 7.2 有发送无接收

检查项：

- 串口参数（数据位/校验位/停止位）是否匹配设备
- 设备是否需要换行符（例如 `\n` 或 `\r\n`）
- 设备是否已正确上电且处于可响应状态

### 7.3 自动重连未生效

检查项：

- 是否勾选了“自动重连”
- 是否是“手动断开”（手动断开不会自动重连）
- 目标 COM 口恢复后是否仍为同一端口号

## 8. 维护建议

- 业务发送统一使用 `sendWithConsole`，保证控制台日志一致
- 业务读取优先使用 `readBufferedData`，并明确消费时机
- 若未来需要“读取不清空”场景，可补充 `peekBufferedData()` 接口
