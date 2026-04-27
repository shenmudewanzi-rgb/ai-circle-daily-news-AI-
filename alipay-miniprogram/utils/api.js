const config = require("./config");
const mockReport = require("../mock/report");

function requestAbsolute(url) {
  return new Promise((resolve, reject) => {
    my.request({
      url,
      method: "GET",
      dataType: "json",
      success(res) {
        if (res.status >= 200 && res.status < 300) {
          resolve({ data: res.data, fromMock: false });
          return;
        }
        reject(new Error(`HTTP ${res.status}`));
      },
      fail(error) {
        reject(error);
      },
    });
  });
}

function request(path) {
  if (config.publicDataUrl) {
    return requestAbsolute(config.publicDataUrl).catch((error) => {
      if (config.useMockWhenOffline) {
        return { data: mockReport, fromMock: true, fallbackError: error.message || "request failed" };
      }
      throw error;
    });
  }

  if (!config.apiBaseUrl) {
    return Promise.resolve({ data: mockReport, fromMock: true });
  }

  return requestAbsolute(`${config.apiBaseUrl}${path}`).catch((error) => {
    if (config.useMockWhenOffline) {
      return { data: mockReport, fromMock: true, fallbackError: error.message || "request failed" };
    }
    throw error;
  });
}

module.exports = {
  getLatestReport() {
    return request("/api/report/latest");
  },
};
