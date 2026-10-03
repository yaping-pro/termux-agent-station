# Herdr 移动端远程操控最佳实践（已验证）

本文档总结在 Android 手机（Termux 工作站 + Herdr 智能体）上做移动远程操控的端到端最佳实践。所有结论均来自真机验证（vivo iQOO，Android 16 / OriginOS，Termux 0.119）。

---

## 一、三条通道，各司其职

移动远程操控共有三条通道，按场景选用，不要混用：

| 通道 | 形态 | 何时使用 |
| --- | --- | --- |
| **(a) Termux + Mosh** | 手机本地原生 SSH 会话，Mosh 抗抖动 | **深度终端操作**：本地编译、跑测试、改文件、长滚动回看。重负载全在手机本地，只传字符流，延迟压到 WireGuard 直连物理下限（常 < 5ms）。 |
| **(b) Herdr Mobile Relay PWA** | 浏览器打开的 HTTPS PWA，直连 relay 的 WebSocket | **实时可视化接管**：需要看智能体的实时画面、点按、滚动、复制粘贴时。桌面端点选、手机端翻页都走它。 |
| **(c) Telegram 桥** | 经 Telegram 收发的旁路聊天通道 | **被动审批**：在人不在设备旁时，用自然语言批准敏感操作、回放日志、查看进度。与工作站解耦，智能体 7×24 跑，你随时用最舒服的设备接管。 |

三条通道经 Tailscale 这一张扁平网络缝合：工作站与手柄看到的是同一个加密、直连、无公网暴露的虚拟局域网。

---

## 二、CRITICAL：PWA 必须跑在 HTTPS 上

Herdr Mobile Relay PWA **必须以 HTTPS（安全上下文）提供**。

- 用 `http://<LAN-IP>:PORT` 这种明文局域网地址打开 PWA，**永远无法完成配对**——在 relay 0.22.6 中，端到端加密（E2EE）依赖 `crypto.subtle`，而该 API 仅在安全上下文（HTTPS 或 localhost）下可用。`e2ee.ts` 在非安全上下文会直接抛错，配对流程因此中断。
- 正确做法：给 relay 前端套一层 HTTPS（反向代理 / 受信任证书 / `localhost` 调试），再用 `https://<relay-host>` 打开 PWA。

> 例外：在本机 `localhost` 调试时，`crypto.subtle` 可用，明文 `http://localhost` 可以配对；但任何跨设备访问都必须 HTTPS。

---

## 三、Relay 地址必须是 ws:// 或 wss://

在浏览器里填入的 Relay URL **必须以 `ws://` 或 `wss://` 开头**。

- 填成 `http://...` 或 `https://...` 会在浏览器侧直接抛出 `SyntaxError`（WebSocket 构造器拒绝非 ws(s) 协议）。
- 原则：页面本身用 HTTPS 托管（见上），但页面内部连接 relay 的 WebSocket 端点必须是 `wss://<relay-host>/...`；仅在本地调试可用 `ws://`。

---

## 四、Relay Key / Token 是必填项

对于**非回环（non-loopback）客户端**，Relay 的 key / token **必须提供**。

- 未携带有效 token 的跨网络客户端会被 relay 拒绝握手。
- 把它当作密钥对待：从环境变量或配置文件注入，**不要写进仓库**。本项目 `.gitignore` 已排除 `.env`、`*.key`、`*.pem`、`local/`，请勿绕过。
- 占位示例（仅文档用途，非真实值）：`relay token = <token>`，`relay url = wss://<relay-host>`。

---

## 五、`mouse_capture` 必须保持 true

桌面端点击场景下，**`mouse_capture` 必须保持 `true`**：

- `true` 时 relay 才能把鼠标事件正确捕获并转发给被控会话，桌面端点按、拖选、右键才生效。
- **手机端滚动不要用鼠标事件**——手机翻页走的是 Termux 扩展键里的 `PG▲` / `PG▼`（见 `configs/termux.properties` 的验证布局）。这两个键是单 token 宏，是唯一能真正滚动的形式；纯字符串 `"PGUP"`/`"PGDN"` 和 `{"key":"PGUP"}` 对象都不滚动。

> 一句话：桌面点击靠 `mouse_capture=true`，手机翻页靠 `PG▲`/`PG▼` 键，两者互补，不要互相替代。

---

## 六、验证清单（Verification Checklist）

部署或排障时，逐项核对：

- [ ] **PWA 托管**：访问地址是 `https://...`（或本机 `http://localhost`），**不是** `http://<LAN-IP>`。打开控制台确认 `crypto.subtle` 存在、无 E2EE 报错。
- [ ] **Relay URL**：填入的是 `ws://` 或 `wss://` 形式，无 `SyntaxError`。
- [ ] **Token**：non-loopback 客户端已填入有效 `<token>`，握手成功。
- [ ] **mouse_capture**：桌面接管场景下为 `true`，点按/拖选可用。
- [ ] **手机滚动**：`PG▲`/`PG▼` 能滚动（非 `PGUP`/`PGDN` 字符串、非 `{"key":...}` 对象）。
- [ ] **Tab 切换**：`◀`(F7)/`▶`(F8) 切换 herdr 的 `previous_tab`/`next_tab`；对应绑定已包含 `f7`/`f8`（及 `goto` 的 `f5`）。
- [ ] **键盘切换**：`⌨` 可正常显示/隐藏软键盘。
- [ ] **中文输入**：`enforce-char-based-input = false`，拼音/双拼组合输入正常。
- [ ] **宏语法**：所有宏为空格分隔（如 `"CTRL ALT z"`），无 `"+"` 连接；无 `[`/`]` 具名按键依赖。

---

## 七、常见踩坑速查

| 现象 | 根因 | 修复 |
| --- | --- | --- |
| PWA 配对永远转圈 | 明文 http://LAN-IP 下 `crypto.subtle` 不可用，E2EE 抛错 | 改为 HTTPS 托管 |
| 浏览器报 `SyntaxError` | Relay URL 写成 `http(s)://` | 改为 `ws(s)://` |
| 握手被拒 | 缺 relay token（non-loopback） | 填入有效 `<token>` |
| 桌面点不动 | `mouse_capture=false` | 置为 `true` |
| 手机不滚动 | 用了 `"PGUP"`/`{"key":"PGUP"}` | 改用单 token 宏 `"PGUP"`/`"PGDN"` |
| 宏把自己打出来 | `"+"` 连接或未知 token | 空格分隔、只用具名键/F-键 |

> 本文档不含任何真实 token、IP 或密钥，仅使用 `<relay-host>`、`<token>` 等占位符。
