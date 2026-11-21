# 红狐听力原生版

从 D:/code/listenappAndroid 的 Kotlin/Compose 项目迁移。原 Android 仓库保持不变；此目录包含两个独立原生工程，不使用 WebView。

- iOS：SwiftUI + AVPlayer，最低 iOS 16，工程 ios/RedFoxListen.xcodeproj。
- 鸿蒙：ArkTS + ArkUI Video，最低 HarmonyOS NEXT 5.0 / API 12，工程 harmony。
- 后端继承 Android 项目：http://47.97.107.100:8090/ 。没有添加单词项目的 /api/ 前缀。

## 已实现

手机号登录、验证码注册、找回密码、隐私政策、分类浏览、课程搜索、海报列表、剧集列表、课程点赞与收藏、学习列表、在线播放、播放/暂停、前后跳转5秒、拖动进度、倍速、AB段落创建/选择/循环/上一段/下一段/删除、云端AB记录加载/保存/清空、精听标记、视频下载/取消/本地删除/本地播放、会员说明、资料刷新、反馈、SVIP设置会员、退出登录和二次确认注销。

原版会员规则：普通会员在海报列表仅开放 id=3 的专辑；剧集列表从第11集起提示会员。状态位继承原后端约定，点赞/收藏/精听的 0 表示已选，1 表示未选。

AB记录位置使用秒，传输字段必须为 APos / BPos（区分大小写）；保存请求使用 curriculumId、recordPhase、curriculumName、category。云端记录加载失败时不允许保存空列表覆盖旧记录；云端删除成功之后才清空本地列表。

登录加密继承 Android 的 BouncyCastle AES/CBC/ZeroBytePadding。输入正好占满16字节时继续补16个零字节，与原 Vue 版 CryptoJS ZeroPadding 的边界行为不同。reference/aes-vectors.json 的6组向量已通过本机实际 BouncyCastle 运行生成，包含空字符串、整块输入和中文。

iOS token 保存到 Keychain；鸿蒙 token 保存到 AssetStore。密码不写入配置。

## 当前验证结果

- 已使用本机 DevEco Studio 配套 SDK 完成 ArkTS 编译与 assembleHap，生成 harmony/entry/build/default/outputs/default/entry-default-unsigned.hap。
- 该 HAP 未签名，需要为 com.redfox.listen.native 单独配置调试/发布签名后安装。没有沿用其他应用的证书和 profile。
- 已运行 scripts/verify.cjs：AB/跳转边界、实际 Android 加密向量、两端全部20个接口路径、Xcode源码构建引用、JSON、页面入口与编码检查。
- 本机没有 Mac/Xcode，iOS 源码尚未编译；提供 scripts/check-ios.sh 在 Mac 上验证加密和播放规则并构建模拟器版本。
- 尚未使用真实账号联调，也没有发送验证码、注册、密码修改、会员修改或注销请求。未执行设备播放或下载测试。

## 启动鸿蒙

1. 用 DevEco Studio 打开 harmony，等待项目同步。
2. 在 File > Project Structure 为本项目配置 SDK 与 Signing，选择 API 12 或更新的 HarmonyOS NEXT 模拟器/真机。
3. 运行 entry。

当前机器也可执行：

~~~powershell
powershell -ExecutionPolicy Bypass -File scripts/build-harmony.ps1
~~~

其他安装位置通过 -DevEcoHome 指定。脚本只构建，不自动配置证书、安装或启动设备。

## 启动 iOS

1. 在 Mac 上打开 ios/RedFoxListen.xcodeproj。
2. 在 Signing & Capabilities 中选择开发团队，按需修改 bundle identifier。
3. 选择 iOS 16 或更新的模拟器运行 RedFoxListen；真机需完成签名。

~~~sh
sh scripts/check-ios.sh
~~~

也可以使用 ios/project.yml 通过 XcodeGen 重新生成工程。

## 本地检查

~~~sh
node scripts/verify.cjs
~~~

checks/AndroidAesVectors.java 用于重新生成旧 Android 加密向量，需要 JDK 和 BouncyCastle bcprov-jdk18on。checks/main.swift 则在 Mac 上直接检查原生 CommonCrypto 输出，不以 JavaScript 对照结果冒充原生执行结果。

## 平台差异与待验证项

- 两端下载面向普通视频文件，尚未实现 HLS/m3u8 离线打包、断点续传或进程结束后的下载任务恢复。iOS 下载页显示下载中/完成/错误；鸿蒙显示进度。完成的文件和元数据持久化到应用私有目录。
- 已登录时可以从下载页播放本地视频；完全离线时云端AB加载会提示错误，视频仍可播放。尚未实现离线AB记录同步队列；不要把它理解为完整离线账号模式。
- iOS 配置了后台音频与锁屏播放/暂停，但仍需真机验证中断与耳机行为；鸿蒙目前是前台 Video 播放，未实现后台连续任务与 AVSession。Android 前台服务无法直接复制到这两个平台。
- 鸿蒙 API12 提供0.75/1/1.25/1.75/2倍速；AB边界精度受 Video 的进度回调和媒体关键帧影响，需要真机验证。
- 原版 SVIP 的两种AB控件布局合并为一套原生段落操作界面；不复刻 Android 的每个像素和系统通知布局。
- 会员说明保留原版支付宝二维码及价格，没有新增支付下单、支付回调、StoreKit 或鸿蒙 IAP；价格是源码原值，尚未在线核验。发布前需核对平台购买流程。
- 隐私政策保留原 Android 文本及日期；发布前请按实际数据处理行为核对。默认 HTTP 与固定 AES key/IV 均为旧协议兼容，上线前应完成 HTTPS 改造并收紧 iOS ATS 配置。

实现参考：[Apple AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer/)、[鸿蒙 Video](https://developer.huawei.com/consumer/en/doc/harmonyos-references/ts-media-components-video/)。

# listenapp_native
