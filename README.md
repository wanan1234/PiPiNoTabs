PiPiNoTabs
皮皮虾（PiPi）TrollStore 插件 — 隐藏顶部标签与底部 TabBar，实现纯净界面

0.9版本适配 3.8.0pro版本（无弹窗菜单）

1.0版本适配 5.4.5pro版本（无弹窗菜单）

1.1版本适配 5.4.5pro版本（有弹窗菜单）

✨ 功能
隐藏底部 TabBar：完全透明化「首页、发现、消息、我的」等底部按钮，保留点击功能（实际已无点击需求）

隐藏顶部标签文字：透明化「关注、推荐、视频、图片、虾聊、文字」等顶部导航标签

极速生效：在 viewWillAppear 中多次异步执行，覆盖所有视图加载时机，无延迟、无闪烁

稳定可靠：只修改 alpha 属性，不触碰布局，不触发额外渲染，无闪退风险

📱 效果预览
原始界面	插件效果
顶部显示「关注、推荐、视频、图片、虾聊、文字」标签，底部显示 TabBar	顶部标签透明，底部 TabBar 透明，视频内容全屏显示
🔧 系统要求
设备：iPhone / iPad（支持 TrollStore）

系统：iOS 14.0 或更高版本

应用：皮皮虾5.4.5 pro（Bundle ID: com.bd.iphone.superPropipi）

📦 安装方法
使用 TrollStore + TrollFools
下载 PiPiNoTabs.deb 文件

打开 TrollFools 应用

在应用列表中找到 皮皮虾

点击「注入」，选择下载的 .deb 文件

注入完成后，彻底关闭皮皮虾（上划卡片强制退出）

重新打开皮皮虾，插件即生效，无任何过渡动画

🔨 编译方法
云端编译（推荐，无需 Mac）
Fork 或克隆本仓库到 GitHub

进入仓库的 Actions 页面

手动触发 Build PiPiNoTabs 工作流

构建完成后，在 Artifacts 中下载 PiPiNoTabs-deb.zip

解压得到 .deb 文件

本地编译（需要 Mac + Theos）
bash
# 1. 安装 Theos
git clone --recursive https://github.com/theos/theos.git "$HOME/theos"

# 2. 进入项目目录
cd PiPiNoTabs

# 3. 编译打包
make package FINALPACKAGE=1

# 4. 产物在 packages/ 目录下
ls -la packages/
📁 文件结构
text
PiPiNoTabs/
├── .github/
│   └── workflows/
│       └── build.yml      # GitHub Actions 自动编译
├── Tweak.xm               # 核心代码
├── Makefile               # Theos 编译配置
├── PiPiNoTabs.plist       # 过滤配置（仅注入皮皮虾）
├── control                # Debian 包描述
└── README.md              # 本文件
🛠️ 技术原理
递归视图遍历：从 UIWindow 开始递归遍历所有子视图

底部 TabBar 识别：通过类名 TTTabbar 精确定位底部容器

顶部标签识别：通过 UILabel.text 匹配「关注、推荐、视频、图片、虾聊、文字」

无痕透明化：设置 alpha = 0.0，保留 userInteractionEnabled 状态（如需点击）

多重执行保障：在 viewWillAppear 中执行三次（立即、0.01秒、0.05秒），覆盖动态加载视图

⚠️ 注意事项
本插件仅适配皮皮虾（Bundle ID: com.bd.iphone.superPropipi），其他应用需修改 Bundle ID

注入后如未生效，请彻底关闭皮皮虾后台（上划卡片强制退出）再重新打开

如需卸载，在 TrollFools 中点击「移除注入」即可恢复原始界面

搜索图标和儿童/青少年模式弹窗未做处理（在目标版本中未成功实现透明化），可单独尝试其他插件

📄 许可证
本项目仅供学习交流使用，请勿用于商业用途。

🤝 贡献
欢迎提交 Issue 和 Pull Request 改进本项目。
