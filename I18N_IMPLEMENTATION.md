# CubeX_PnP 国际化 (i18n) 实现文档

## 概述

CubeX_PnP 应用现已实现完整的国际化支持，支持中文（简体）和英文两种语言。用户可以在"设置"页面动态切换应用语言，改变后立即生效。

## 架构设计

### 核心组件

#### 1. TranslateHelper (翻译帮助类)
- **位置**: `src/helper/TranslateHelper.h` / `TranslateHelper.cpp`
- **功能**: 
  - 管理应用语言加载和切换
  - 保存用户语言选择到本地设置
  - 支持动态语言切换且立即生效
- **关键方法**:
  - `init(QQmlEngine *engine)` - 初始化翻译系统
  - `switchLanguage(const QString &language)` - 切换语言
- **支持的语言**:
  - `en_US` - 英文（美式）
  - `zh_CN` - 中文（简体）

#### 2. SettingsHelper (设置帮助类)
- **功能**: 持久化保存语言选择
- **方法**:
  - `saveLanguage(const QString &language)` - 保存语言设置
  - `getLanguage()` - 获取保存的语言（默认 "en_US"）

#### 3. 翻译文件结构
```
CubeX_PnP/
├── CubeX_PnP_en_US.ts       # 英文翻译源文件
├── CubeX_PnP_zh_CN.ts       # 中文翻译源文件
└── build/...../i18n/
    ├── CubeX_PnP_en_US.qm   # 编译后的英文翻译
    └── CubeX_PnP_zh_CN.qm   # 编译后的中文翻译
```

## 实现细节

### 1. 翻译文件格式

翻译文件采用 Qt 标准的 TS (Translation Source) 格式，XML 结构：

```xml
<?xml version="1.0" encoding="utf-8"?>
<!DOCTYPE TS>
<TS version="2.1" language="en_US">
    <context>
        <name>SettingsPage</name>
        <message>
            <source>设置</source>
            <translation>Settings</translation>
        </message>
    </context>
</TS>
```

### 2. CMake 编译配置

在 `CMakeLists.txt` 中配置翻译编译：

```cmake
# 添加 LinguistTools 模块
find_package(Qt6 REQUIRED COMPONENTS LinguistTools)

# 指定翻译文件
set(TS_FILES
    CubeX_PnP_en_US.ts
    CubeX_PnP_zh_CN.ts
)

# 编译翻译文件
qt6_add_translations(appCubeX_PnP
    TS_FILES ${TS_FILES}
)

# 复制 .qm 文件到 i18n 目录
add_custom_command(TARGET appCubeX_PnP POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E make_directory 
        "$<TARGET_FILE_DIR:appCubeX_PnP>/i18n"
)
```

编译过程：
1. lupdate 工具处理 .ts 文件
2. 生成 .qm (Compiled Binary Translation) 文件
3. Post-build 命令复制到 `appCubeX_PnP/i18n/` 目录

### 3. QML 中的使用

#### 基本用法
所有可显示的文本都使用 `qsTr()` 函数标记：

```qml
Text {
    text: qsTr("这是中文文本")  // 标记为可翻译
}
```

#### 在 QML 中访问翻译系统

```qml
import QtQuick
import FluentUI

FluComboBox {
    model: transHelper.languages  // ["en_US", "zh_CN"]
    onCurrentIndexChanged: {
        var lang = currentIndex === 1 ? "zh_CN" : "en_US"
        transHelper.switchLanguage(lang)
    }
}
```

### 4. 主程序集成 (main.cpp)

```cpp
#include "src/helper/TranslateHelper.h"

int main(int argc, char *argv[]) {
    QQmlApplicationEngine engine;
    
    // 初始化翻译系统
    TranslateHelper::getInstance()->init(&engine);
    
    // 注册为 QML 上下文属性
    engine.rootContext()->setContextProperty("transHelper", 
                                            TranslateHelper::getInstance());
    
    // ... 其他初始化代码
    
    return app.exec();
}
```

## 使用指南

### 对用户
1. 打开应用，进入"设置"页面
2. 在"语言设置"部分选择所需语言
3. 整个应用界面立即切换到对应语言（无需重启）
4. 语言选择自动保存，下次启动应用时会使用之前选择的语言

### 对开发者

#### 添加新的可翻译文本

1. **在 QML 文件中**：使用 `qsTr()` 包装文本
```qml
Text { text: qsTr("新消息") }
```

2. **在 C++ 代码中**：使用 `QCoreApplication::translate()`
```cpp
QString msg = QCoreApplication::translate("Context", "新消息");
```

#### 更新翻译文件

执行以下命令更新 .ts 文件（提取新的待翻译字符串）：

```bash
# Windows: 使用 Qt 工具目录中的 lupdate
C:\Qt\6.10.2\mingw_64\bin\lupdate.exe -recursive . -ts CubeX_PnP_*.ts

# 或使用 CMake 在构建目录中运行
cmake --build . --target lupdate_appCubeX_PnP
```

#### 翻译工作流

1. **提取字符串** (`lupdate`)
   - 扫描所有 QML 和 C++ 文件
   - 提取 `qsTr()` 和 `translate()` 调用
   - 更新 .ts 文件

2. **翻译** (手动编辑或使用 Qt Linguist)
   - 打开 `CubeX_PnP_en_US.ts` 使用 Qt Linguist
   - 为每个 `<message>` 填写 `<translation>`

3. **编译** (`lrelease`)
   - 将 .ts 文件编译为二进制 .qm 文件
   - 自动在构建过程中进行
   - 输出到 `build/.../i18n/` 目录

### 更新翻译的步骤

如果添加了新文本需要翻译：

1. 确珠代码中使用了 `qsTr()`
2. 重新构建项目（会自动运行 lupdate）
3. 编辑 .ts 文件添加翻译
4. 再次构建以生成新的 .qm 文件

### 当前支持的翻译内容

| 模块 | 翻译项数 | 状态 |
|------|--------|------|
| SettingsPage | 8 | ✅ 完成 |
| HomePage | 39 | ✅ 完成 |
| PackageLibraryPage | 40 | ✅ 完成 |
| **总计** | **87** | **✅ 完成** |

## 技术细节

### 翻译系统的加载流程

```
应用启动
  ↓
main.cpp: TranslateHelper::getInstance()->init(&engine)
  ↓
SettingsHelper::getLanguage() 获取上次保存的语言 (默认 "en_US")
  ↓
加载 i18n/CubeX_PnP_<language>.qm 文件
  ↓
QGuiApplication::installTranslator() 安装翻译器
  ↓
engine.retranslate() 重新翻译所有 UI 文本
  ↓
QML 上下文："transHelper" 可用于语言切换
```

### 语言切换流程

```
用户在 SettingsPage 选择新语言
  ↓
transHelper.switchLanguage(newLanguage)
  ↓
更新 TranslateHelper::m_current
  ↓
调用 SettingsHelper::saveLanguage() 保存到本地
  ↓
卸载旧翻译器，加载新翻译器
  ↓
engine.retranslate() 更新所有 UI 文本
  ↓
整个界面立即切换语言
```

## 常见问题

### Q: 如何添加新语言支持？

A: 
1. 创建新的 .ts 文件（如 `CubeX_PnP_ja_JP.ts`）
2. 在 CMakeLists.txt 的 TS_FILES 中添加
3. 翻译所有字符串
4. 重新构建项目

### Q: 翻译文件放在哪里？

A: 
- 源文件：项目根目录 (`CubeX_PnP_*.ts`)
- 编译后：`build/.../i18n/` 目录
- 运行时加载路径：`executable_dir/i18n/CubeX_PnP_<lang>.qm`

### Q: 如何验证翻译是否生效？

A:
1. 检查 `i18n/` 是否存在 .qm 文件
2. 启动应用，进入设置页面
3. 切换语言，验证界面文本是否改变
4. 查看控制台输出确认翻译文件加载成功

### Q: 部分文本未翻译怎么办？

A:
1. 确保文本使用了 `qsTr()` 
2. 检查 .ts 文件中是否存在该字符串
3. 如果缺失，重新构建以运行 lupdate 提取新字符串
4. 在 .ts 文件中添加翻译

## 文件清单

新创建/修改的文件：

```
CubeX_PnP/
├── CubeX_PnP_en_US.ts                           # 新增：英文翻译文件
├── CubeX_PnP_zh_CN.ts                           # 新增：中文翻译文件
├── CMakeLists.txt                               # 修改：添加翻译编译配置
├── main.cpp                                     # 修改：添加 TranslateHelper 初始化
├── src/helper/TranslateHelper.h                 # 修改：添加 switchLanguage() 方法
├── src/helper/TranslateHelper.cpp               # 修改：实现 switchLanguage() 和文件名更改
└── QML/page/SettingsPage.qml                    # 修改：添加语言选择控件
```

## 后续计划

- [ ] 添加更多语言支持（日文、西班牙文等）
- [ ] 使用 Qt Linguist 工具完善翻译
- [ ] 支持系统语言自动检测
- [ ] 添加翻译不完整警告
- [ ] 性能优化翻译加载

## 相关资源

- Qt 国际化文档: https://doc.qt.io/qt-6/i18n-overview.html
- Qt Linguist 工具: https://doc.qt.io/qt-6/qtlinguist-index.html
- QML 翻译: https://doc.qt.io/qt-6/qtquick-positioning-layouts.html

