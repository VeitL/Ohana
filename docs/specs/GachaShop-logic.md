# Gacha + Shop 规则书

确认日期：2026-06-13  
最近更新：2026-07-24
适用范围：Phase 7 Gacha + Shop 模块；覆盖盲盒抽取、扭蛋概率与期望值、商店价格、商店购买与发放、App Icon、2.5D 头像券、隐藏的线下兑换价格表、Gacha / Shop 云同步与备份演进。

本规则书覆盖宪法 D2/D3/D4/D7/D13/D14/G1/G2/G3/G4/G7/G8/G10 在 Gacha + Shop 模块中的首发语义。Shop/Gacha 是椰子经济的消费出口；所有钱包写入必须满足 Economy 规则书的合资、冻结、账本可重放与服务层硬边界。

## 已确认产品决定

- Gacha 是付费抽取的消费出口，不是照护奖励；其椰子产出不进入照护预算 / 冷却管线。防刷靠抽取成本、概率、期望值与账本可重放，大奖命中时真实发放 500🥥。
- Gacha 每抽成本为 80🥥；大奖 `coconut_grand_bundle_500` 保持 500🥥 与既有 id / 文案，但概率从 5% 降为 2%。腾出的 300bp 分配给无椰子产出的 message 类结果，保证每个系列概率总和仍为 10000bp。
- Gacha 抽取消费支持岛屿合资：当前抽取人 / 买家优先出资，余额不足时从其他未冻结人类钱包补差额；藏品、抽取日志和即时奖励仍归抽取人，出资人只记录补差支出。
- 当前 active human 缺失时，Gacha / Shop 可回退第一位可写人类；若 active human 明确存在但已离世，则阻止操作并显示冻结反馈，不自动切人。被删除的人类已物理移除，不是可选择钱包。
- Gacha 默认系列始终可抽；Noir 系列必须在同一 owner 集齐 Nana 8 个普通款后解锁；隐藏款必须在同一系列普通款集齐后才可能产出。
- Shop 价格按首发经济合理性固定：金色幸运券 20🥥，Streak 保护盾 180🥥，2.5D 头像券 1200🥥。
- 补签券写入路径已随旧打卡系统退役，因此不再陈列或新增出售；旧 ×1/×3 目录项只保留 240🥥/580🥥 的历史订单履约与备份恢复能力，不删除既有库存。
- 生命树能量只在 Oasis 内注入，不在 Shop 重复陈列；历史 `boost_tree` / `boost_tree_large` 订单仍保留可解析 fulfilment，以免升级后成为死单。
- 线下兑换功能首发仍由 `CoconutExchangeFeatureGate` 关闭；但保留的兑换价格表必须线性一致。JPY 为 500🥥→¥75、1000🥥→¥150、2000🥥→¥300；CNY 为 500🥥→¥2.5、1000🥥→¥5、2000🥥→¥10。
- Shop 为最终销售：用户确认前可取消，校验或保存失败不得扣款；钱包支出与购买事实一旦同事务提交成功，不允许撤销或退款。应用暂时失败时保留 entitlement / outbox，自动或手动重试，不得再次扣款。
- App Icon 购买先原子提交 Shop 扣款、账本与所有权事实，再尝试系统图标切换；系统拒绝或暂时失败不撤销所有权，用户可从百宝箱重试应用。
- Shop 所有道具发放必须收进服务层 fulfilment 边界，不由 View 直接承担业务发放。View 只负责触发购买、展示结果、打开后续 picker / sheet。
- 每个 catalog ID 必须在单一 `ShopProductApplicationCatalog` 中映射到实际应用路径；有宠物 / 狗狗前置条件的效果必须在扣款前失败关闭，未知 ID 不得出售。
- `purchasedShopItems` 的非消耗品所有权必须从 `UserDefaults` 迁入 SwiftData append-only 购买记录；偏好与设备态（当前图标、称号、特效开关）继续保留在 `UserDefaults`。
- GachaOwnedItem、GachaDrawLog 与 Shop 非消耗品购买记录必须接入 CloudSync serializer / applier；首发不启用 CloudKit，但同步地基语义必须闭合。
- Shop / Gacha 只允许对未离世的人类钱包消费；2.5D 头像升级与 Popout card 目标只允许活跃人类 / 宠物。

## 业务不变量

- GS-001：Gacha 概率表每个系列总和恒为 10000bp；隐藏款 200bp，普通款总计 2000bp，大奖 200bp，其余 instant / message 总计 7800bp。
- GS-002：Gacha 大奖 id `coconut_grand_bundle_500` 和 `coconutDelta == 500` 不变；概率调整不得破坏历史抽取记录对 id 的引用。
- GS-003：Gacha 每次成功抽取必须写一条 `GachaDrawLog`；抽中藏品时同步创建或累加一条 `GachaOwnedItem`；instant/message 不创建藏品。
- GS-004：Gacha 消费必须通过钱包 / CareLedger 服务层写入；不得让任何人类钱包透支，不得绕过账本直接改 `coconutBalance`。
- GS-005：Gacha 合资时，买家优先出资；其他可写人类按稳定顺序补差额。任一钱包写入失败，整次抽取必须回滚，不留下 draw log、owned item 或半笔支出。
- GS-006：Gacha 即时椰子奖励是抽奖回报，不走照护预算；但必须是 `CoconutLedgerEntry` + `CareLedgerEvent` 可重放事实，并归属抽取人。
- GS-007：Gacha 对离世 active human 必须抛冻结错误；对缺失 active human 可选择第一位可写人类；没有可写人类时不可抽。
- GS-008：Shop 分类 `cashExchange` 在 `CoconutExchangeFeatureGate.isEnabled == false` 时不可见；直接调用 create/confirm/cancel 也不得写入请求或钱包。
- GS-009：Shop 正式购买必须通过 `ShopPurchaseCommandService` / `RewardEconomyCommandExecutor`；买家不足时使用岛屿合资，仍不得透支，不得写 system 钱包。
- GS-010：Shop 道具发放必须在购买成功后由 fulfilment 服务完成；发放失败必须保留已购买 entitlement / outbox、记录原因并重试，禁止生成补偿退款或删除所有权。
- GS-011：App Icon 购买顺序为原子提交扣款 / 账本 / 所有权 -> setIcon；setIcon 失败只影响当前设备选择状态，不影响永久所有权，重试应用不得再次扣款。
- GS-012：非消耗品所有权是持久业务事实，存入 SwiftData append-only 购买记录并参与备份 / 恢复 / CloudSync；设备偏好仍留在 `UserDefaults`。
- GS-013：当前在售消耗品（头像券库存、保护盾有效期、幸运券状态）是当前设备消费状态，首发继续由现有 inventory/defaults 管理，但发放入口必须服务化；补签券仅作为旧订单/备份兼容库存保留，不得重新陈列。
- GS-014：2.5D 头像券购买入口（含 Members 建档流程）必须复用 Shop 消费语义：合资、冻结钱包、账本、最终销售与幂等 fulfilment 边界一致。
- GS-015：2.5D 升级目标和 Popout card 目标只允许活跃人类 / 宠物；离世对象保留历史，不参与新外观消费。
- GS-016：隐藏兑换价格表虽然首发不可达，仍必须保持每个国家同一线性汇率，避免未来打开时出现反直觉套利。
- GS-017：Gacha / Shop 规则必须有自动测试护栏：概率总和与区间、价格表、catalog 全映射、应用前置条件、合资消费与执行前重校验、冻结拒绝、App Icon 失败保留所有权、重试不重复扣款、SwiftData 所有权迁移、CloudSync serializer / applier。

## 九类全域问题雷达

1. **表面与入口完整性**：入口包括 GrowthUnlock / route guard、FunctionMenu、Oasis 弹层、Shop route container、Gacha route container、Shop View 命令、Gacha service 直接调用、Members 建档头像券购买、备份 / 恢复、CloudSync serializer / applier。首发兑换入口由 `CoconutExchangeFeatureGate` 关闭，但价格表仍作为未来地基保留。
2. **可用性与操作闭环**：Gacha 余额不足必须按岛屿可支配余额判断；Shop 购买失败需显示缺口、前置对象或冻结反馈；确认页展示每位出资额与“购买后不可撤销/退款”；App Icon 或库存应用失败必须展示保留所有权和重试入口。
3. **必要性与产品价值**：Gacha / Shop 均是 D2 留存经济的消费出口，首发必要；线下兑换为未来能力，首发必要性只在地基一致性；非消耗品 SwiftData 所有权迁移必要，因为所有权是跨设备 / 备份业务事实。
4. **业务合理性与数值合理性**：大奖 5% 使期望返还过高，降至 2%；幸运券、保护盾与头像券价格按收益确定性和月级目标调整；没有有效消费端的旧补签券停止销售；兑换小额不得比大额费率更优或更差。
5. **身份 / 归属 / 隐私边界**：抽取日志与藏品归买家；合资者只出资不获得藏品；冻结钱包不能消费 / 获奖；system 钱包不参与 Shop/Gacha 正式消费；隐私人类钱包计入合资可支配总额但 UI 明细仍按 Economy 隐私规则处理。
6. **状态机、时间与并发**：购买状态为 pending -> purchased -> fulfilling -> fulfilled，无法自动处理时进入 manualReview；旧 `refundPending/refunded` 仅为数据兼容，新购买不得进入。Gacha 抽取为 funded -> rolled -> logged -> walletApplied -> saved；重复命令依靠 transactionKey / append-only record 阻止重复扣款和重复所有权。
7. **副作用顺序与派生状态**：核心事实、钱包与 entitlement 先于设备副作用；App Icon、库存、外观与历史 Oasis XP 属于 fulfilment；失败只重试应用并刷新投影，不能逆转已提交购买；购买成功后发布 read-model revision。
8. **持久化与演进边界**：新增 `ShopPurchaseRecord` 需 schema 升版、轻量迁移、启动旧 `purchasedShopItems` 导入、备份兼容、CloudSync 注册；Gacha records 需 serializer / applier 闭合，但不启用 CloudKit。
9. **验证与可观测性**：自动测试覆盖服务层不变量；无法自动验收的真实系统图标切换和 UI 遍历写入统一中文 track list。

## 状态机

Gacha 抽取：

1. `selectBuyer`：解析 active human；缺失时回退第一位可写人类，冻结时失败。
2. `fundingPlanned`：按 80🥥 计算合资出资；不足则失败。
3. `rollResolved`：按系列概率产出 collectible / instantReward / message。
4. `factsStaged`：插入 draw log，必要时插入 / 累加 owned item，记录 CareLedgerEvent。
5. `walletApplied`：写入买家 / 合资者支出，若有即时奖励则写入买家收入。
6. `saved`：事务保存成功。
7. `rolledBack`：任一写入失败回滚，不保留半成品。

Shop 购买：

1. `pendingPurchase`：用户确认某 ShopItem。
2. `preflight`：确认 catalog 有实际应用、所需 active Pet / Dog 存在，并生成合资预览。
3. `fundingRevalidated`：实际执行前按当前钱包与冻结状态重新校验每位出资额；失败则不写任何事实。
4. `purchased`：同事务写 CareLedgerEvent、钱包支出、购买 entitlement 与 fulfilment outbox；从此不可撤销或退款。
5. `fulfilling`：服务幂等应用库存 / 所有权 / 外观效果 / App Icon；失败保持 outbox 并有界重试。
6. `manualReview`：自动重试无法解决时保留购买，百宝箱提供手动重试；不得再次扣款。
7. `fulfilled`：应用 checkpoint 与完成状态提交。
8. `visible`：UI 更新 toast、picker、库存或装备状态。

非消耗品所有权迁移：

1. `legacyDefaults`：旧版本只存在 `UserDefaults.purchasedShopItems`。
2. `migrationPending`：启动维护读取旧 key。
3. `recordsInserted`：为每个 item 生成稳定 legacy transactionKey 的 `ShopPurchaseRecord`。
4. `migrationMarked`：写入迁移标记；旧 key 暂保留供回退。
5. `queryBacked`：Shop / Inventory 从 SwiftData records 聚合所有权。

## 当前代码来源

- Catalog、定价与 catalog-to-runtime 应用映射：`Ohana/Features/Shop/ShopCatalog.swift`。
- 合资预览与原子购买命令：`Ohana/Features/Economy/RewardEconomyCommands.swift`。
- 幂等库存 / 所有权发放：`Ohana/Features/Shop/ShopPurchaseFulfillmentService.swift`。
- 启动恢复、手动重试与 legacy refund 状态收口：`Ohana/Features/Shop/ShopPurchaseRecoveryService.swift`。
- Append-only 所有权与 durable outbox：`Ohana/Features/Shop/ShopPurchaseRecordStore.swift`、`Ohana/Models/ShopPurchaseAttempt.swift`。

## 边界

- 本轮会改 SwiftData schema，新增 append-only Shop purchase record；迁移为轻量增表 + 启动维护导入旧 UserDefaults。
- 本轮会补 Gacha / Shop CloudSync serializer / applier，但不启用 CloudKit，不改变 `CoconutExchangeFeatureGate` 首发关闭语义。
- 本轮不重新设计真钱兑换产品，只修保留价格表的一致性。
- 本轮不把设备偏好迁出 UserDefaults；当前图标、称号、特效开关仍是设备态。
