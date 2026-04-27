# AI圈今日要闻

一个适配 PC 和手机端的本地 AI 早报系统，面向新媒体运营，把可信来源的最新 AI 资讯整理成中文标题、中文摘要、爆点标题和公众号选题池。

## 现在能做什么

- 每次刷新时抓取可信来源并生成今日 AI 早报
- 自动补中文标题翻译和中文摘要
- 按上游、中游、下游和深度测评分栏
- 单独统计大V/分析师内容，不再是 0
- 导出 Markdown 早报、JSON 和 CSV 选题池
- 配置飞书机器人和企业微信群机器人 Webhook
- 支持本机每日 09:00 定时生成
- 已创建一条 Codex 每日 09:00 的线程自动化
- 已提供微信小程序和支付宝小程序手机端骨架

## 已接入的来源

- 官方/研究：OpenAI、Google AI、Microsoft AI、Hugging Face、NVIDIA、arXiv
- 行业媒体：TechCrunch AI、VentureBeat AI、The Decoder
- 大V/分析师：Simon Willison、Ethan Mollick、Ben's Bites、Latent Space、Import AI、Understanding AI、Interconnects、AI Snake Oil、Exponential View、Strange Loop Canon

## 启动方式

直接双击 `run.bat`

或在 PowerShell 中执行：

```powershell
.\start-server.ps1
```

启动后访问：

`http://localhost:8765`

不要直接打开 `index.html` 的 `file://` 地址，否则本地 API、导出和推送功能不可用。

## 生成日报

手动生成：

```powershell
.\generate-daily-brief.ps1
```

安装 Windows 每日 09:00 定时任务：

```powershell
.\install-daily-task.ps1
```

## 推送配置

把 Webhook 填到页面“推送与定时”区域后保存即可。

- `feishuWebhook`：飞书自定义机器人地址
- `wechatWebhook`：企业微信群机器人地址
- `enableAutoPush`：开启后，定时生成时会自动推送

## 导出文件

生成后会写到：

- `data/latest-report.json`
- `exports/latest-report.md`
- `exports/latest-topics.csv`

并同时按日期生成归档文件。

## 公开网页

现在每次运行：

```powershell
.\generate-daily-brief.ps1
```

都会自动更新：

- `public-site/`

这个目录就是可公开托管的“只读公开版”网站，可直接上传到静态托管平台。

- 发布说明：[PUBLIC-DEPLOY.md](C:/Users/Administrator/Documents/Codex/2026-04-23-pc-ai-ai-v/PUBLIC-DEPLOY.md)

如果你要它在线自动更新，项目里已经加好了 GitHub Actions 工作流：

- [.github/workflows/public-site-pages.yml](C:/Users/Administrator/Documents/Codex/2026-04-23-pc-ai-ai-v/.github/workflows/public-site-pages.yml)

## 手机端小程序

- 微信小程序目录：`wechat-miniprogram/`
- 支付宝小程序目录：`alipay-miniprogram/`
- 小程序接入文档：[MINIAPP-DEPLOY.md](C:/Users/Administrator/Documents/Codex/2026-04-23-pc-ai-ai-v/MINIAPP-DEPLOY.md)

生成日报后，会自动同步更新两个小程序的 mock 数据文件，方便直接在开发者工具里预览。
