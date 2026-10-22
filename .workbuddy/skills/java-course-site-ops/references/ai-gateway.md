# 大模型网关参考

实现：`backend/src/main/java/com/javacourse/service/ModelGateway.java`
业务封装：`backend/src/main/java/com/javacourse/service/AiAssistantService.java`
配置：`backend/src/main/resources/application.yml` 的 `app.ai` 段
诊断接口：`GET /api/ai/health`

## 降级链

```
openai (OpenAI 兼容 /v1/chat/completions)
   ↓ 失败 / 超时 / 空响应
ollama (本地 Ollama 自带的 /v1 兼容端点)
   ↓ 失败
local  (后端内：课程内容检索式回答)
   ↓ 网络异常
offlineReply() (前端：正则分流的本地预设回复)
```

`provider` 可选值：

| 值 | 行为 |
|---|---|
| `auto`（默认） | 按 `fallback-order` 依次尝试，`local` 永远留作最后兜底 |
| `openai` | 只用 OpenAI 兼容端点，失败直接落 local |
| `ollama` | 只用本地 Ollama |
| `local` | 完全不调远程模型，零延迟零成本 |

`resolveOrder()` 在 `auto` 模式下会**跳过没有配置 API Key 的 openai 档**，避免无谓的网络往返。

## 配置项

全部走环境变量，不入库、不进版本库。

| 变量 | 默认值 | 说明 |
|---|---|---|
| `AI_PROVIDER` | `auto` | 见上表 |
| `AI_BASE_URL` | `https://api.deepseek.com` | OpenAI 兼容根地址，**不含** `/v1/chat/completions` |
| `AI_API_KEY` | 空 | `Authorization: Bearer <key>` |
| `AI_MODEL` | `deepseek-v3` | 模型名 |
| `AI_FALLBACK_ORDER` | `openai,ollama,local` | auto 模式尝试顺序 |
| `AI_OLLAMA_BASE_URL` | `http://127.0.0.1:11434` | Ollama 自带兼容端点 |
| `AI_OLLAMA_MODEL` | `qwen2.5:7b` | 本地模型名 |
| `AI_TIMEOUT_MS` | `20000` | 单次调用硬超时，超时即降级下一档 |
| `app.ai.context-limit` | `6` | 检索喂给模型的课程内容条数 |

## 厂商 base-url 示例

| 厂商 | base-url | 模型示例 |
|---|---|---|
| DeepSeek | `https://api.deepseek.com` | `deepseek-v3` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode` | `qwen-plus` |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas` | `glm-4-plus` |
| 豆包 | `https://ark.cn-beijing.volces.com/api/v3` | 端点 ID |
| 硅基流动 | `https://api.siliconflow.cn` | `deepseek-ai/DeepSeek-V3` |
| 本地 Ollama | `http://127.0.0.1:11434` | `qwen2.5:7b` |

请求体统一：
```json
{"model":"...","messages":[{"role":"system","content":"人设"},{"role":"user","content":"课程资料+问题"}],"temperature":0.6,"max_tokens":1500}
```
响应解析兼容 `choices[0].message.content` 为**字符串**或**数组**（取 `text` 块）两种形态。

## 鉴权与请求流程

1. 前端 `POST /api/ask` 携带登录会话令牌（`Authorization` 头）。
2. 后端 `AiAssistantService` 组装 prompt：课程检索结果（最多 `context-limit` 条）+ 用户问题。system 段是鲸鲸助教人设（`PERSONA`），**不要**在人设里重复拼接，避免双份。
3. `ModelGateway` 按顺序调用各通道，每次调用带 `timeoutMs` 硬超时。
4. 成功即返回 `Result(answer, provider, degraded=false, detail, latencyMs)`。
5. 全部失败则 `Result(localAnswer(...), "local", degraded=true, 失败原因汇总, latencyMs)`。
6. 响应体额外带 `provider` 与 `degraded` 两个字段，前端据此显示通道徽标（本地/云端/离线）。

`ai_chat_message` 表记录 `latency_ms` 与 `citations`（引用列表 JSON），便于后续统计各通道质量。

## 延迟与成本（实测）

| 场景 | provider | degraded | 延迟 |
|---|---|---|---|
| 无 Key、无 Ollama | `local` | true | 41–48 ms |
| 指向本地 mock OpenAI 服务 | `openai` | false | 458 ms |
| 端点不可达 | 自动降级 `local` | true | < 800 ms |
| 云端真实模型 | 取决于厂商 | false | 通常 1.5–4 s |

成本约束：
- `local` 档零成本零网络，是唯一完全免费的档位。
- 云端按 token 计费，`max_tokens: 1500` + `context-limit: 6` 把单次调用的上下文控制在可接受范围；课程检索结果越少越省钱。
- `temperature 0.6`、单轮问答，无多步工具调用，避免放大成本。
- `timeoutMs` 过大时，故障期间会持续挂起请求；20 s 是延迟与可用性的折中。

## 调试手法

```bash
# 起一个假 OpenAI 兼容服务，会打印 auth 头与原始 body
python scripts/mock_openai.py            # 监听 19998
export AI_BASE_URL=http://127.0.0.1:19998
export AI_API_KEY=test-key
export AI_PROVIDER=openai
```

```bash
# 看当前生效通道
curl http://localhost:8080/api/ai/health
```

`aiHealth()` 返回 `provider` / `baseUrl` / `model` / `fallbackOrder` / `ollamaBaseUrl` / `ollamaModel` / `openaiConfigured` / `effective` / `degraded` / `note`。
