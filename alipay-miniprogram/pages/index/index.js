const api = require("../../utils/api");

Page({
  data: {
    loading: true,
    usingMock: false,
    statusText: "正在加载早报...",
    report: null,
    stats: [],
    topItems: [],
    topicPool: [],
    allItems: [],
  },

  onLoad() {
    this.loadReport();
  },

  onPullDownRefresh() {
    this.loadReport(() => my.stopPullDownRefresh());
  },

  loadReport(done) {
    this.setData({
      loading: true,
      statusText: "正在加载早报...",
    });

    api.getLatestReport()
      .then(({ data, fromMock, fallbackError }) => {
        this.setData({
          loading: false,
          usingMock: fromMock,
          statusText: fromMock
            ? `当前展示的是内置样例数据${fallbackError ? `，原因：${fallbackError}` : ""}`
            : "已连接公开早报数据。",
          report: data,
          stats: buildStats(data),
          topItems: decorateItems(data.topItems || []),
          topicPool: data.topicPool || [],
          allItems: decorateItems(data.items || []),
        });
      })
      .catch((error) => {
        my.showToast({
          type: "fail",
          content: "加载失败",
        });
        this.setData({
          loading: false,
          statusText: error.message || "加载失败",
        });
      })
      .finally(() => {
        if (typeof done === "function") {
          done();
        }
      });
  },
});

function buildStats(report) {
  if (!report || !report.counts) {
    return [];
  }

  return [
    { label: "今日资讯", value: report.counts.total },
    { label: "大V/分析师", value: report.counts.creator },
    { label: "官方/研究", value: report.counts.official },
    { label: "上游信号", value: report.counts.upstream },
  ];
}

function decorateItems(items) {
  return items.map((item) => ({
    ...item,
    laneText: laneLabel(item.lane),
    bucketText: bucketLabel(item.bucket),
  }));
}

function laneLabel(value) {
  return {
    upstream: "上游基础设施",
    midstream: "中游模型平台",
    downstream: "下游应用商业化",
    deepdive: "深度分享与测评",
  }[value] || value;
}

function bucketLabel(value) {
  return {
    official: "官方/研究",
    media: "行业媒体",
    creator: "大V/分析师",
  }[value] || value;
}
