# 公开网页发布说明

当前项目已经支持导出一个可直接托管的公开网页目录：

- `public-site/`

这个目录是“公开只读版”：

- 可以公开打开
- 可以浏览最新早报
- 可以下载 Markdown / JSON / CSV
- 不暴露本地生成、Webhook、推送配置等管理能力
- 可以作为微信/支付宝小程序的公开数据源

## 先生成公开版

在项目根目录执行：

```powershell
.\generate-daily-brief.ps1
```

执行后会自动同步更新：

- `public-site/index.html`
- `public-site/app.js`
- `public-site/styles.css`
- `public-site/latest-report.json`
- `public-site/latest-report.md`
- `public-site/latest-topics.csv`
- `public-site/robots.txt`
- `public-site/404.html`
- `public-site/build-meta.json`

## 最简单的公开方式

### 方案 A：GitHub Pages

把 `public-site/` 目录内容上传到一个 GitHub 仓库，然后发布 Pages。

官方文档：

- [GitHub Pages Quickstart](https://docs.github.com/en/pages/quickstart)
- [GitHub Actions 定时任务](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows#schedule)

适合：

- 成本低
- 页面公开访问
- 先快速上线一个可分享网址

项目里已经自带工作流：

- `.github/workflows/public-site-pages.yml`

它可以：

1. 每天自动运行 `generate-daily-brief.ps1`
2. 自动构建 `public-site/`
3. 自动部署到 GitHub Pages

如果你需要手动点一次立即生成，还可以用：

- `.github/workflows/public-site-artifacts.yml`

### 方案 B：Cloudflare Pages

把 `public-site/` 目录作为静态站点部署。

官方文档：

- [Cloudflare Pages Get Started](https://developers.cloudflare.com/pages/get-started/)
- [Cloudflare Workers Cron Triggers](https://developers.cloudflare.com/workers/configuration/cron-triggers/)

适合：

- 国内外访问都比较友好
- 配自定义域名更方便
- 后续升级成 API / Worker 更顺滑

## 当前版本的重要限制

你现在的“完整交互版”依赖本地 PowerShell API：

- `start-server.ps1`
- `backend.ps1`

所以它不能原样一键扔到 GitHub Pages 这类纯静态托管上。

因此我已经帮你拆出了 `public-site/`：

- 公开网站用 `public-site/`
- 本地管理后台继续用项目根目录运行
- 小程序也可以直接读取 `public-site/latest-report.json`

## 如果你想要“公开网页也能实时刷新”

那就不是纯静态托管了，需要继续做一步：

1. 把抓取/翻译/生成逻辑迁到可部署的后端
2. 提供公网 HTTPS 接口
3. 前端从这个公网接口拉取最新早报

这时就可以做到：

- 公网实时刷新
- 小程序拉同一套数据
- 飞书/企业微信推送和网页共用同一后端

如果你接受“按天自动更新，而不是每秒实时”，那么现在这套 GitHub Pages 自动发布已经能满足大部分公开展示需求。

## 我建议你现在这样做

如果你想最快先有一个公开网址：

1. 运行 `.\generate-daily-brief.ps1`
2. 把 `public-site/` 上传到 GitHub Pages 或 Cloudflare Pages
3. 先把“展示版”上线
4. 如果要让小程序也公开展示，把该站点的 `latest-report.json` 地址填入两个小程序的 `publicDataUrl`

如果你想做成正式产品：

下一步让我帮你把后端改成真正可部署的公网版本。
