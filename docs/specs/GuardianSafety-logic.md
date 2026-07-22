# Ohana Family App 内亲友守护规则书

> 状态：客户端、V96 本机投影 / outbox、年度 Family catalog 与 AWS SAM 服务端骨架已实现；运行开关默认关闭，尚未达到公开上线条件。
> 最近核对：2026-07-22。
> 所有者：`GuardianSafetyCoordinator`、Presence 命令、`OnlineFeatureGate`、StoreKit entitlement 与 `backend/guardian/`。

## 产品边界

亲友守护只使用已安装 Ohana 的守护人账号与普通 APNs 推送。不采集或使用电话号码、
邮箱，不发送短信或外部自动消息，也不宣称急救、死亡检测或保证送达。Free / Personal
继续免 Ohana 账号并保留本机提醒；只有用户主动启用 Ohana Family 在线守护时才要求
Sign in with Apple。

守护人是最小权限角色，只能看到与自己关系相关的当前事件、漏签守护日、确认状态、
暂停截止时间和推送可达性。守护人不能读取 Human 资料、打卡分数、Pet、Plant、健康、
体重、费用、任务、照片或完整家庭数据。

## 有效守护日

一个自然日只有同时满足以下条件才是有效守护日：

- 当前处于佛系模式，并绑定一位在世本人；
- Family 服务端权益有效且守护开关开启；
- 当天属于用户选择的星期；
- 守护没有处于计划暂停期；
- 至少一位已接受邀请且通知可用的守护人存在。

默认截止时间 20:00，默认宽限 60 分钟。星期、截止时间和 15–180 分钟宽限使用
Personal / Family 的高级提醒配置。计划按 IANA 时区和计划 revision 计算；DST 缺失时间
移到同一守护日下一个真实分钟，重叠时间使用第一次出现。更改时区或计划会增加
revision、关闭旧事件并从新的漏签序列开始。

未选择星期不增加也不打断连续漏签。暂停最长 30 天；期满恢复为新序列。退出佛系、
更换 / 解绑本人、本人进入纪念状态、关闭守护、撤销关系、Family 到期或删除账号都会
立即结束当前序列并阻止后续调度。

## 签到、漏签与事件

截止加宽限前，前台自动签到、本人卡片签到、一键全部或本机通知“我没事”动作都通过
同一 Presence 命令写事实。成功后清除连续漏签；普通后台刷新、静默推送或服务端任务
绝不能代替本人签到。

连续漏签状态机固定为：

1. 第 1 个连续漏签守护日只记录，不通知守护人；
2. 第 2 个连续漏签守护日创建事件，并最多提交一次首次 APNs；
3. 第 3 个连续漏签守护日最多提交一次跟进；
4. 同一事件此后保持安静，直到本人恢复、守护人确认或结构性停止。

守护人点“已联系到本人”只关闭事件并阻止跟进，不创建签到、不恢复连续、不发奖励。
首次提醒已经提交后，本人重新签到会向曾收到该事件提交尝试的守护人最多提交一次
“已恢复打卡”，随后关闭事件。

推送尝试状态必须区分 `submitted`、`opened`、`acknowledged` 和 `unreachable`。
SNS / APNs 接受请求只能显示“已提交”，不得显示“对方已收到”。锁屏文案使用最少
信息，例如“连续 2 个守护日未收到打卡，请主动联系确认”。

## 补签、撤回与离线

- 参与区间内的过去漏签日允许补记 1–10 分状态，但它不是签到：不修复连续、不发奖励、
  不触发全员完成，也不改写已发生或已关闭的守护事件。
- 当日签到可撤回；已发 reward receipt 与椰子不回收。截止前撤回后，当日仍可能按正常
  规则成为漏签，UI 必须先明确警告。已关闭事件不会因撤回重新发送。
- 本机离线签到照常事务保存并写可靠 outbox；界面显示“守护状态等待同步”。服务端只
  能表述“尚未收到打卡”，不得断言用户实际上没有签到。
- 恢复备份只恢复允许的本机事实，不重建守护关系、不上传旧联系人、不触发推送或奖励。

## 邀请与设备

Family 订阅者最多有 3 位已接受守护人；守护人无需购买 Family。邀请支持一次性 HTTPS
链接、二维码和 16 位邀请码，48 小时过期且只可接受一次。未安装用户先进入 App Store；
安装后必须在 App 内 Sign in with Apple 并明确接受，网页不能直接完成关系建立。

每次安装使用 Keychain `ThisDeviceOnly` 保存一个伪匿名设备 ID。APNs token 与设备 ID
按账号和安装分别幂等注册；退出登录只撤销当前安装端点，不影响同账号其他设备。token
失效会标记该设备不可达；所有守护人均不可达时，向本人持续显示警告，不降级为短信。

邀请链接必须通过真实 HTTPS Universal Link 主机。Associated Domains 未配置真实域名时，
Family 入口和购买必须保持关闭。

## 权益与账号

Family 年度商品为 `com.guanchen.li.Ohana.family.yearly`，目标 €39.99 / 年，无试用、无
Lifetime，并与 Personal 月 / 年订阅位于同一订阅组。组合能力固定为：

- `hasPersonal = Personal || Family`
- `hasFamily = Family`

客户端只接受 StoreKit 已验证 transaction，并把签名 transaction 临时提交服务端；
不把可篡改布尔值当在线权限。服务端使用 Apple App Store Server Library 验证 JWS，并
通过 App Store Server Notifications V2 处理续订、升级、降级、退款、撤销和到期。
Family 到期立即停止新调度；若还有独立 Personal / Lifetime 则回 Personal，否则回 Free。
本机打卡、历史、档案和椰子保持不变。

Family 商品即使存在本地 StoreKit 配置，也只有在完整运行配置有效时才加载和购买；默认
开关关闭时购买 fail-closed。普通 Free / Personal 启动和本地照护始终不依赖账号、AWS、
APNs 或 Family 权益服务。

## 数据与技术边界

V96 在 V95 后追加四种本机模型：

- `GuardianSafetyPolicyProjection`
- `GuardianRelationshipProjection`
- `GuardianIncidentProjection`
- `GuardianSafetySyncOutbox`

Presence 签到、撤回和结构性停止在原业务事务中写 outbox。发送使用幂等事件键、重试退避
和发送 lease；崩溃后过期的 `.sending` 可重放。服务端每次推送前重新检查签到、确认、
暂停、撤销、关系可达与签名权益，并用 DynamoDB 条件写防止并发重复提交。

AWS 区域固定 `eu-central-1`，基础设施使用 Cognito + Sign in with Apple、API Gateway、
Lambda、DynamoDB（PITR / TTL）、EventBridge Scheduler、SQS / DLQ 与 SNS APNS /
APNS_SANDBOX。服务端只保存匿名账号 ID、守护关系、时区与计划 revision、守护日结果、
事件状态、设备端点、最小通知尝试和权益投影；不上传姓名、打卡分数、健康、Pet、Plant、
费用、备注或其他家庭资料。

账号 token 与安装 ID 使用 Keychain `ThisDeviceOnly`。APNs token、账号 token、守护本机
投影和 outbox 不进入受限备份、用户导出或现有 CloudSync。当前备份格式仍为 v33，V96
不改变备份格式。

默认保留：邀请 48 小时、守护日信号 35 天、最小通知审计 90 天。撤销或账号删除立即
停止调度，关联服务端数据最迟 30 天内清除；为处理争议而保留的最小通知审计不超过
90 天。服务端日志不得包含 request body、JWS、回调 token、姓名、分数或家庭资料。

旧 `SafetyContact` 电话只留在本机，不上传、不静默删除，产品界面仅提供一次性清理入口；
旧短信编辑器和联系人编辑入口不再可达。

## 上线门禁

仓库实现不等于服务已上线。以下全部通过前，`OHANAGuardianSafetyEnabled` 必须为 false，
服务端 URL 保持空，Family SKU 不得公开销售或宣传：

- AWS `eu-central-1` 生产栈部署、告警、DLQ、留存清理和权限最小化通过；
- Cognito / Sign in with Apple、真实 HTTPS Universal Link 与 Associated Domains 配置通过；
- APNs production / sandbox token 注册、卸载失效、打开 / 确认 / 不可达状态通过；
- App Store Server Notifications V2、Sandbox 续订 / 降级 / 退款 / 撤销通过；
- App Store 隐私标签、公开隐私政策、DPA / 删除流程和审核备注与实现一致；
- 两个 Apple 测试账号、两台真机完成邀请、接受、第二日首次提醒、第三日唯一跟进、
  本人恢复、守护人确认、离线同步、暂停 / 恢复和账号删除旅程；
- 九语言、VoiceOver、Dynamic Type、RTL、深浅色通过；不申请 Critical Alerts。

Simulator 和本地 SAM 测试只能证明规则、编译和 fail-closed 边界，不能证明 APNs 到达、
系统权限、卸载 token 失效或两账号恢复。
