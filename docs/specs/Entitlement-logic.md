# Entitlement Logic

> 状态：Free / Personal 与 fail-closed Family 年度 catalog、StoreKit 测试配置和统一权益服务已在工作树实现；Family 商品默认不加载、不展示、不可购买，直到在线守护上线门禁完成。这不等于 App Store Connect、Sandbox、服务端或真机已验收。
> 最近核对：2026-07-22，依据 `product-foundation.md` D4、D6、D9、D22、D25、D29–D32 与 G12。
> 所有者：统一 Entitlement 服务与领域额度策略；任何 View、主题、图标或分享卡不得自行读取产品 ID、交易或本地布尔值决定所有权。

## Purpose

基础商业结构为 Ohana Free + Ohana Personal；Ohana Family 是独立年度订阅并包含
Personal，只用于需要持续服务的 App 内亲友守护。权益系统分别回答 `hasPersonal` 与
`hasFamily`，各功能只询问语义能力。

StoreKit 不可用、网络中断、商品加载失败、购买失败或交易无法验证时，Free 基础能力必须 fail-open。任何付费状态都不能锁定原始记录、已有历史查看编辑、手动导出、健康关键提醒、纪念模式或离世档案。Ohana 不植入广告，Personal 不售卖“去广告”。

## 1.0 Product Catalog

| 商品 | StoreKit 类型 | Product ID | 目标配置 |
| --- | --- | --- | --- |
| Personal Monthly | Auto-Renewable Subscription | `com.guanchen.li.Ohana.personal.monthly` | €2.99 / 月；不默认承诺试用 |
| Personal Yearly | Auto-Renewable Subscription | `com.guanchen.li.Ohana.personal.yearly` | €14.99 / 年；符合条件的新订阅者 14 天试用；主推 |
| Personal Lifetime | Non-Consumable | `com.guanchen.li.Ohana.personal.lifetime` | €49.99 一次购买 |
| Legacy Supporter Pack | Non-Consumable | `com.guanchen.li.Ohana.supporterPack` | 不再作为新用户主要商品；已验证有效的历史购买授予 Personal Lifetime |
| Family Yearly | Auto-Renewable Subscription | `com.guanchen.li.Ohana.family.yearly` | €39.99 / 年；无试用、无 Lifetime；上线门禁完成前隐藏且不可购买 |

Personal Monthly、Personal Yearly 与 Family Yearly 必须位于同一订阅组，以便 Apple
管理升级和降级；Family 同时授予 Personal。Lifetime 是本地 Personal 能力的永久权益，
不包含 Family 在线守护、Care+ 云端 AI 或其他持续服务。所有商品的 App Store Family
Sharing 保持关闭。

App 内价格、币种、税费、周期和 introductory offer 只使用 StoreKit 本地化结果。上表欧元值只是 App Store Connect 配置目标，不得硬编码。首发 Founding Lifetime €39.99 只可作为真实 Storefront offer 实验，不新建第四个 SKU；StoreKit 未返回该优惠时不得展示。

四个新 Product ID、legacy Product ID、订阅组和价格语义必须在集中 catalog、本地
StoreKit 配置、测试、App Store Connect 与本文中保持一致。Family 本地配置仅用于测试，
不能绕过运行开关。不得静默改名、复用 legacy SKU 卖新权益或用本地布尔值伪造购买。

## Single Decision Point

实现必须提供一个统一、可观察、可注入测试替身的 Entitlement 服务。调用者只询问
语义能力，例如 `hasPersonalAccess`、`allows(.unlimitedActiveProfiles)` 或 `allows(.supporterBackgrounds)`；不得：

- 在 View、主题、图标、周报或 Settings 中直接调用 `Product.products`；
- 根据 Product ID 字符串、价格、Storefront、购买按钮状态或 UserDefaults 自行推断
  所有权；
- 把 `ShopPurchaseRecord`、椰子余额、备份内容或当前选中装饰当作 StoreKit 收据；
- 在照护 command、SwiftData 模型写入、提醒调度或应用启动成功条件中等待 StoreKit。
- 在 View 中自行查询全库并计数，或先写入超额事实后再用付费墙补救。

权益事实来自 Apple 签名且通过验证的 StoreKit transaction。可缓存派生快照改善
离线体验，但缓存不是新所有权来源，也不能覆盖更新的已验证 StoreKit 事实。

## Free Quotas And Grandfathering

| 领域 | Free 上限 | 计数语义 |
| --- | --- | --- |
| Pet | 1 个活跃宠物 | 未离世的 Pet 计数；纪念档案不计数 |
| Human | 2 个活跃 Human | 未离世的 Human 计数；纪念档案不计数 |
| Plant | 5 株活跃植物 | 未归档的 Plant 计数 |
| 普通提醒 / 计划 | 3 个普通活跃逻辑计划 | Event 与它派生的 Reminder 只计一个；健康关键计划、系统旅程事项、已完成、已取消和已失效项不计数 |

Personal 在上述四个领域全部不限。额度检查必须由领域服务 / command 在持久化前完成，使用有界计数或 read model，返回可测试的语义结果；View 只发出意图并根据拒绝结果展示克制的 Personal 介绍。

成员创建入口应在构建资料表单前调用同一领域服务做只读 preflight。Free 已达到
对应活跃上限时，应立即展示仅含一句额度说明、真实方案、购买 / 恢复动作和必要
条款的精简 Personal 页面；不得让用户填完资料后才得知额度。写入边界仍须再次
校验，防止 preflight 后权益或活跃数量变化。

无论是旧版更新、Personal 降级、备份恢复还是数据迁移，已存在的超额数据全部 grandfather：

- 可继续查看、编辑、记录照护、手动导出、备份恢复和迁移；
- 不得自动删除、隐藏、离世、归档、取消或停用任何对象 / 计划；
- 只阻止“新建或重新激活后使超额程度继续增加”的操作；不增加活跃计数的普通编辑继续允许；
- 健康关键提醒 / 计划永远不因额度拒绝；
- 当活跃数量自然回到 Free 上限以下时，才恢复对应领域的新增 / 重新激活。

## Personal Capability Mapping

Personal 解锁以下语义能力；只有已实现、已验收的条目才能显示在付费页或 App Store 元数据中：

- 不限活跃宠物、Human、植物和普通活跃提醒 / 计划；
- 高级用药计划与依从性工具；
- 90 天、1 年、全部时间趋势与本地交叉比较；
- 高级周报、月报、年度回顾、兽医 PDF、健康护照和 CSV；
- 全历史搜索、高级筛选、自定义照护动作、批量记录、文档扫描和附件；
- 已实现的隐私精简、只读“今日照护”Widget；Shortcuts 与快捷记录只有实现并验收后才可加入付费宣传；
- 多版本自动 iCloud Drive 备份与恢复点；
- Founding 徽章、3 个 Supporter 背景、`AppIconNeonSmile` 立即使用权和 Founding 周报海报。

原始记录、已有历史、手动导出、健康关键提醒、纪念、椰子、基础 Oasis 与 Free 最新一份自动备份不读 Personal entitlement。

佛系基础模式、卡片打卡、固定状态、一键全部、全部原始月份、当前/最长连续、基础
Oasis、商店、扭蛋和电子宠物也不读 Personal entitlement。Personal 只增加佛系的
90 天/1 年/全部时间趋势、状态分布、完成率、跨对象比较、导出、按星期提醒、
15–180 分钟宽限和第二次本机提醒。Free 保留一个每日本机提醒时间。Free / Personal
都不发送跨设备亲友通知；任何套餐都不增加佛系奖励、椰子倍率或扭蛋概率。

Family 使用组合能力：Family 同时满足 `hasPersonal` 与 `hasFamily`。`hasFamily` 只开放
已部署、已验收的在线守护；不自动开放 CloudKit 同步或其他未来协作。客户端完整运行
配置缺失或开关关闭时，不请求 Family 商品、隐藏购买入口，直接购买调用也 fail-closed。

### Household Insights

家庭洞察固定包含“体重、花费、周报、照护分析、提醒健康、长期回顾”六个始终可见的
Tab。Free 按椰子树等级依次开放：体重与花费 Lv.1、周报 Lv.6、照护分析与完整提醒
诊断 Lv.8、长期回顾 Lv.9；未解锁项显示所需等级，不隐藏原始记录。健康与用药的家庭
聚合面板仍由椰子树 Lv.2 独立解锁，不属于 Personal 提前开放范围。

Personal 以及满足 `hasPersonal` 的 Family 可从 Lv.0 提前访问全部家庭洞察，并在
体重、花费和分析中使用 90 天、1 年、全部时间、跨对象比较及导出。Free 保留全部原始
记录、7 天与 30 天趋势和单对象查看。Personal 只绕过这六个家庭洞察 Tab 的等级门，
不得提前开放 Lv.4 植物、Lv.5 Oasis 成长、Lv.6 商店、Lv.7 扭蛋、Lv.10 电子宠物，
也不改变椰子收入、成长速度或抽取概率。

提醒权限异常、发送失败和逾期属于安全摘要，任何家庭洞察等级与套餐门都不得隐藏；
详细调度流水和趋势仍按 Lv.8 或 Personal 裁决。权益降级后只锁定高级范围、比较和新
导出，原始记录以及已由当前椰子树等级开放的能力继续可用。

## State Model

商品展示状态与已购权益状态必须分开：已购用户即使暂时加载不到商品 / 价格，也要继续使用已验证 Personal；未购用户加载不到商品时不能显示假价格或不可完成的购买按钮。

### Product presentation

| 状态 | UI 行为 |
| --- | --- |
| `idle/loading` | 保持页面可用，价格位显示克制 loading，不阻塞其他设置 |
| `available([Product])` | 按商品分别显示 StoreKit 本地化名称、说明、周期、试用资格 / offer 和 `displayPrice` |
| `unavailable(error)` | 显示“暂时无法连接 App Store”与重试；不猜价格 |

### Entitlement

| 状态 | 含义与门控 |
| --- | --- |
| `checking` | 正在枚举本机 StoreKit 权益；Free 基础能力全开，Personal 按最近一次已验证快照裁决 |
| `personalSubscriptionVerified` | Monthly 或 Yearly 存在当前有效、未退款 / 撤销的已验证 entitlement；开放 Personal |
| `personalLifetimeVerified` | Personal Lifetime 或 legacy Supporter Pack 存在未退款 / 撤销的已验证 entitlement；永久开放 Personal |
| `familySubscriptionVerified` | Family Yearly 存在当前有效、未退款 / 撤销的已验证 entitlement；同时开放 Personal，并允许客户端向服务端验证 Family 在线权限 |
| `freeVerified` | 已成功枚举且不存在任何有效 Personal 来源；使用 Free 额度 |
| `temporarilyUnknown` | 枚举失败或 StoreKit 暂不可用；Free 基础能力全开，最近一次 Personal 已验证拥有者可继续 Personal，从未验证者不误解锁 |

`.unverified` transaction 永远不能授予权益、写入“已购买”布尔值或伪装为成功。
它只产生非敏感诊断和可恢复错误提示。

## Launch And Refresh

应用启动时必须让 StoreKit 工作与本地照护启动并行，不得让交易请求延迟主界面：

1. 先启动一个应用生命周期所有的 `Transaction.updates` 监听任务；同一进程只允许
   一个权威监听者，退出时取消。
2. 使用集中 catalog 加载三个 Personal Product ID；只有 Family 运行配置有效时才附加
   Family Yearly。legacy Supporter ID 仅参与权益恢复，不出现在新购页。
3. 枚举 `Transaction.currentEntitlements`，只消费 `.verified` transaction，并检查
   Product ID、product type、`revocationDate`、订阅过期时间和有效所有权状态。任一
   Personal 来源均授予 Personal；有效 Family 同时授予 Personal 与 Family。
4. 发布不可变权益快照；View 只观察快照，不持有 StoreKit transaction。

以下时机重新枚举 `currentEntitlements`：

- 冷启动和应用回到前台；
- 已验证购买结果到达后；
- `Transaction.updates` 收到已验证更新后；
- 用户主动恢复购买后；
- Storefront 或 StoreKit account 环境变化后。

监听者收到已验证 transaction 后先刷新并发布权益，再调用 `finish()`；不得 finish
后却不交付内容。重复更新和重复枚举必须幂等，不能重复生成本地购买记录、徽章或
其他副作用。

## Purchase Flow

购买只能由用户明确点击触发：

1. 确认用户选择的 Personal Monthly / Yearly / Lifetime 或 Family Yearly 已由 StoreKit
   成功加载；按钮显示对应 `displayPrice` 和真实周期。只有 Personal Yearly 且 StoreKit
   返回符合条件的 introductory offer 时才显示 14 天试用；Family 不显示试用。
2. 防止连点并调用 `Product.purchase()`；不在购买前写任何所有权状态。
3. 根据结果处理：
   - `.success(.verified(transaction))`：核对 Product ID 与类型，刷新
     `currentEntitlements`，开放 Personal，随后 `finish()`；
   - `.success(.unverified)`：不开放 Personal，说明购买暂时无法验证并提供稍后重试 / 恢复；
   - `.pending`：说明购买等待家长批准或 App Store 处理，不当作成功或失败；由
     `Transaction.updates` 完成交付；
   - `.userCancelled`：安静恢复按钮，不展示错误或继续追弹；
   - 其他错误：保留 Free 全部基础能力，提供可重试错误，不重复扣款猜测。
4. 成功页只列出当前 build 已交付的能力，明确 Lifetime 不包含 Family / Care+ 持续服务，
   Family 不包含尚未上线的 CloudKit 协作，不暗示去广告或未来全部内容。

Family 购买成功不等于服务端立即授权。客户端只暂存内存中的签名 transaction，登录后
提交服务端以 Apple App Store Server Library 再验证；服务端 entitlement 生效后才能
开启守护。客户端布尔值、备份或本地商品加载结果都不能授权在线调度。

用户已有月 / 年订阅时购买 Lifetime，App 只能引导其在系统订阅管理中确认后续订状态；App 无权自行取消订阅，也不得说成“购买 Lifetime 后自动退订”。Monthly / Yearly 之间的切换和生效时间由同一 StoreKit 订阅组管理。

购买 UI 不得出现在首次启动强制流程、健康关键提醒、纪念模式、导出失败或用户担心
数据丢失的时刻。

## Restore Purchases

设置和 Personal 页面必须始终提供清晰的“恢复购买”：

1. 由用户点击后调用 `AppStore.sync()`；不得每次启动强制弹出账号验证。
2. sync 返回后重新枚举 `Transaction.currentEntitlements`，而不是相信 sync 成功就
   直接解锁。
3. 找到任一已验证有效 Personal Monthly / Yearly / Lifetime 或 legacy Supporter transaction 时恢复 Personal，并清楚确认成功。
4. 没找到有效 transaction 时说明当前 Apple 账号没有可恢复购买；不得抹掉本机
   数据或现有椰子商店所有权。
5. 网络、账号或 StoreKit 错误必须允许稍后重试；恢复失败不改变最后一次已验证拥有
   状态。

自动权益刷新与用户主动 Restore 是不同动作：正常换机应可从
`currentEntitlements` 自动恢复，按钮为账号或缓存异常提供显式同步路径。

## Refund, Revocation, And Offline Rules

### Refund or revocation

- Monthly / Yearly 过期、订阅终止、Lifetime / legacy 购买退款或撤销，且 `currentEntitlements` 不再给出任何其他有效 Personal 来源时，回到 Free。
- StoreKit 明确仍处于有效宽限期 / 账单重试权益时，按 Apple 当前权益继续 Personal；不根据自制日期提前取消。
- 降级后不得删除、隐藏、归档或停用既有超额档案 / 计划；只按 Free 额度阻止新增或重新激活导致继续超额。
- 已生成的高级报告、PDF、海报、导出和备份文件不删除；只停止新建 Personal 产物和继续使用 Personal 工具。
- Founding 徽章、Supporter 背景和海报样式停止展示；当前选中的 Personal 背景 / 海报温和回退免费默认样式，但保留选择偏好，未来重新拥有时可以恢复。
- 若 `AppIconNeonSmile` 正在使用，先检查用户是否也通过椰子商店拥有它；椰子来源
  仍有效时保持图标。只有两个来源都无效时，才在下一个用户可见、可解释的权益协调
  点回退到免费默认图标，不得从后台突然触发系统换图标提示。
- 不删除周报、分享结果、家庭数据、照片、历史、备份或任何用户内容。
- 不撤销、迁移或重写椰子商店所有权。

### Offline

- Free 基础能力在完全离线时仍完整可用。
- `currentEntitlements` 的本机已验证 transaction 历史是优先来源。
- 如果 StoreKit 枚举暂时失败，最近一次 `personalSubscriptionVerified` 或 `personalLifetimeVerified` 可以继续开放 Personal，直到下一
  次成功验证；这是低风险本地权益的信任优先策略，不得借此授予从未验证过的新所有权。
- 最近一次 `freeVerified` 或全新安装在离线时保持 Free；不得从备份、
  选中主题、椰子购买或可篡改布尔值推导购买。
- 离线时购买按钮应说明需要连接 App Store，不能排队自制交易。
- 离线期间发生的退款 / 撤销会在下一次成功 StoreKit 更新后生效；在此之前不得为
  强制联网而阻止 app 使用。

## Legacy Supporter And Cosmetic Grandfathering

已验证有效的 legacy `com.guanchen.li.Ohana.supporterPack` transaction 必须授予与 Personal Lifetime 完全相同的语义能力，而不是只恢复旧装饰。新购买页不展示 legacy Pack，但权益枚举、换机和 Restore 必须永久包含该 ID。不得用当前安装时间或本地版本号替代 Apple transaction 作为 grandfather 事实。

Personal 装饰必须使用独立、稳定的语义 ID，并与现有椰子经济命名空间分开：

- 3 个 Supporter 背景检查 Personal entitlement；免费背景保持可用。
- `AppIconNeonSmile` 是一个明确批准的双来源例外：Personal 提供立即使用权，
  原有椰子商店购买 / 已拥有事实也独立提供使用权；裁决为两者任一有效即可使用。
- 周报免费内容、计算和基础导出不读 entitlement；只有附加海报样式读。
- Founding 徽章不写入椰子账本、不授予奖励，也不影响等级或排序。

现有 `ShopPurchaseRecord`、legacy `purchasedShopItems`、恢复出的商店记录和已经用椰子
购买的主题 / 图标全部 grandfather：

- StoreKit transaction 不转换成 `ShopPurchaseRecord`；
- `ShopPurchaseRecord` 也不能冒充 Personal / legacy Supporter transaction；
- `AppIconNeonSmile` 的最终使用权由“Personal 已验证拥有”或“椰子商店已拥有”两个独立事实做 OR 裁决；不得为 Personal 补写虚假椰子购买记录；
- 更新、恢复备份、退款、撤销或 Product ID 变更不得让椰子商品重新收费或消失。

应用备份可以保存用户选中的装饰 ID 以恢复偏好，但不得把 Personal 所有权写进
备份并据此解锁。换机 / 恢复后必须重新从 StoreKit 得到权益。

## UX, Localization, Accessibility

- 首次打开和 Onboarding 不强弹 Paywall。
- 页面同时说明 Free 额度、Monthly / Yearly / Lifetime 的真实周期与价格，并准确区分订阅和一次购买。不得使用虚假倒计时、默认预选、隐藏其他购买方式或数据焦虑文案。
- 额度触发页不重复展示通用 Hero、完整 Free / Personal 对比、外观权益或其他与
  当前动作无关的说明；设置中用户主动打开的完整方案页可保留详细比较。
- 付费墙只在用户自然超出额度或主动使用 Personal 功能时出现；不得出现在健康紧急、备份失败、手动导出、纪念或已有数据查看编辑路径。
- 购买、恢复、pending、验证失败、已拥有、退款 / 撤销后的状态均有明确文本，不能
  只靠颜色或动画表达。
- 套餐比较、购买按钮、Restore、主题 / 图标 / 海报选择支持 Dynamic Type、VoiceOver、Voice
  Control、Switch Control、Reduce Motion、深色模式和 RTL。
- App 内文案与 App Store IAP 元数据覆盖当前注册的九种语言：中文、英文、德语、
  西班牙语、葡萄牙语、法语、日语、韩语和意大利语。
- App 内价格、货币和税费表达只使用 StoreKit 本地化结果。

## Privacy And Security

- Apple 处理付款、账单和 Apple 账号；Ohana 不读取、保存或传输银行卡、账单地址、
  Apple ID 密码或完整支付凭据。
- App 只读取 StoreKit 提供的商品元数据，以及 Apple 签名并验证的 transaction 和当前权益状态，用于本机交付 Personal。
- Free / Personal 没有 Ohana account。Family 守护登录只建立匿名账号映射，并将经
  Apple 签名的 Family transaction 交给服务端验证；不得把购买关联到 Human、Pet、
  Plant、健康、打卡分数或其他照护记录。
- 不为 Personal 引入广告 SDK、追踪、第三方分析或开发者托管购买后端。
- 未验证 transaction、错误日志和测试诊断不得包含收据正文、Apple 账号信息或照护
  数据。
- 购买状态不是照护数据；不得上传到 CloudKit、写入用户导出包或通过分享卡外泄。
  Family 服务端只保存验证在线权益所需的最小交易标识、产品、到期和状态，不保存 JWS
  正文或支付凭据。

## App Store Release Gate

以下步骤不能仅通过仓库完成，全部是 1.0 提交前的外部发布门：

- 在 App Store Connect 接受 Paid Apps Agreement，并完成有效的税务和银行资料；
- 创建同一订阅组下的 Personal Monthly / Yearly auto-renewable subscriptions 与 Personal Lifetime non-consumable，Product ID 与集中 catalog / 本文一致，Family Sharing 保持关闭；
- 为 Yearly 配置并审核符合条件新订阅者的 14 天 introductory offer；App 必须以 StoreKit 资格与元数据为准；
- 配置目标价格、地区可售范围和地区价格实验；目标为 €2.99 / 月、€14.99 / 年和 €49.99 Lifetime，实际档位由 App Store Connect 决定；
- 若测试 Founding Lifetime €39.99，只使用符合 StoreKit 与 App Store Connect 能力的真实 offer，不创建第四个 SKU，不硬编码折扣或虚假划线价；
- 保留 legacy Supporter Pack 对已购用户的 `currentEntitlements` 与 Restore 可达性；停止新售不得破坏历史恢复；
- 为当前九种语言配置商品名称和说明，并准备 IAP 审核截图、Review Notes、购买入口
  与恢复购买入口说明；
- 将三个 Personal 商品与包含其实现的 1.0 新版本一同提交审核，付费页和 App Store 元数据只能声明当前 build 已交付的 Personal 能力；
- 在 Sandbox / StoreKit 测试覆盖月付、年付试用 / 付费转化、Lifetime、legacy grandfather、取消、pending、失败、未验证、重复点击、离线 / 重启；
- 使用第二台设备和同一 Apple 测试账号验证自动恢复与主动 Restore；
- 使用 App Store / Sandbox 支持路径验证订阅过期、试用结束、退款或交易撤销后 Free 降级、超额 grandfather、数据不变和椰子所有权不变；
- 在最终签名包核对商品可加载、Storefront 价格、本地化、App Store 隐私答案和审核
  元数据一致。

任何一项缺失都不能把 Personal 标为 release-ready，也不能仅以本地
`.storekit` 配置测试代替真实 Sandbox、第二设备或退款 / 撤销证据。

## Repository Validation Matrix

| 场景 | 必须证明 |
| --- | --- |
| 商品加载成功 / 失败 / 重试 | 只显示 StoreKit 价格、周期、试用 / offer；失败不阻塞 Free |
| 首次购买成功 | 月、年、Lifetime 都只接受 verified transaction；授予统一 Personal；transaction finish |
| 取消 / pending / 错误 / unverified | 不误解锁、不重复购买、不把正常取消显示成失败 |
| `Transaction.updates` | 监听唯一、幂等、跨前后台交付且无生命周期泄漏 |
| `currentEntitlements` | 启动、前台、购买、更新、恢复后均重算；退款 / 撤销被排除 |
| Restore | `AppStore.sync()` 后重新验证三个 Personal ID 和 legacy Supporter ID；无购买与错误文案真实 |
| Free 额度 | 1 Pet / 2 Human / 5 Plant / 3 普通活跃逻辑计划；健康关键不计数；Event + 派生 Reminder 不重复计数 |
| 超额 grandfather | 旧版、降级、恢复和迁移均不删 / 不隐藏 / 不停用；非增额编辑、照护记录、导出继续可用；只阻断继续增额 |
| 离线 / 重启 | Free 基础能力全开；已验证拥有者保留 Personal；从未验证者不误解锁 |
| 换机 / 备份恢复 | 所有权来自 StoreKit，不来自备份；legacy Supporter 恢复为 Personal Lifetime |
| 试用结束 / 订阅过期 / 退款 / 撤销 | 降级保护成立；所有家庭数据和 Free 能力保持，椰子商品不变 |
| Personal 能力映射 | 不限额度和每一个已对外声明的高级本地能力都有定向测试；Supporter 装饰与椰子独立所有权正确 |
| Family 默认关闭 | 运行配置缺失时不加载商品、不展示入口、直接购买 fail-closed；不影响 Personal 恢复或普通照护 |
| Family entitlement | 有效 Family 同时授予 Personal；服务端 JWS / ASSN V2 再验证后才允许调度；到期 / 降级立即停止新守护且本机数据不变 |
| UI / 本地化 / 无障碍 | 九语言、动态价格、Dynamic Type、语义控件和辅助技术路径通过 |

定向 StoreKit 测试编译受影响 target 后可替代单独 build；最终仍需上述 App Store
外部证据和签名包验收。

## Family Release Gate And Future Care+

Family Yearly 已进入集中 catalog 和本地 StoreKit 测试配置，但运行开关默认关闭。以下
完成前不得在 App Store Connect 开放销售、在 App 内加载商品或宣传守护可用：

- AWS 生产栈、Sign in with Apple、Associated Domains、APNs 与 App Store Server
  Notifications V2；
- Family 续订、升级、降级、宽限 / 账单重试、退款、撤销与 entitlement loss；
- 隐私标签 / 政策、九语言、Sandbox、第二账号和双真机端到端证据。

详细门禁见 [`GuardianSafety-logic.md`](GuardianSafety-logic.md)。Care+ 启用前仍须另行批准：

- Care+ 包含 Personal；是否同时包含 Family 或作为 Family 加购，以及 AI 成本、隐私、留存和安全
  边界；
- Care+ 的订阅升级、降级、宽限期、账单重试、退款、Family Sharing 和多设备一致性状态机。

任何在线产品不得借 Personal / legacy Supporter Product ID、本地布尔值或装饰购买记录提前解锁。
