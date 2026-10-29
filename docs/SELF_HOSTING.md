# Dokploy 私有部署

这个镜像只提供静态页面：构建阶段使用 Node.js 22，运行阶段只有非 root Nginx，监听 **8080**。不运行 Vite 开发服务器、Node.js API、网页截图代理或数据库。

## Dokploy Application 配置

1. 创建 Application，连接 `NeroSong/iPhoneDuoMock`，选择包含部署文件的分支。
2. Build Type 选择 **Dockerfile**。
3. Dockerfile 路径填写 `Dockerfile`，Build Context 为仓库根目录（`/`）；不需要自定义运行命令、环境变量或卷。
4. Domain 的容器端口填写 **8080**，路径为 `/`，启用 HTTPS。中文版入口为 `https://你的域名/zh/`。
5. Save 后 Deploy。不要额外映射主机端口，流量通过 Dokploy 的反向代理进入容器。
6. 该工具没有内置登录。供指定设计师使用时，先通过 Tailscale/私网访问，或在域名入口配置身份验证（例如 Cloudflare Access），再分享链接。`robots.txt` 和 `noindex` 仅用于减少索引，不能代替访问控制。

普通 Application 部署依靠 Dockerfile 中的非 root 用户运行。如果面板提供自定义容器参数，建议进一步设置：只读根文件系统、`/tmp` 的 64 MiB tmpfs（`noexec,nosuid,nodev`）、删除全部 Linux capabilities、`no-new-privileges`。不要给它 privileged、Docker socket 或主机目录挂载。

初始可设置 256 MiB 内存上限、0.5 CPU，并按实际使用调整。渲染和编码发生在设计师浏览器里，服务器主要分发静态资源。

## 统计与数据边界

- 已移除 README 的 OctoCounts 计数徽章。原站页面中的 Cloudflare Analytics 是托管平台注入的，不在源代码中；这个 Docker 镜像不会注入它。自行部署时也不要开启入口代理的统计脚本注入。
- 容器构建会检查产物中已知的统计服务标记；发现后停止构建。CSP 只允许同源脚本、连接及本地图片，不允许加载外部统计脚本。这不是完整的恶意代码扫描。
- Nginx 关闭访问日志，仍保留必要的错误日志。Dokploy、入口代理或 CDN 自身仍可能记录访问，请按自己的隐私要求配置。
- 图片读取、自动保存及导出都发生在浏览器。自动保存使用 IndexedDB，关闭页面后仍会保留；共享电脑上用完应清除站点数据。下载的 `.duo.json` 可能包含原始设计图。
- 浏览器模式会直接访问填写的网站，HTTPS 外站可以嵌入；HTTP 外站在此部署中被 CSP 阻止。外站有自己的请求及隐私行为。
- 仅上传图片和导出效果图不需要屏幕共享。实时网页导出才需要授权捕获当前工具标签页，不要选择其他标签页或整个桌面。
- 静态镜像不提供“生成网页截图”后端，也不会接收上传请求。

## 镜像与安全响应头

运行用户为 `101:101`，只允许 GET/HEAD。所有 PID 与临时文件写入 `/tmp`，支持只读根文件系统。构建上下文使用白名单，排除 Git 历史、环境文件、参考素材及本地依赖；最终镜像只复制构建产物及 Nginx 配置，不带源码和 npm 工具链。

CSP 从构建生成的 `dist/_headers` 转换为 Nginx 配置，保留多语言 JSON-LD 的哈希，并补充表单提交限制。安全头也用于错误响应；禁止目录列表，隐藏点文件及托管平台指令文件。HTML 不缓存，带哈希的 `/assets/` 成功响应可以长期缓存。

TLS 在 Dokploy/入口代理终止。HSTS 应在确认域名始终通过 HTTPS 后由入口统一设置。本镜像不会信任客户端传来的 `X-Forwarded-Proto` 来决定安全策略。

基础镜像使用 Node 22 Alpine 和官方维护的非 root Nginx `stable-alpine` 系列标签；构建时应拉取最新基础镜像，定期重建以获得修复。依赖版本由 `package-lock.json` 固定。这个配置减少暴露面，但不保证依赖或宿主机永远没有漏洞。

## 部署后检查

本次按要求未在本机执行构建、测试或启动容器。上线后由部署方检查：

```sh
curl -I https://你的域名/zh/
curl -i https://你的域名/healthz
curl -i -X POST https://你的域名/healthz
```

分别预期：中文页面返回 200 且有 CSP、`nosniff`、`no-referrer` 等响应头；健康检查返回 `ok`；POST 返回 405。若入口配置了身份验证，先通过认证再检查，不要为探测而绕过认证。

在浏览器验证拖入图片、切换姿态、刷新恢复项目、PNG 导出；网络面板应只有同源静态资源读取，截图模式没有上传请求。网页模式需要另行核对目标站点请求；不要据此宣称整个页面永远不会连接外站。
