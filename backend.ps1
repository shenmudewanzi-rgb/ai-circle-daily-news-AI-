$script:WorkspaceRoot = $PSScriptRoot
$script:DataDir = Join-Path $script:WorkspaceRoot "data"
$script:ExportsDir = Join-Path $script:WorkspaceRoot "exports"
$script:ConfigPath = Join-Path $script:DataDir "config.json"
$script:LatestReportPath = Join-Path $script:DataDir "latest-report.json"
$script:TranslationCache = @{}

function ConvertTo-AIDailyHashtable {
  param(
    [Parameter(Mandatory)]
    $InputObject
  )

  $result = @{}
  foreach ($property in $InputObject.PSObject.Properties) {
    $result[$property.Name] = $property.Value
  }
  $result
}

function Initialize-AIDailyEnvironment {
  foreach ($path in @($script:DataDir, $script:ExportsDir)) {
    if (-not (Test-Path -LiteralPath $path)) {
      New-Item -ItemType Directory -Path $path | Out-Null
    }
  }

  if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
    $defaultJson = (Get-DefaultAIDailyConfig) | ConvertTo-Json -Depth 6
    $defaultJson | Set-Content -LiteralPath $script:ConfigPath -Encoding utf8
  }
}

function Get-DefaultAIDailyConfig {
  [ordered]@{
    appName = "AI圈今日要闻"
    reportTopCount = 12
    timeWindowHours = 72
    enableAutoPush = $false
    feishuWebhook = ""
    wechatWebhook = ""
  }
}

function Get-AIDailyConfig {
  Initialize-AIDailyEnvironment
  $default = Get-DefaultAIDailyConfig
  if (-not (Test-Path -LiteralPath $script:ConfigPath)) {
    return [pscustomobject]$default
  }

  try {
    $raw = Get-Content -LiteralPath $script:ConfigPath -Raw -Encoding utf8
    $saved = if ($raw.Trim()) { ConvertTo-AIDailyHashtable -InputObject ($raw | ConvertFrom-Json) } else { @{} }
  } catch {
    $saved = @{}
  }

  foreach ($key in $default.Keys) {
    if (-not $saved.ContainsKey($key)) {
      $saved[$key] = $default[$key]
    }
  }

  [pscustomobject]$saved
}

function Save-AIDailyConfig {
  param(
    [Parameter(Mandatory)]
    [hashtable]$Config
  )

  foreach ($path in @($script:DataDir, $script:ExportsDir)) {
    if (-not (Test-Path -LiteralPath $path)) {
      New-Item -ItemType Directory -Path $path | Out-Null
    }
  }
  $merged = @{}
  $default = Get-DefaultAIDailyConfig
  foreach ($key in $default.Keys) {
    $merged[$key] = if ($Config.ContainsKey($key)) { $Config[$key] } else { $default[$key] }
  }

  ($merged | ConvertTo-Json -Depth 6) | Set-Content -LiteralPath $script:ConfigPath -Encoding utf8
  [pscustomobject]$merged
}

function Get-AIDailySources {
  @(
    @{ id = "openai"; name = "OpenAI News"; bucket = "official"; lane = "midstream"; url = "https://openai.com/news/rss.xml"; credibility = 10; tags = @("官方", "模型", "平台") }
    @{ id = "google-ai"; name = "Google AI Blog"; bucket = "official"; lane = "midstream"; url = "https://blog.google/innovation-and-ai/technology/ai/rss/"; credibility = 9; tags = @("官方", "AI", "产品") }
    @{ id = "microsoft-ai"; name = "Microsoft AI Blog"; bucket = "official"; lane = "midstream"; url = "https://blogs.microsoft.com/ai/feed/"; credibility = 8; tags = @("官方", "企业", "平台") }
    @{ id = "huggingface"; name = "Hugging Face Blog"; bucket = "official"; lane = "midstream"; url = "https://huggingface.co/blog/feed.xml"; credibility = 8; tags = @("开源", "模型", "社区") }
    @{ id = "nvidia"; name = "NVIDIA Blog"; bucket = "official"; lane = "upstream"; url = "https://blogs.nvidia.com/feed/"; credibility = 9; tags = @("芯片", "算力", "基础设施") }
    @{ id = "arxiv-ai"; name = "arXiv cs.AI"; bucket = "official"; lane = "upstream"; url = "https://rss.arxiv.org/rss/cs.AI"; credibility = 7; tags = @("研究", "论文", "算法") }
    @{ id = "techcrunch-ai"; name = "TechCrunch AI"; bucket = "media"; lane = "downstream"; url = "https://techcrunch.com/category/artificial-intelligence/feed/"; credibility = 8; tags = @("媒体", "融资", "产品") }
    @{ id = "venturebeat-ai"; name = "VentureBeat AI"; bucket = "media"; lane = "downstream"; url = "https://venturebeat.com/category/ai/feed"; credibility = 8; tags = @("媒体", "企业", "应用") }
    @{ id = "decoder"; name = "The Decoder"; bucket = "media"; lane = "downstream"; url = "https://the-decoder.com/tag/artificial-intelligence/feed/"; credibility = 8; tags = @("媒体", "趋势", "AI") }
    @{ id = "bens-bites"; name = "Ben's Bites"; bucket = "creator"; lane = "deepdive"; url = "https://www.bensbites.com/feed"; credibility = 8; tags = @("大V", "简报", "趋势") }
    @{ id = "one-useful-thing"; name = "One Useful Thing"; bucket = "creator"; lane = "deepdive"; url = "https://www.oneusefulthing.org/feed"; credibility = 9; tags = @("Ethan Mollick", "教育", "洞察") }
    @{ id = "simon-willison"; name = "Simon Willison"; bucket = "creator"; lane = "deepdive"; url = "https://simonwillison.net/atom/everything/"; credibility = 9; tags = @("开发者", "实测", "点评") }
    @{ id = "latent-space"; name = "Latent Space"; bucket = "creator"; lane = "deepdive"; url = "https://www.latent.space/feed"; credibility = 8; tags = @("播客", "行业", "趋势") }
    @{ id = "import-ai"; name = "Import AI"; bucket = "creator"; lane = "deepdive"; url = "https://importai.substack.com/feed"; credibility = 9; tags = @("研究", "政策", "策略") }
    @{ id = "understanding-ai"; name = "Understanding AI"; bucket = "creator"; lane = "deepdive"; url = "https://www.understandingai.org/feed"; credibility = 8; tags = @("解释", "测评", "科普") }
    @{ id = "interconnects"; name = "Interconnects"; bucket = "creator"; lane = "deepdive"; url = "https://www.interconnects.ai/feed"; credibility = 8; tags = @("模型", "观点", "分析") }
    @{ id = "ai-snake-oil"; name = "AI Snake Oil"; bucket = "creator"; lane = "deepdive"; url = "https://www.aisnakeoil.com/feed"; credibility = 8; tags = @("批判", "测评", "科普") }
    @{ id = "strangeloopcanon"; name = "Strange Loop Canon"; bucket = "creator"; lane = "deepdive"; url = "https://www.strangeloopcanon.com/feed"; credibility = 8; tags = @("深度", "推理", "行业") }
    @{ id = "exponential-view"; name = "Exponential View"; bucket = "creator"; lane = "deepdive"; url = "https://www.exponentialview.co/feed"; credibility = 8; tags = @("商业", "科技", "洞察") }
  ) | ForEach-Object { [pscustomobject]$_ }
}

function Invoke-AIDailyFetch {
  param(
    [Parameter(Mandatory)]
    [string]$Url
  )

  $headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Safari/537.36"
  }

  $candidates = @(
    $Url,
    ("https://api.codetabs.com/v1/proxy?quest=" + [uri]::EscapeDataString($Url)),
    ("https://api.allorigins.win/raw?url=" + [uri]::EscapeDataString($Url))
  )

  $lastError = $null
  foreach ($candidate in $candidates) {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $candidate -Headers $headers -TimeoutSec 25
      if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        return $response.Content
      }
    } catch {
      $lastError = $_
    }
  }

  throw $lastError
}

function Parse-AIDailyFeed {
  param(
    [Parameter(Mandatory)]
    [string]$Raw,
    [Parameter(Mandatory)]
    [pscustomobject]$Source
  )

  try {
    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml($Raw)
  } catch {
    throw "无法解析 $($Source.name) 的 Feed。"
  }

  $nodes = @($doc.SelectNodes("//*[local-name()='item' or local-name()='entry']"))
  $items = foreach ($node in $nodes) {
    $title = Get-AIDailyNodeText -Node $node -Names @("title")
    $linkNode = $node.SelectSingleNode("*[local-name()='link' and @href]")
    $link = if ($linkNode) { $linkNode.GetAttribute("href") } else { Get-AIDailyNodeText -Node $node -Names @("link", "guid") }
    $published = Get-AIDailyNodeText -Node $node -Names @("pubDate", "published", "updated", "date")
    $summary = Get-AIDailyNodeText -Node $node -Names @("description", "summary", "encoded", "content")
    if ([string]::IsNullOrWhiteSpace($title) -or [string]::IsNullOrWhiteSpace($link)) {
      continue
    }

    [pscustomobject]@{
      id = "$($Source.id)-$([guid]::NewGuid().ToString('N'))"
      sourceId = $Source.id
      sourceName = $Source.name
      bucket = $Source.bucket
      lane = $Source.lane
      sourceUrl = $Source.url
      title = (Clear-AIDailyText $title)
      link = $link
      publishedAt = (ConvertTo-AIDailyIsoDate $published)
      summary = (Clear-AIDailyText $summary)
      credibility = $Source.credibility
      tags = $Source.tags
    }
  }

  @($items | Select-Object -First 12)
}

function Get-AIDailyNodeText {
  param(
    [Parameter(Mandatory)]
    [System.Xml.XmlNode]$Node,
    [Parameter(Mandatory)]
    [string[]]$Names
  )

  foreach ($name in $Names) {
    $candidate = $Node.SelectSingleNode("*[local-name()='$name']")
    if ($candidate -and -not [string]::IsNullOrWhiteSpace($candidate.InnerText)) {
      return $candidate.InnerText.Trim()
    }
  }

  ""
}

function Clear-AIDailyText {
  param(
    [AllowNull()]
    [string]$Text
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  [System.Net.WebUtility]::HtmlDecode(
    ($Text -replace "<!\[CDATA\[|\]\]>", "" -replace "<[^>]+>", " " -replace "\s+", " ").Trim()
  )
}

function ConvertTo-AIDailyIsoDate {
  param(
    [AllowNull()]
    [string]$Value
  )

  try {
    if ([string]::IsNullOrWhiteSpace($Value)) {
      return (Get-Date).ToString("o")
    }
    return ([datetime]$Value).ToUniversalTime().ToString("o")
  } catch {
    return (Get-Date).ToString("o")
  }
}

function Get-AIDailyNormalizedKey {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $title = ($Item.title -replace "[^\p{L}\p{Nd}]+", "").ToLowerInvariant()
  $link = ($Item.link -replace "\?.*$", "" -replace "#.*$", "").ToLowerInvariant()
  "$title|$link"
}

function Test-AIDailyIsNewsworthy {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $haystack = ("{0} {1} {2}" -f $Item.title, $Item.link, $Item.summary).ToLowerInvariant()
  $blockedPatterns = @(
    "what is codex",
    "how to start",
    "collaborating with codex",
    "codex settings",
    "plugins and skills",
    "/academy/",
    "/help/",
    "/docs/"
  )

  foreach ($pattern in $blockedPatterns) {
    if ($haystack -like "*$pattern*") {
      return $false
    }
  }

  $true
}

function Test-AIDailyIsRelevantAI {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $haystack = ("{0} {1} {2}" -f $Item.title, $Item.summary, ($Item.tags -join " ")).ToLowerInvariant()
  $keywords = @(
    " ai ",
    "artificial intelligence",
    "openai",
    "gpt",
    "claude",
    "gemini",
    "llm",
    "model",
    "agent",
    "inference",
    "training",
    "multimodal",
    "codex",
    "rag",
    "chip",
    "gpu",
    "tpu",
    "大v",
    "测评",
    "模型",
    "人工智能",
    "算力",
    "推理",
    "芯片"
  )

  foreach ($keyword in $keywords) {
    if ($haystack -like "*$keyword*") {
      return $true
    }
  }

  $false
}

function Merge-AIDailyItems {
  param(
    [Parameter(Mandatory)]
    [object[]]$Items
  )

  $map = @{}
  foreach ($item in $Items) {
    $key = Get-AIDailyNormalizedKey -Item $item
    if (-not $map.ContainsKey($key) -or $map[$key].credibility -lt $item.credibility) {
      $map[$key] = $item
    }
  }

  @($map.Values)
}

function Test-AIDailyNeedsTranslation {
  param(
    [AllowNull()]
    [string]$Text
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return $false
  }

  return ($Text -notmatch "[\p{IsCJKUnifiedIdeographs}]")
}

function Invoke-AIDailyTranslate {
  param(
    [AllowNull()]
    [string]$Text
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $clean = ($Text -replace "\s+", " ").Trim()
  if (-not (Test-AIDailyNeedsTranslation -Text $clean)) {
    return $clean
  }

  $trimmed = if ($clean.Length -gt 500) { $clean.Substring(0, 500) } else { $clean }
  if ($script:TranslationCache.ContainsKey($trimmed)) {
    return $script:TranslationCache[$trimmed]
  }

  $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh-CN&dt=t&q=" + [uri]::EscapeDataString($trimmed)
  try {
    $json = (Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 20).Content | ConvertFrom-Json
    $translated = (($json[0] | ForEach-Object { $_[0] }) -join "").Trim()
    if ([string]::IsNullOrWhiteSpace($translated)) {
      $translated = $clean
    }
  } catch {
    $translated = $clean
  }

  $script:TranslationCache[$trimmed] = $translated
  $translated
}

function Compress-AIDailyChineseText {
  param(
    [AllowNull()]
    [string]$Text,
    [int]$MaxLength = 110
  )

  if ([string]::IsNullOrWhiteSpace($Text)) {
    return ""
  }

  $segments = [regex]::Split($Text, "(?<=[。！？；!?])") | Where-Object { $_.Trim() }
  $result = ""
  foreach ($segment in $segments) {
    if (($result + $segment).Length -gt $MaxLength) {
      break
    }
    $result += $segment
  }

  if ([string]::IsNullOrWhiteSpace($result)) {
    $result = if ($Text.Length -gt $MaxLength) { $Text.Substring(0, $MaxLength).Trim() + "..." } else { $Text.Trim() }
  }

  $result.Trim()
}

function Get-AIDailyLane {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $haystack = ("{0} {1} {2}" -f $Item.title, $Item.summary, ($Item.tags -join " ")).ToLowerInvariant()

  if ($Item.bucket -eq "creator") {
    return "deepdive"
  }
  if ($haystack -match "gpu|chip|cluster|cuda|datacenter|cloud|paper|dataset|inference|training") {
    return "upstream"
  }
  if ($haystack -match "model|llm|gpt|claude|gemini|open source|weights|sdk|api|agent|multimodal") {
    return "midstream"
  }
  if ($haystack -match "enterprise|workflow|ads|marketing|commerce|copilot|assistant|customer|business") {
    return "downstream"
  }

  $Item.lane
}

function Get-AIDailyScore {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $ageHours = [math]::Max(0, ((Get-Date) - [datetime]$Item.publishedAt).TotalHours)
  $score = ($Item.credibility * 10) + [math]::Max(0, 120 - ($ageHours * 1.4))

  if ($Item.bucket -eq "official") {
    $score += 8
  }
  if ($Item.bucket -eq "creator") {
    $score += 5
  }
  if ($Item.title -match "release|launch|announce|benchmark|agent|open source|API|评测|测评|教程") {
    $score += 12
  }

  [math]::Round($score)
}

function New-AIDailyHotTitle {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $titleZh = $Item.titleZh
  switch ($Item.lane) {
    "upstream" { return "上游有新信号：$titleZh" }
    "midstream" { return "模型圈新动作：$titleZh" }
    "downstream" { return "应用端值得盯：$titleZh" }
    "deepdive" { return "大V开讲：$titleZh" }
    default { return "今天的AI爆点：$titleZh" }
  }
}

function New-AIDailyPlainTalk {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  switch ($Item.lane) {
    "upstream" { return "说人话：底层算力、芯片或研究又有新动静了，后面会影响模型成本、速度和谁能率先把产品做大。" }
    "midstream" { return "说人话：模型和平台层又出了新能力，离普通用户更近一步，也会带动新一轮教程、横评和对比内容。" }
    "downstream" { return "说人话：这类新闻离真实业务更近，重点看它能不能帮团队提效、降本，或者做出新产品。" }
    "deepdive" { return "说人话：这不是简单搬运新闻，而是有人替你先踩坑、先上手、先做判断，适合快速补课。" }
    default { return "说人话：这条动态值得看，因为它不仅有信息量，还可能改变接下来几天的内容热点。" }
  }
}

function New-AIDailyProTake {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  switch ($Item.lane) {
    "upstream" { return "内行看门道：上游变化通常先影响训练/推理成本、供给节奏和生态站队，往往比产品层更早释放风向。" }
    "midstream" { return "内行看门道：模型平台层的更新最容易带来分发、接口能力和开发门槛的变化，值得盯兼容性和生态响应。" }
    "downstream" { return "内行看门道：下游应用新闻真正要看的是留存、付费、场景深度和组织流程重构，不只是功能上新。" }
    "deepdive" { return "内行看门道：大V/分析师的价值不在'快'，而在把二手信息变成判断框架，适合做选题二次加工。" }
    default { return "内行看门道：可以从传播势能、产业位置和可复用方法论三个角度继续拆。" }
  }
}

function Complete-AIDailyItem {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $titleZh = Invoke-AIDailyTranslate -Text $Item.title
  $summarySource = if ($Item.summary) { $Item.summary } else { $Item.title }
  $summaryZhRaw = Invoke-AIDailyTranslate -Text $summarySource
  $summaryZh = Compress-AIDailyChineseText -Text $summaryZhRaw -MaxLength 110
  $lane = Get-AIDailyLane -Item $Item
  $score = Get-AIDailyScore -Item $Item

  [pscustomobject]@{
    id = $Item.id
    sourceId = $Item.sourceId
    sourceName = $Item.sourceName
    bucket = $Item.bucket
    lane = $lane
    sourceUrl = $Item.sourceUrl
    title = $Item.title
    titleZh = $titleZh
    hotTitle = ""
    link = $Item.link
    publishedAt = $Item.publishedAt
    summary = $Item.summary
    summaryZh = if ($summaryZh) { $summaryZh } else { "$titleZh。建议查看原文了解完整细节。" }
    plainTalk = ""
    proTake = ""
    tags = $Item.tags
    credibility = $Item.credibility
    score = $score
  }
}

function Finalize-AIDailyItem {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Item
  )

  $Item.hotTitle = New-AIDailyHotTitle -Item $Item
  $Item.plainTalk = New-AIDailyPlainTalk -Item $Item
  $Item.proTake = New-AIDailyProTake -Item $Item
  $Item
}

function Get-AIDailyTopThemes {
  param(
    [Parameter(Mandatory)]
    [object[]]$Items
  )

  $keywords = @(
    "Agent", "OpenAI", "Google", "Claude", "Gemini", "开源", "推理", "AI视频", "芯片", "企业应用", "评测", "工作流"
  )

  $matches = foreach ($keyword in $keywords) {
    $count = @($Items | Where-Object {
      ($_.titleZh + " " + $_.summaryZh + " " + ($_.tags -join " ")) -match [regex]::Escape($keyword)
    }).Count
    if ($count -gt 0) {
      [pscustomobject]@{ keyword = $keyword; count = $count }
    }
  }

  @($matches | Sort-Object count -Descending | Select-Object -First 4)
}

function New-AIDailyLead {
  param(
    [Parameter(Mandatory)]
    [object[]]$Items
  )

  $official = @($Items | Where-Object { $_.bucket -eq "official" }).Count
  $creator = @($Items | Where-Object { $_.bucket -eq "creator" }).Count
  $themes = Get-AIDailyTopThemes -Items $Items
  $themeText = if ($themes.Count -gt 0) { ($themes.keyword -join "、") } else { "模型更新、产业动向和测评观点" }

  "今天这份《AI圈今日要闻》里，官方/研究信号有 $official 条，大V/分析师深度内容有 $creator 条。主线集中在 $themeText。外行能快速看懂'发生了什么'，内行可以顺着产业位置、成本变化和生态站队继续深挖。"
}

function New-AIDailyTopicPool {
  param(
    [Parameter(Mandatory)]
    [object[]]$Items
  )

  $result = foreach ($item in ($Items | Select-Object -First 8)) {
    $format = switch ($item.lane) {
      "upstream" { "产业链解读 / 图解长图" }
      "midstream" { "功能拆解 / 横评短视频" }
      "downstream" { "案例分析 / 增长复盘" }
      "deepdive" { "观点提炼 / 直播串讲" }
      default { "图文快评" }
    }

    [pscustomobject]@{
      topic = $item.hotTitle
      angle = $item.plainTalk
      format = $format
      source = $item.sourceName
      link = $item.link
    }
  }

  @($result)
}

function Format-AIDailyDate {
  param(
    [Parameter(Mandatory)]
    [datetime]$Date
  )

  $china = [System.TimeZoneInfo]::FindSystemTimeZoneById("China Standard Time")
  [System.TimeZoneInfo]::ConvertTime($Date, $china).ToString("yyyy-MM-dd HH:mm")
}

function Export-AIDailyReport {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Report
  )

  Initialize-AIDailyEnvironment

  $dateStamp = ([datetime]$Report.generatedAt).ToString("yyyy-MM-dd")
  $jsonLatest = Join-Path $script:ExportsDir "latest-report.json"
  $mdLatest = Join-Path $script:ExportsDir "latest-report.md"
  $csvLatest = Join-Path $script:ExportsDir "latest-topics.csv"

  $jsonNamed = Join-Path $script:ExportsDir ("AI圈今日要闻_{0}.json" -f $dateStamp)
  $mdNamed = Join-Path $script:ExportsDir ("AI圈今日要闻_{0}.md" -f $dateStamp)
  $csvNamed = Join-Path $script:ExportsDir ("AI圈今日要闻_{0}.csv" -f $dateStamp)

  $json = $Report | ConvertTo-Json -Depth 8
  $json | Set-Content -LiteralPath $jsonLatest -Encoding utf8
  $json | Set-Content -LiteralPath $jsonNamed -Encoding utf8

  $markdown = New-AIDailyMarkdown -Report $Report
  $markdown | Set-Content -LiteralPath $mdLatest -Encoding utf8
  $markdown | Set-Content -LiteralPath $mdNamed -Encoding utf8

  $rows = $Report.topicPool | Select-Object topic, angle, format, source, link
  $rows | Export-Csv -LiteralPath $csvLatest -Encoding utf8 -NoTypeInformation
  $rows | Export-Csv -LiteralPath $csvNamed -Encoding utf8 -NoTypeInformation
}

function New-AIDailyMarkdown {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Report
  )

  $lines = New-Object System.Collections.Generic.List[string]
  foreach ($line in @(
      "# AI圈今日要闻",
      "",
      "生成时间：$(Format-AIDailyDate -Date ([datetime]$Report.generatedAt))",
      "",
      "## 今日导读",
      $Report.lead,
      "",
      "## 今日爆点"
    )) {
    $lines.Add($line)
  }

  foreach ($item in $Report.topItems) {
    $lines.Add("- **$($item.hotTitle)**：$($item.summaryZh)")
  }

  foreach ($line in @(
      "",
      "## 公众号选题池"
    )) {
    $lines.Add($line)
  }

  foreach ($item in $Report.topicPool) {
    $lines.Add("- **$($item.topic)**｜形式：$($item.format)｜角度：$($item.angle)")
  }

  foreach ($line in @(
      "",
      "## 全量资讯"
    )) {
    $lines.Add($line)
  }

  foreach ($item in $Report.items) {
    foreach ($line in @(
        "### $($item.titleZh)",
        "- 原标题：$($item.title)",
        "- 来源：$($item.sourceName) / $($item.bucket) / $($item.lane)",
        "- 时间：$(Format-AIDailyDate -Date ([datetime]$item.publishedAt))",
        "- 中文摘要：$($item.summaryZh)",
        "- 说人话：$($item.plainTalk)",
        "- 内行看门道：$($item.proTake)",
        "- 原文：$($item.link)",
        ""
      )) {
      $lines.Add($line)
    }
  }

  [string]::Join("`n", $lines)
}

function Send-AIDailyPush {
  param(
    [Parameter(Mandatory)]
    [pscustomobject]$Report
  )

  $config = Get-AIDailyConfig
  $summaryLines = @(
    "AI圈今日要闻",
    "",
    $Report.lead,
    ""
  )
  foreach ($item in ($Report.topItems | Select-Object -First 6)) {
    $summaryLines += "- $($item.hotTitle)"
    $summaryLines += "  $($item.summaryZh)"
  }

  $plainText = ($summaryLines -join "`n").Trim()
  $markdown = ($summaryLines -join "`n").Trim()
  $sentChannels = @()

  if ($config.feishuWebhook) {
    $body = @{
      msg_type = "text"
      content = @{
        text = $plainText
      }
    } | ConvertTo-Json -Depth 6

    Invoke-RestMethod -Method Post -Uri $config.feishuWebhook -Body $body -ContentType "application/json; charset=utf-8" | Out-Null
    $sentChannels += "feishu"
  }

  if ($config.wechatWebhook) {
    $body = @{
      msgtype = "markdown"
      markdown = @{
        content = $markdown
      }
    } | ConvertTo-Json -Depth 6

    Invoke-RestMethod -Method Post -Uri $config.wechatWebhook -Body $body -ContentType "application/json; charset=utf-8" | Out-Null
    $sentChannels += "wechat"
  }

  $sentChannels
}

function New-AIDailyReport {
  param(
    [switch]$Persist,
    [switch]$Push
  )

  Initialize-AIDailyEnvironment
  $config = Get-AIDailyConfig
  $sources = Get-AIDailySources
  $sourceStates = New-Object System.Collections.Generic.List[object]
  $allItems = New-Object System.Collections.Generic.List[object]

  foreach ($source in $sources) {
    try {
      $raw = Invoke-AIDailyFetch -Url $source.url
      $items = Parse-AIDailyFeed -Raw $raw -Source $source | Select-Object -First 8
      foreach ($item in $items) {
        $allItems.Add($item)
      }
      $sourceStates.Add([pscustomobject]@{
        id = $source.id
        name = $source.name
        bucket = $source.bucket
        ok = $true
        count = @($items).Count
        url = $source.url
        error = ""
      })
    } catch {
      $sourceStates.Add([pscustomobject]@{
        id = $source.id
        name = $source.name
        bucket = $source.bucket
        ok = $false
        count = 0
        url = $source.url
        error = $_.Exception.Message
      })
    }
  }

  $recentCutoff = (Get-Date).AddHours(-[int]$config.timeWindowHours)
  $deduped = Merge-AIDailyItems -Items (
    $allItems |
      Where-Object {
        (Test-AIDailyIsNewsworthy -Item $_) -and
        (Test-AIDailyIsRelevantAI -Item $_)
      }
  )
  $recentRawItems = @(
    $deduped |
      Where-Object { [datetime]$_.publishedAt -ge $recentCutoff } |
      Sort-Object publishedAt -Descending |
      Select-Object -First 60
  )

  $completed = foreach ($item in $recentRawItems) {
    $full = Complete-AIDailyItem -Item $item
    Finalize-AIDailyItem -Item $full
  }

  $filtered = @($completed | Sort-Object score -Descending)
  $topCount = [math]::Max(6, [int]$config.reportTopCount)
  $topItems = @($filtered | Select-Object -First $topCount)
  $topicPool = New-AIDailyTopicPool -Items $topItems
  $counts = [pscustomobject]@{
    total = @($filtered).Count
    official = @($filtered | Where-Object { $_.bucket -eq "official" }).Count
    media = @($filtered | Where-Object { $_.bucket -eq "media" }).Count
    creator = @($filtered | Where-Object { $_.bucket -eq "creator" }).Count
    upstream = @($filtered | Where-Object { $_.lane -eq "upstream" }).Count
    midstream = @($filtered | Where-Object { $_.lane -eq "midstream" }).Count
    downstream = @($filtered | Where-Object { $_.lane -eq "downstream" }).Count
    deepdive = @($filtered | Where-Object { $_.lane -eq "deepdive" }).Count
  }

  $report = [pscustomobject]@{
    appName = $config.appName
    generatedAt = (Get-Date).ToString("o")
    lead = (New-AIDailyLead -Items $topItems)
    counts = $counts
    themes = (Get-AIDailyTopThemes -Items $topItems)
    topItems = $topItems
    topicPool = $topicPool
    items = $filtered
    sourceStatus = $sourceStates.ToArray()
    exports = [pscustomobject]@{
      json = "/exports/latest-report.json"
      markdown = "/exports/latest-report.md"
      csv = "/exports/latest-topics.csv"
    }
  }

  if ($Persist) {
    ($report | ConvertTo-Json -Depth 8) | Set-Content -LiteralPath $script:LatestReportPath -Encoding utf8
    Export-AIDailyReport -Report $report
  }

  if ($Push) {
    $channels = Send-AIDailyPush -Report $report
    $report | Add-Member -NotePropertyName pushedChannels -NotePropertyValue $channels -Force
  }

  $report
}

function Get-AIDailyLatestReport {
  param(
    [switch]$Refresh
  )

  Initialize-AIDailyEnvironment
  if ($Refresh -or -not (Test-Path -LiteralPath $script:LatestReportPath)) {
    return New-AIDailyReport -Persist
  }

  try {
    Get-Content -LiteralPath $script:LatestReportPath -Raw -Encoding utf8 | ConvertFrom-Json
  } catch {
    New-AIDailyReport -Persist
  }
}
