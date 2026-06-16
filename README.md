# Headache

头痛发作记录 iOS App，使用 SwiftUI + SwiftData 实现。

## 功能

- 按头痛发作事件记录开始时间、结束时间、疼痛等级、睡眠时间和备注
- 支持多条药物服用记录：药名、剂量、单位、服用时间
- 自动保存历史药物，下次填写时可直接选择
- 使用头部图示热区选择疼痛位置
- 统计近 7 天 / 30 天发作次数、平均疼痛、平均持续时间、用药次数和常见位置

## 打开方式

使用 Xcode 打开：

```bash
open Headache.xcodeproj
```

当前机器的 `xcodebuild` 指向 Command Line Tools，不是完整 Xcode。如果需要命令行构建，请先安装完整 Xcode 并执行：

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```
