# 旅记 App

一个以本机数据为主的 Flutter 旅行规划 App。首次安装没有预置行程，用户可以自行创建、编辑和切换多天行程。

## 功能

- 智能地图：高德实时地图、GPS 定位、地图选点；道路导航可唤起外部地图 App。
- 景点行程：按行程日期安排地点，保存电子票与订单链接。
- 旅行记账：预算、商家、商品或服务、支付方式与支出明细；Android 支持 CSV 账单导入。
- 美团直订：打开第三方门票、交通、美食和订单页面；本机优惠券截图识别需要人工核对。
- 路线规划：按天添加、编辑、删除和排序地点。App 内蓝线只表示地点顺序，实际道路路线由外部地图计算。
- 时间提醒：独立于行程的定时通知和提醒音。
- 旅行笔记：与行程关联的文字和照片记录。

行程、地点、账目、票据、提醒和笔记存于设备本机。卸载 App 会删除本机数据；当前没有云同步。第三方购买与支付在对应的外部应用或网页完成。

## 开发环境

需要 Flutter SDK、Android SDK 和 JDK 17。运行：

```bash
flutter pub get
flutter analyze
flutter run
```

地图功能需要自行申请高德地图 SDK Key。Key 与 Android 包名、签名 SHA1 或 iOS Bundle ID 绑定。构建时通过环境变量与 Dart define 注入，不要提交真实 Key：

```powershell
$env:AMAP_ANDROID_KEY = '你的 Android Key'
flutter run --dart-define=AMAP_ANDROID_KEY=$env:AMAP_ANDROID_KEY
```

发布 Android APK 时，同样设置 `AMAP_ANDROID_KEY` 并运行 `flutter build apk --release --dart-define=AMAP_ANDROID_KEY=$env:AMAP_ANDROID_KEY`。iOS 构建另传 `--dart-define=AMAP_IOS_KEY=你的 iOS Key`。没有 Key 时，地图页面使用应用内示意图，其余本地功能仍可运行。

Android 正式包需要自己的签名材料。Gradle 从用户目录的 `.luji/signing/signing.properties` 读取 `storeFile`、`storePassword`、`keyAlias`、`keyPassword`；签名文件和密码不能提交到仓库。按自己的包名和签名申请 Key 后再发布 APK。

`preview/` 是独立的电脑浏览器预览，与手机 App 的本机数据库不互通。`third_party/amap_flutter_map_plus_x/` 是项目使用的高德地图 Flutter 插件副本，请保留其中的许可证声明。
