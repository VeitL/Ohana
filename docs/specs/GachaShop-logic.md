# Gacha + Shop 规则书

确认日期：2026-06-13  
适用范围：Phase 7 Gacha + Shop 模块；覆盖盲盒抽取、扭蛋概率与期望值、商店价格、商店购买与发放、App Icon、2.5D 头像券、隐藏的线下兑换价格表、Gacha / Shop 云同步与备份演进。

本规则书覆盖宪法 D2/D3/D4/D7/D13/D14/G1/G2/G3/G4/G7/G8/G10 在 Gacha + Shop 模块中的首发语义。Shop/Gacha 是椰子经济的消费出口；所有钱包写入必须满足 Economy 规则书的合资、冻结、账本可重放与服务层硬边界。

## 已确认产品决定

- Gacha 是付费抽取的消费出口，不是照护奖励；其椰子产出不进入照护预算 / 冷却管线。防刷靠抽取成本、概率、期望值与账本可重放，大奖命中时真实发放 500🥥。
- Gacha 每抽成本为 80🥥；大奖 `coconut_grand_bundle_500` 保持 500🥥 与既有 id / 文案，但概率从 5% 降为 2%。腾出的 300bp 分配给无椰子产出的 message 类结果，保证每个系列概率总和仍为 10000bp。
- Gacha 抽取消费支持岛屿合资：当前抽取人 / 买家优先出资，余额不足时从其他未冻结人类钱包补差额；藏品、抽取日志和即时奖励仍归抽取人，出资人只记录补差支出。
- 当前 active human 缺失时，Gacha / Shop 可回退第一位可写人类；若 active human 明确存在但已离世，则阻止操作并显示冻结反馈，不自动切人。被删除的人类已物理移除，不是可选择钱包。
- Gacha 默认系列始终可抽；Noir 系列必须在同一 owner 集齐 Nana 8 个普通款后解锁；隐藏款必须在同一系列普通款集齐后才可能产出。
- Shop 价格按首发经济合理性固定：金色幸运券 80🥥，Streak 保护盾 180🥥，补签券 ×1 为 240🥥，补签券 ×3 为 580🥥，2.5D 头像券 1200🥥。
- 保护盾是事前保险，必须低于确定性事后补救的补签券；补签包保留折扣但不能比保护盾便宜到反向激励。
- 线下兑换功能首发仍由 `CoconutExchangeFeatureGate` 关闭；但保留的兑换价格表必须线性一致。JPY 为 500🥥→¥75、1000🥥→¥150、2000🥥→¥300；CNY 为 500🥥→¥2.5、1000🥥→¥5、2000🥥→¥10。
- App Icon 购买必须先完成 Shop 扣款 / 账本事实，再尝试系统图标切换；切换成功后才标记拥有和选中，切换失败必须按原出资人退款。
- Shop 所有道具发放必须收进服务层 fulfilment 边界，不由 View 直接承担业务发放。View 只负责触发购买、展示结果、打开后续 picker / sheet。
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
- GS-010：Shop 道具发放必须在购买成功后由 fulfilment 服务完成；发放失败必须退款给实际出资人，并在 metadata 中记录失败原因。
- GS-011：App Icon 购买顺序为扣款成功 -> setIcon -> 成功标记拥有 / 选中；setIcon 失败 -> 退款 -> 不标记拥有 / 不选中。
- GS-012：非消耗品所有权是持久业务事实，存入 SwiftData append-only 购买记录并参与备份 / 恢复 / CloudSync；设备偏好仍留在 `UserDefaults`。
- GS-013：消耗品库存（补签券、头像券库存、保护盾有效期、幸运券状态）是当前设备消费状态，首发继续由现有 inventory/defaults 管理，但发放入口必须服务化。
- GS-014：2.5D 头像券购买入口（含 Members 建档流程）必须复用 Shop 消费语义：合资、冻结钱包、账本、退款边界一致。
- GS-015：2.5D 升级目标和 Popout card 目标只允许活跃人类 / 宠物；离世对象保留历史，不参与新外观消费。
- GS-016：隐藏兑换价格表虽然首发不可达，仍必须保持每个国家同一线性汇率，避免未来打开时出现反直觉套利。
- GS-017：Gacha / Shop 规则必须有自动测试护栏：概率总和与区间、价格表、汇率线性、合资消费、冻结拒绝、App Icon 失败退款、SwiftData 所有权迁移、CloudSync serializer / applier。

## 九类全域问题雷达

1. **表面与入口完整性**：入口包括 GrowthUnlock / route guard、FunctionMenu、Oasis 弹层、Shop route container、Gacha route container、Shop View 命令、Gacha service 直接调用、Members 建档头像券购买、备份 / 恢复、CloudSync serializer / applier。首发兑换入口由 `CoconutExchangeFeatureGate` 关闭，但价格表仍作为未来地基保留。
2. **可用性与操作闭环**：Gacha 余额不足必须按岛屿可支配余额判断；Shop 购买失败需显示缺口或冻结反馈；App Icon 系统失败必须退款且不留下“已拥有”错觉；发放失败必须显示退款反馈。
3. **必要性与产品价值**：Gacha / Shop 均是 D2 留存经济的消费出口，首发必要；线下兑换为未来能力，首发必要性只在地基一致性；非消耗品 SwiftData 所有权迁移必要，因为所有权是跨设备 / 备份业务事实。
4. **业务合理性与数值合理性**：大奖 5% 使期望返还过高，降至 2%；幸运券、保护盾、补签券与头像券价格按收益确定性和月级目标调整；兑换小额不得比大额费率更优或更差。
5. **身份 / 归属 / 隐私边界**：抽取日志与藏品归买家；合资者只出资不获得藏品；冻结钱包不能消费 / 获奖；system 钱包不参与 Shop/Gacha 正式消费；隐私人类钱包计入合资可支配总额但 UI 明细仍按 Economy 隐私规则处理。
6. **状态机、时间与并发**：购买状态为 pending -> purchased -> fulfilled / refunded；Gacha 抽取为 funded -> rolled -> logged -> walletApplied -> saved；重复命令需依靠 transactionKey / append-only record 避免非消耗品重复拥有。
7. **副作用顺序与派生状态**：核心事实和钱包先于 UI 副作用；App Icon、库存、外观、Oasis XP、购买所有权属于 fulfilment；失败要退款并刷新投影；购买成功后发布 read-model revision。
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
2. `fundingPlanned`：用 Shop 合资计划确认资金足够。
3. `purchased`：写 CareLedgerEvent 与钱包支出。
4. `fulfilled`：fulfilment 服务发放库存 / 所有权 / 外观效果 / App Icon。
5. `refunded`：fulfilment 失败时按原出资人退款。
6. `visible`：UI 更新 toast、picker、库存或装备状态。

非消耗品所有权迁移：

1. `legacyDefaults`：旧版本只存在 `UserDefaults.purchasedShopItems`。
2. `migrationPending`：启动维护读取旧 key。
3. `recordsInserted`：为每个 item 生成稳定 legacy transactionKey 的 `ShopPurchaseRecord`。
4. `migrationMarked`：写入迁移标记；旧 key 暂保留供回退。
5. `queryBacked`：Shop / Inventory 从 SwiftData records 聚合所有权。

## 当前代码来源与差距

- Gacha 概率与大奖当前定义在 `Ohana/Features/Gacha/GachaModels.swift:132`、`Ohana/Features/Gacha/GachaModels.swift:166`、`Ohana/Features/Gacha/GachaModels.swift:200`；当前大奖 500bp，需降至 200bp。
- Gacha 抽取服务当前在 `Ohana/Features/Gacha/GachaModels.swift:645`，使用单人余额检查与单人扣款，需改为合资计划与冻结硬门。
- Shop 价格当前在 `Ohana/Features/Shop/ShopCatalog.swift:207`、`Ohana/Features/Shop/ShopCatalog.swift:234`，需按本规则书重定价。
- Shop 主购买服务已支持合资：`Ohana/Features/Economy/RewardEconomyCommands.swift:277`。
- App Icon 当前先调用系统 setIcon 再扣款：`Ohana/Features/Shop/Views/CoconutShopView+Commands.swift:98`，需改为先扣款后副作用失败退款。
- Shop fulfilment 当前在 View 中直接改库存 / UserDefaults：`Ohana/Features/Shop/Views/CoconutShopView+Commands.swift:287`，需收进服务层。
- Members 建档头像券购买当前单人扣款：`Ohana/Features/Members/MemberCreationService.swift:79`，需复用 Shop 消费语义。
- 隐藏兑换价格表当前 JPY / CNY 小额不线性：`Ohana/Models/CoconutExchangeRequest.swift:106`、`Ohana/Models/CoconutExchangeRequest.swift:124`。
- 非消耗品所有权当前使用 `UserDefaults.purchasedShopItems`：`Ohana/Features/Shop/Views/CoconutShopView.swift:84`，需迁入 SwiftData。

## 边界

- 本轮会改 SwiftData schema，新增 append-only Shop purchase record；迁移为轻量增表 + 启动维护导入旧 UserDefaults。
- 本轮会补 Gacha / Shop CloudSync serializer / applier，但不启用 CloudKit，不改变 `CoconutExchangeFeatureGate` 首发关闭语义。
- 本轮不重新设计真钱兑换产品，只修保留价格表的一致性。
- 本轮不把设备偏好迁出 UserDefaults；当前图标、称号、特效开关仍是设备态。
