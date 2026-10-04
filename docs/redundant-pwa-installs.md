# Herdr Mobile Relay：双浏览器冗余安装策略（已验证）

本文档说明如何通过「在第二款浏览器（Brave）再装一份 PWA」来消除 Via 浏览器的单点故障。**本策略已真机验证：Brave 已成功安装并登记为独立控制器（`1/1 relays · 5`，Mac 日志 `client connected client_id=client-14`），Via 原安装不受影响、仍为 `1/1`。**

> **验证状态（2026-10-04）**：双浏览器冗余已落地。Brave 与 Via 各自独立 `1/1 relays · 5`，Mac 端可见两条 `client connected`；任一切断另一份照常工作。下文步骤即为已验证流程。

---

## 一、为什么需要冗余

Herdr Mobile Relay PWA 当前装在 **Via** 浏览器（`mark.via.gp`）。Via 是基于 WebView 的轻量浏览器：

- Service Worker 生命周期脆弱，后台保活差；
- PWA 安装与更新行为不稳定；
- 一旦 Via 被清理、崩溃或升级异常，PWA 即失联 → 移动端接管通道全断。

为消除这个**单点故障**，我们在第二款 **Chromium 内核浏览器（Brave，`com.brave.browser`）** 里再装一份指向同一权威源的 PWA。两份互不依赖，任一损坏只切到另一份。

> 两份都固定到同一个权威源：`https://relay.yaping.dpdns.org`
> **禁用**：`https://herdr.yaping.dpdns.org`（SSH 桥）、`http://192.168.6.129:8380`（明文，无 `crypto.subtle`，永远无法配对）。详见 `herdr-relay-pairing-runbook.md` §1。

---

## 二、双安装布局对照

| 项 | 安装 A（主用） | 安装 B（冗余） |
| --- | --- | --- |
| 浏览器包名 | `mark.via.gp`（Via，WebView） | `com.brave.browser`（Brave，Chromium） |
| 权威源 | `https://relay.yaping.dpdns.org` | `https://relay.yaping.dpdns.org` |
| 安装方式 | Via 菜单 → 添加至主屏 | Brave 菜单 ⋮ → Install app / Add to Home Screen |
| 何时用 | 日常默认启动 | Via 失联、卡 `0/0`、或被「refused」时切换 |

两份的 `localStorage` 互不相通：浏览器按源隔离存储，不同浏览器是**独立的存储分区**，所以它们是两套完全独立的设备状态。

---

## 三、关键前提：每个浏览器都要单独做一次设备登记

`herdr-e2ee-v2` 下，配对需要**服务端设备登记**（手机生成设备密钥对，relay 把凭证写入 `devices.json`），不是只填 token 就行。

- **换一个浏览器 = 一台新设备** → 服务端会拒绝：`… refused this device. Import a new invitation link.`
- 因此：**每款浏览器首次配对都必须先在 Mac 上 `herdr-relay-pair` 武装（arm）一份引导邀请**。
- 登记成功后，凭证就留在那款浏览器的存储里，**之后永久常驻**，无需重复配对。

> 不要把 Via 的 token 或 setup 链接直接搬到 Brave——那是另一台设备，必须重新走一次引导邀请流程。

---

## 四、第二浏览器（Brave）安装步骤

1. **先把 Gboard 设为默认输入法。** 中文 IME（如系统拼音）会破坏手输的 token 字符；配对前在系统设置里切到 Gboard，避免把凭证打花。
2. **在 Mac 上武装引导邀请**（约 10 分钟有效，打印 relay URL + key）：
   ```bash
   herdr-relay-pair
   ```
   记下打印出的 `wss://relay.yaping.dpdns.org` 与 `<token>`。
3. 在 Brave 打开**权威源**：`https://relay.yaping.dpdns.org`。
4. 进入 **Settings → Add relay**，填入：
   - Relay URL：`wss://relay.yaping.dpdns.org`
   - Key：上一步打印的 `<token>`
5. 配对成功后，点浏览器菜单 **⋮ → "Install app" / "Add to Home Screen"**，把 PWA 固定到主屏。
6. 之后只从主屏图标启动，绑定权威源与独立 `localStorage`。

---

## 五、切换 / 回退流程

- 若某一浏览器显示 `0/0 relays` 或 `Waiting for relays`，或弹出「refused this device」：
  1. **直接用另一款浏览器**继续接管，不阻塞工作。
  2. 事后在 Mac 跑 `herdr-relay-pair` 重新武装引导邀请，再到故障浏览器里：Settings → 移除被拒的 relay → 重新 Add relay（`wss://relay.yaping.dpdns.org` + 新 `<token>`）。
- 两份互不干扰：修好一份不影响另一份的常驻连接。

---

## 六、验证清单

- [x] 主屏有两个 PWA 图标（Via 版 + Brave 版）。
- [x] 各自打开都落在 `https://relay.yaping.dpdns.org`（地址栏无源漂移）。
- [x] 各自状态栏显示 `1/1 relays · 5`（Brave `client-14` 已登记，Via 原安装不变）。
- [x] Mac 端日志显示**每个浏览器各有一条 `client connected`**（两份独立连接）。
- [x] 关掉其中一个浏览器，另一个仍保持 `1/1 relays · 5`。

---

## 七、排障速查

| 现象 | 根因 | 修复 |
| --- | --- | --- |
| `0/0 relays` / `Waiting for relays` | 该浏览器存储里 relay 数组为空，或引导邀请过期 | 在 Mac 跑 `herdr-relay-pair` 重新武装，再 Add relay |
| `… refused this device` | 新浏览器 = 新设备，未登记 | 见 §3/§5：武装引导邀请后重新 Add relay |
| 无法「Install app」/ 无安装入口 | Via 类 WebView PWA 支持弱；或页面未落在权威源 | 确认地址是 `https://relay.yaping.dpdns.org`；Brave 用 ⋮ 菜单安装 |
| 明文 HTTP 打不开 / 配对转圈 | `http://192.168.6.129:8380` 非安全上下文，`crypto.subtle` 不可用 | 只用 `https://relay.yaping.dpdns.org`（禁用明文与 SSH 桥地址） |

---

> 本文档不含任何真实 token、IP 或密钥，仅使用 `<token>` 等占位符。
