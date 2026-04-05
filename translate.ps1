# PowerShell script to add English translations to the .ts file
$translationMap = @{
    "设置" = "Settings"
    "快速设置" = "Quick Settings"
    "深色模式" = "Dark Mode"
    "语言设置" = "Language Settings"
    "应用语言:" = "Application Language:"
    "中文 (Chinese)" = "Chinese (中文)"
    "英文 (English)" = "English"
    "选择应用的界面语言，改变后立即生效。" = "Select the application interface language. Changes take effect immediately."
    "运动控制" = "Motion Control"
    "XY 平面" = "XY Plane"
    "Z1 轴" = "Z1 Axis"
    "R1 轴" = "R1 Axis"
    "移动距离:" = "Move Distance:"
    "摄像头:" = "Camera:"
    "顶部黑白" = "Top B&W"
    "顶部彩色" = "Top Color"
    "底部黑白" = "Bottom B&W"
    "底部彩色" = "Bottom Color"
    "左上 (-X+Y)" = "Top-Left (-X+Y)"
    "上 (+Y)" = "Up (+Y)"
    "右上 (+X+Y)" = "Top-Right (+X+Y)"
    "左 (-X)" = "Left (-X)"
    "归零" = "Home"
    "右 (+X)" = "Right (+X)"
    "左下 (-X-Y)" = "Bottom-Left (-X-Y)"
    "下 (-Y)" = "Down (-Y)"
    "右下 (+X-Y)" = "Bottom-Right (+X-Y)"
    "Z1 上升 (+Z1)" = "Z1 Up (+Z1)"
    "Z1 下降 (-Z1)" = "Z1 Down (-Z1)"
    "Z1 归零" = "Z1 Home"
    "R1 逆时针" = "R1 Counter-Clockwise"
    "R1 顺时针" = "R1 Clockwise"
    "Z2 轴" = "Z2 Axis"
    "Z2 上升 (+Z2)" = "Z2 Up (+Z2)"
    "Z2 下降 (-Z2)" = "Z2 Down (-Z2)"
    "Z2 归零" = "Z2 Home"
    "R2 逆时针" = "R2 Counter-Clockwise"
    "R2 顺时针" = "R2 Clockwise"
    "速度:" = "Speed:"
    "当前位置" = "Current Position"
    "TableView" = "Component Placement"
    "首页" = "Home"
    "设备连接" = "Device Connection"
    "封装库" = "Package Library"
    "新增" = "Add"
    "保存" = "Save"
    "删除" = "Delete"
    "编辑" = "Edit"
    "取消" = "Cancel"
    "开始执行" = "Start Execution"
    "已暂停" = "Paused"
    "单步执行" = "Single Step"
    "导入文件" = "Import File"
    "导入Gerber" = "Import Gerber"
    "Clear All" = "Clear All"
    "Delete Selection" = "Delete Selection"
    "Add a row of Data" = "Add a row of Data"
    "Insert a Row" = "Insert a Row"
    "序号" = "No."
    "器件名称" = "Device Name"
    "x坐标" = "X Coordinate"
    "y坐标" = "Y Coordinate"
    "角度" = "Rotation"
    "封装" = "Package"
    "搜索" = "Search"
}

# Read the file
$content = Get-Content -Path "C:\Users\lzj\Github\CubeX_PnP\CubeX_PnP_en_US.ts" -Raw

# Replace unfinished translations
foreach ($chinese in $translationMap.Keys) {
    $english = $translationMap[$chinese]
    # Escape special XML characters and regex special characters
    $escapedChinese = [regex]::Escape($chinese)
    $pattern = "<source>$escapedChinese</source>\s*<translation type=`"unfinished`"></translation>"
    $replacement = "<source>$chinese</source>`n        <translation>$english</translation>"
    $content = $content -replace $pattern, $replacement
}

# Write back
$content | Set-Content -Path "C:\Users\lzj\Github\CubeX_PnP\CubeX_PnP_en_US.ts" -Encoding UTF8

Write-Output "Translation updates completed"
