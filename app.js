const state = {
  report: null,
  config: null,
  runtime: {
    mode: "interactive",
    readOnly: false,
  },
  filters: {
    bucket: "all",
    lane: "all",
    search: "",
    windowHours: 72,
  },
};

const els = {
  bootNotice: document.querySelector("#boot-notice"),
  totalCount: document.querySelector("#total-count"),
  creatorCount: document.querySelector("#creator-count"),
  generatedAt: document.querySelector("#generated-at"),
  briefingMeta: document.querySelector("#briefing-meta"),
  leadCard: document.querySelector("#lead-card"),
  pulseGrid: document.querySelector("#pulse-grid"),
  topList: document.querySelector("#top-list"),
  topicGrid: document.querySelector("#topic-grid"),
  feedSummary: document.querySelector("#feed-summary"),
  statusBanner: document.querySelector("#status-banner"),
  feedList: document.querySelector("#feed-list"),
  sourceStatusList: document.querySelector("#source-status-list"),
  exportMd: document.querySelector("#export-md"),
  exportCsv: document.querySelector("#export-csv"),
  exportJson: document.querySelector("#export-json"),
  generateButton: document.querySelector("#generate-button"),
  pushButton: document.querySelector("#push-button"),
  settingsForm: document.querySelector("#settings-form"),
  settingsPanel: document.querySelector("#settings-panel"),
  searchInput: document.querySelector("#search-input"),
  timeWindow: document.querySelector("#time-window"),
  bucketFilters: document.querySelector("#bucket-filters"),
  laneFilters: document.querySelector("#lane-filters"),
  feishuWebhook: document.querySelector("#feishu-webhook"),
  wechatWebhook: document.querySelector("#wechat-webhook"),
  reportTopCount: document.querySelector("#report-top-count"),
  configWindowHours: document.querySelector("#config-window-hours"),
  enableAutoPush: document.querySelector("#enable-auto-push"),
  feedCardTemplate: document.querySelector("#feed-card-template"),
};

boot();

async function boot() {
  wireEvents();
  if (location.protocol === "file:") {
    showFileModeWarning();
    return;
  }

  await initializeAppData();
}

function wireEvents() {
  els.generateButton.addEventListener("click", () => generateReport(false));
  els.pushButton.addEventListener("click", () => generateReport(true));
  els.settingsForm.addEventListener("submit", saveConfig);
  els.searchInput.addEventListener("input", (event) => {
    state.filters.search = event.currentTarget.value.trim().toLowerCase();
    renderFeed();
  });
  els.timeWindow.addEventListener("change", (event) => {
    state.filters.windowHours = Number(event.currentTarget.value);
    renderFeed();
  });
  bindChipGroup(els.bucketFilters, "bucket");
  bindChipGroup(els.laneFilters, "lane");
}

function bindChipGroup(container, key) {
  container.addEventListener("click", (event) => {
    const button = event.target.closest(".chip");
    if (!button) {
      return;
    }

    container.querySelectorAll(".chip").forEach((chip) => {
      chip.classList.toggle("is-active", chip === button);
    });
    state.filters[key] = button.dataset[key];
    renderFeed();
  });
}

function showFileModeWarning() {
  els.bootNotice.classList.remove("hidden");
  els.bootNotice.innerHTML = `
    你现在是通过 <code>file://</code> 打开的。中文摘要、定时抓取、导出和机器人推送都依赖本地 API，
    请运行 <code>run.bat</code> 或 <code>start-server.ps1</code> 后，访问
    <a href="http://localhost:8765" target="_blank" rel="noreferrer noopener">http://localhost:8765</a>。
  `;
  els.statusBanner.textContent = "当前是文件模式，后端接口不可用。";
}

async function loadConfig() {
  const config = await api("/api/config");
  state.config = config;
  fillConfigForm(config);
}

async function loadReport() {
  setStatus("正在读取最新早报...");
  const report = await api("/api/report/latest");
  state.report = report;
  applyReportToUI();
  setStatus("最新早报已加载。");
}

async function initializeAppData() {
  try {
    await loadConfig();
    await loadReport();
    enterInteractiveMode();
  } catch (error) {
    await loadPublicStaticSite(error);
  }
}

async function loadPublicStaticSite(cause) {
  state.runtime.mode = "public-static";
  state.runtime.readOnly = true;
  const report = await apiInternal("./latest-report.json", {}, true);
  state.report = report;
  state.config = {
    appName: "AI圈今日要闻",
    reportTopCount: report.topItems?.length || 12,
    timeWindowHours: 72,
    enableAutoPush: false,
    feishuWebhook: "",
    wechatWebhook: "",
  };
  fillConfigForm(state.config);
  applyReportToUI();
  enterReadOnlyMode();
  setStatus("当前是公开只读版，展示的是已生成好的最新早报。");
  showPublicNotice(cause);
}

function enterInteractiveMode() {
  state.runtime.mode = "interactive";
  state.runtime.readOnly = false;
  els.generateButton.disabled = false;
  els.pushButton.disabled = false;
  els.generateButton.classList.remove("hidden");
  els.pushButton.classList.remove("hidden");
  els.settingsPanel.classList.remove("hidden");
}

function enterReadOnlyMode() {
  els.generateButton.classList.add("hidden");
  els.pushButton.classList.add("hidden");
  els.settingsPanel.classList.add("hidden");
}

function showPublicNotice(cause) {
  els.bootNotice.classList.remove("hidden");
  els.bootNotice.innerHTML = `
    当前页面运行在公开只读模式。你可以公开展示最新早报，但“生成早报、保存 Webhook、机器人推送”这类管理功能已隐藏。
    ${cause ? `<br />接口回退原因：${escapeHtml(cause.message || String(cause))}` : ""}
  `;
}

async function generateReport(push) {
  setButtonState(true);
  setStatus(push ? "正在生成并推送..." : "正在抓取、翻译并生成早报...");
  try {
    const report = await api("/api/report/generate", {
      method: "POST",
      body: JSON.stringify({ push }),
    });
    state.report = report;
    applyReportToUI();
    setStatus(push ? "早报已生成并尝试推送到机器人。" : "早报已更新。");
  } catch (error) {
    setStatus(`生成失败：${error.message}`);
  } finally {
    setButtonState(false);
  }
}

async function saveConfig(event) {
  event.preventDefault();
  const payload = {
    appName: "AI圈今日要闻",
    feishuWebhook: els.feishuWebhook.value.trim(),
    wechatWebhook: els.wechatWebhook.value.trim(),
    reportTopCount: Number(els.reportTopCount.value || 12),
    timeWindowHours: Number(els.configWindowHours.value || 72),
    enableAutoPush: els.enableAutoPush.checked,
  };

  setStatus("正在保存配置...");
  try {
    state.config = await api("/api/config", {
      method: "POST",
      body: JSON.stringify(payload),
    });
    fillConfigForm(state.config);
    setStatus("配置已保存。");
  } catch (error) {
    setStatus(`保存失败：${error.message}`);
  }
}

function applyReportToUI() {
  if (!state.report) {
    return;
  }

  els.totalCount.textContent = String(state.report.counts.total);
  els.creatorCount.textContent = String(state.report.counts.creator);
  els.generatedAt.textContent = formatDate(state.report.generatedAt);
  els.briefingMeta.textContent = `共 ${state.report.counts.total} 条内容，覆盖官方、媒体和大V分析。`;
  els.leadCard.innerHTML = `
    <h3>今天先看什么</h3>
    <p>${escapeHtml(state.report.lead)}</p>
  `;

  renderPulse();
  renderTopItems();
  renderTopicPool();
  renderFeed();
  renderSourceStatus();
  updateExportLinks();
}

function renderPulse() {
  const { counts, themes = [] } = state.report;
  const cards = [
    { label: "官方/研究", value: counts.official, text: "第一手信号，适合首发解读。" },
    { label: "行业媒体", value: counts.media, text: "适合跟融资、产品化和案例。" },
    { label: "大V/分析师", value: counts.creator, text: "不是搬运，是判断框架和测评。" },
    {
      label: "今日主题",
      value: themes.length ? themes.map((item) => item.keyword).join(" / ") : "持续跟踪",
      text: "今天最集中被讨论的几个方向。",
    },
  ];

  els.pulseGrid.innerHTML = cards
    .map(
      (card) => `
        <article class="pulse-card">
          <span class="badge">${card.label}</span>
          <span class="pulse-card__value">${escapeHtml(String(card.value))}</span>
          <p>${card.text}</p>
        </article>
      `
    )
    .join("");
}

function renderTopItems() {
  const fragment = document.createDocumentFragment();
  (state.report.topItems || []).forEach((item) => {
    fragment.appendChild(buildFeedCard(item));
  });
  els.topList.innerHTML = "";
  els.topList.appendChild(fragment);
}

function renderTopicPool() {
  const topicPool = state.report.topicPool || [];
  els.topicGrid.innerHTML = topicPool
    .map(
      (item) => `
        <article class="topic-card">
          <span class="badge">选题</span>
          <h3>${escapeHtml(item.topic)}</h3>
          <p>${escapeHtml(item.angle)}</p>
          <div class="topic-card__meta">
            <span>${escapeHtml(item.format)}</span>
            <span>${escapeHtml(item.source)}</span>
          </div>
          <a href="${item.link}" target="_blank" rel="noreferrer noopener">查看原文</a>
        </article>
      `
    )
    .join("");
}

function renderFeed() {
  if (!state.report) {
    return;
  }

  const filtered = getFilteredItems();
  els.feedSummary.textContent = `筛选后共 ${filtered.length} 条，标题和摘要已转成中文。`;

  if (!filtered.length) {
    els.feedList.innerHTML = `<div class="empty-state">当前筛选条件下没有匹配结果。</div>`;
    return;
  }

  const fragment = document.createDocumentFragment();
  filtered.forEach((item) => fragment.appendChild(buildFeedCard(item)));
  els.feedList.innerHTML = "";
  els.feedList.appendChild(fragment);
}

function buildFeedCard(item) {
  const card = els.feedCardTemplate.content.firstElementChild.cloneNode(true);
  card.querySelector(".feed-card__lane").textContent = laneLabel(item.lane);
  card.querySelector(".feed-card__source").textContent = bucketLabel(item.bucket);
  card.querySelector(".feed-card__time").textContent = `${formatDate(item.publishedAt)} · ${item.sourceName}`;
  card.querySelector(".feed-card__title").textContent = item.hotTitle || item.titleZh;
  card.querySelector(".feed-card__original").textContent = `原标题：${item.title}`;
  card.querySelector(".feed-card__summary").textContent = `中文摘要：${item.summaryZh}`;
  card.querySelector(".feed-card__angle").textContent = item.plainTalk;
  card.querySelector(".feed-card__pro").textContent = item.proTake;
  card.querySelector(".score-pill").textContent = `关注优先级 ${item.score}`;
  card.querySelector(".feed-card__link").href = item.link;
  return card;
}

function renderSourceStatus() {
  const rows = state.report.sourceStatus || [];
  els.sourceStatusList.innerHTML = rows
    .map((source) => {
      const detail = source.ok ? `抓取成功 · ${source.count} 条` : `抓取失败 · ${escapeHtml(source.error || "未知错误")}`;
      return `
        <div class="source-row ${source.ok ? "is-ok" : "is-fail"}">
          <div class="source-row__meta">
            <strong>${escapeHtml(source.name)}</strong>
            <span>${escapeHtml(source.url)}</span>
          </div>
          <div class="source-row__bucket">${bucketLabel(source.bucket)}</div>
          <div class="source-row__count">${source.count} 条</div>
          <div class="source-row__status">${detail}</div>
        </div>
      `;
    })
    .join("");
}

function getFilteredItems() {
  const items = state.report.items || [];
  const maxAgeMs = state.filters.windowHours * 60 * 60 * 1000;
  const now = Date.now();
  const query = state.filters.search;

  return items.filter((item) => {
    const ageOk = now - new Date(item.publishedAt).getTime() <= maxAgeMs;
    const bucketOk = state.filters.bucket === "all" || item.bucket === state.filters.bucket;
    const laneOk = state.filters.lane === "all" || item.lane === state.filters.lane;
    const queryOk =
      !query ||
      `${item.titleZh} ${item.title} ${item.summaryZh} ${item.sourceName}`
        .toLowerCase()
        .includes(query);
    return ageOk && bucketOk && laneOk && queryOk;
  });
}

function updateExportLinks() {
  if (!state.report?.exports && state.runtime.mode !== "public-static") {
    return;
  }

  if (state.runtime.mode === "public-static") {
    els.exportMd.href = "./latest-report.md";
    els.exportCsv.href = "./latest-topics.csv";
    els.exportJson.href = "./latest-report.json";
    return;
  }

  els.exportMd.href = state.report.exports.markdown;
  els.exportCsv.href = state.report.exports.csv;
  els.exportJson.href = state.report.exports.json;
}

function fillConfigForm(config) {
  els.feishuWebhook.value = config.feishuWebhook || "";
  els.wechatWebhook.value = config.wechatWebhook || "";
  els.reportTopCount.value = config.reportTopCount || 12;
  els.configWindowHours.value = config.timeWindowHours || 72;
  els.enableAutoPush.checked = Boolean(config.enableAutoPush);
  els.timeWindow.value = String(config.timeWindowHours || 72);
  state.filters.windowHours = Number(config.timeWindowHours || 72);
}

function setButtonState(isBusy) {
  els.generateButton.disabled = isBusy;
  els.pushButton.disabled = isBusy;
  els.generateButton.textContent = isBusy ? "生成中..." : "刷新并生成早报";
  els.pushButton.textContent = isBusy ? "处理中..." : "立即推送到机器人";
}

function setStatus(text) {
  els.statusBanner.textContent = text;
}

async function api(url, options = {}) {
  return apiInternal(url, options, false);
}

async function apiInternal(url, options = {}, silent = false) {
  const response = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
    },
    ...options,
  });

  if (!response.ok) {
    let message = `HTTP ${response.status}`;
    try {
      const payload = await response.json();
      if (payload?.error) {
        message = payload.error;
      }
    } catch {
      // ignore
    }
    if (silent) {
      throw new Error(message);
    }
    throw new Error(message);
  }

  return response.json();
}

function formatDate(value) {
  return new Intl.DateTimeFormat("zh-CN", {
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    timeZone: "Asia/Shanghai",
  }).format(new Date(value));
}

function laneLabel(lane) {
  return (
    {
      upstream: "上游基础设施",
      midstream: "中游模型平台",
      downstream: "下游应用商业化",
      deepdive: "深度分享与测评",
    }[lane] || lane
  );
}

function bucketLabel(bucket) {
  return (
    {
      official: "官方/研究",
      media: "行业媒体",
      creator: "大V/分析师",
    }[bucket] || bucket
  );
}

function escapeHtml(text) {
  return String(text)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
