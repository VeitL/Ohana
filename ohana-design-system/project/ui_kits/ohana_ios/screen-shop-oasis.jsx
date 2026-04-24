// Ohana — Coconut Shop & Life Tree / Oasis screens
// Adapts CoconutShopView and OasisHomeView: shop grid and tree visualization.

function OhanaShopScreen() {
  const items = [
    { emoji: '🛡️', name: '连胜保护盾', sub: '7 天有效', cost: 120, tag: '热门', c: '#48DBFB' },
    { emoji: '🥥🥥', name: '双倍椰子', sub: '48 小时', cost: 200, c: OH.primary },
    { emoji: '🌴', name: '椰林礼包', sub: '10 株 + 金币', cost: 300, tag: '限时', c: OH.teal },
    { emoji: '🎰', name: '扭蛋机 × 3', sub: '保底紫装', cost: 90, c: '#FD79A8' },
    { emoji: '👑', name: '皇家皮肤', sub: 'Mochi 专属', cost: 800, c: OH.yellow },
    { emoji: '🎈', name: '家庭派对', sub: '全员 +50 🥥', cost: 450, c: OH.orange },
  ];
  return (
    <OhIslandBg>
      <div style={{ padding: '62px 20px 100px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer, textTransform: 'uppercase', fontWeight: 600, letterSpacing: 0.4 }}>Ohana Shop</div>
            <div style={{ fontFamily: 'Nunito, sans-serif', fontSize: 30, fontWeight: 900, color: OH.fg, letterSpacing: -1, lineHeight: 1.1 }}>椰子商店</div>
          </div>
          <OhPill color={OH.primary}><span>🥥</span><span>1,284</span></OhPill>
        </div>

        {/* featured banner */}
        <div style={{
          borderRadius: 24, padding: 18,
          background: `linear-gradient(120deg, ${OH.primary}, #A8E300 60%, ${OH.teal})`,
          color: OH.ink, position: 'relative', overflow: 'hidden',
          boxShadow: '0 10px 30px rgba(200,255,0,0.25)',
        }}>
          <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 22, letterSpacing: -0.6, lineHeight: 1.1 }}>节日大礼包</div>
          <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, marginTop: 4, fontWeight: 600, opacity: 0.85 }}>购买赠送 1× 双倍椰子 · 3× 扭蛋机</div>
          <div style={{ display: 'flex', gap: 8, alignItems: 'center', marginTop: 14 }}>
            <button style={{ background: OH.ink, color: OH.primary, border: 0, padding: '10px 18px', borderRadius: 999, fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 13 }}>立即购买 · 580 🥥</button>
            <span style={{ fontFamily: 'Nunito, sans-serif', fontSize: 12, fontWeight: 800, opacity: 0.7, textDecoration: 'line-through' }}>原价 720</span>
          </div>
          <div style={{ position: 'absolute', right: -10, top: -20, fontSize: 130, opacity: 0.3, lineHeight: 1 }}>🥥</div>
        </div>

        {/* chip filter row */}
        <div style={{ display: 'flex', gap: 8, overflowX: 'auto' }}>
          {['全部', '道具', '扭蛋', '皮肤', '礼包'].map((t, i) => (
            <div key={i} style={{
              padding: '8px 14px', borderRadius: 999,
              background: i === 0 ? OH.primary : 'rgba(255,255,255,0.08)',
              color: i === 0 ? OH.ink : OH.fg,
              border: i === 0 ? 'none' : '1px solid rgba(255,255,255,0.1)',
              fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 12, whiteSpace: 'nowrap',
            }}>{t}</div>
          ))}
        </div>

        {/* grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
          {items.map((it, i) => (
            <div key={i} style={{
              ...glassBg, padding: 14, position: 'relative',
              display: 'flex', flexDirection: 'column', gap: 6,
            }}>
              {it.tag && <div style={{ position: 'absolute', top: 10, right: 10, background: it.c, color: OH.ink, padding: '2px 8px', borderRadius: 999, fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 9, textTransform: 'uppercase' }}>{it.tag}</div>}
              <div style={{ width: 54, height: 54, borderRadius: 16, background: `${it.c}22`, border: `1px solid ${it.c}44`, display: 'grid', placeItems: 'center', fontSize: 28, marginBottom: 4 }}>{it.emoji}</div>
              <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 14, color: OH.fg, lineHeight: 1.2 }}>{it.name}</div>
              <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, color: OH.fgSec }}>{it.sub}</div>
              <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 4 }}>
                <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 15, color: OH.primary }}>🥥 {it.cost}</span>
                <div style={{ width: 28, height: 28, borderRadius: 999, background: OH.primary, color: OH.ink, display: 'grid', placeItems: 'center' }}>
                  <OhIcon name="plus" size={14} color={OH.ink}/>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>
    </OhIslandBg>
  );
}

function OhanaOasisScreen() {
  return (
    <OhIslandBg>
      <div style={{ padding: '62px 20px 100px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer, textTransform: 'uppercase', fontWeight: 600, letterSpacing: 0.4 }}>Oasis · 绿洲</div>
            <div style={{ fontFamily: 'Nunito, sans-serif', fontSize: 28, fontWeight: 900, color: OH.fg, letterSpacing: -0.8 }}>生命之树</div>
          </div>
          <OhPill color={OH.primary}><span>🥥</span><span>1,284</span></OhPill>
        </div>

        {/* Tree scene */}
        <div style={{
          position: 'relative', borderRadius: 28, overflow: 'hidden',
          height: 360,
          background: 'radial-gradient(ellipse at 50% 100%, #1A2E8A 0%, #0C1640 55%, #000 100%)',
          border: '1px solid rgba(200,255,0,0.2)',
        }}>
          {/* Stars */}
          {Array.from({length: 24}).map((_, i) => (
            <div key={i} style={{
              position: 'absolute',
              top: `${(i*37)%70}%`, left: `${(i*53)%95}%`,
              width: i%3===0? 3:2, height: i%3===0? 3:2,
              background: '#fff', opacity: 0.3+((i%5)/10), borderRadius: 999,
            }}/>
          ))}
          {/* Moon */}
          <div style={{ position: 'absolute', top: 32, right: 36, width: 46, height: 46, borderRadius: 999, background: '#FFEAA7', boxShadow: '0 0 30px rgba(255,234,167,0.6)' }}/>
          {/* Island */}
          <div style={{ position: 'absolute', bottom: 0, left: 0, right: 0, height: 120, background: 'linear-gradient(180deg, #FDCB6E 0%, #E67E22 100%)', borderRadius: '50% 50% 0 0 / 30% 30% 0 0' }}/>
          {/* Sand dots */}
          <div style={{ position: 'absolute', bottom: 20, left: '30%', fontSize: 14 }}>🌺</div>
          <div style={{ position: 'absolute', bottom: 16, right: '24%', fontSize: 16 }}>🐚</div>
          {/* Tree */}
          <div style={{ position: 'absolute', bottom: 60, left: '50%', transform: 'translateX(-50%)', fontSize: 140, filter: 'drop-shadow(0 6px 20px rgba(200,255,0,0.4))' }}>🌴</div>
          {/* Level badge floating */}
          <div style={{
            position: 'absolute', top: 28, left: 24,
            background: OH.primary, color: OH.ink,
            padding: '8px 14px', borderRadius: 999,
            fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 14,
            boxShadow: '0 6px 18px rgba(200,255,0,0.45)',
          }}>Lv.5 · 椰林</div>
          {/* Energy floaters */}
          <div style={{ position: 'absolute', top: 90, left: 60, fontSize: 20, opacity: 0.7 }}>✨</div>
          <div style={{ position: 'absolute', top: 140, right: 80, fontSize: 16, opacity: 0.5 }}>✨</div>
        </div>

        {/* Progress card */}
        <OhGlass padding={16}>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 10 }}>
            <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 14, color: OH.fg }}>成长进度</span>
            <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgSec }}>790 / 1,000 能量</span>
          </div>
          <div style={{ position: 'relative', height: 10, background: 'rgba(255,255,255,0.08)', borderRadius: 999, overflow: 'hidden' }}>
            <div style={{ position: 'absolute', inset: 0, width: '79%', background: `linear-gradient(90deg, ${OH.primary}, ${OH.teal})`, borderRadius: 999, boxShadow: `0 0 16px ${OH.primary}` }}/>
          </div>
          <div style={{ display: 'flex', justifyContent: 'space-between', marginTop: 14 }}>
            {[
              { k: '被动收入', v: '+12 🥥/日' },
              { k: '家庭贡献', v: '4 成员' },
              { k: '总繁荣', v: '18,402' },
            ].map((s, i) => (
              <div key={i} style={{ textAlign: 'center' }}>
                <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 16, color: OH.fg }}>{s.v}</div>
                <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 10, color: OH.fgTer, textTransform: 'uppercase', letterSpacing: 0.3, marginTop: 2 }}>{s.k}</div>
              </div>
            ))}
          </div>
        </OhGlass>

        {/* Action */}
        <button style={{
          height: 52, borderRadius: 999, border: 0,
          background: OH.primary, color: OH.ink,
          fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 15,
          boxShadow: '0 8px 24px rgba(224,255,0,0.35)',
          display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
        }}>
          <span>⚡</span>
          <span>注入 50 🥥 能量</span>
        </button>

        {/* Milestones */}
        <div style={{ padding: '0 4px', marginTop: 2 }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 14, color: OH.fg }}>下一个里程碑</span>
        </div>
        <OhGlass padding={14}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
            <div style={{ width: 48, height: 48, borderRadius: 14, background: `${OH.yellow}22`, border: `1px solid ${OH.yellow}55`, display: 'grid', placeItems: 'center', fontSize: 24 }}>🏆</div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 14, color: OH.fg }}>Lv.6 · 椰林之王</div>
              <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, color: OH.fgSec, marginTop: 2 }}>解锁专属岛屿皮肤 + 每日 18 🥥</div>
            </div>
            <OhIcon name="chev" size={16} color={OH.fgTer}/>
          </div>
        </OhGlass>
      </div>
    </OhIslandBg>
  );
}

window.OhanaShopScreen = OhanaShopScreen;
window.OhanaOasisScreen = OhanaOasisScreen;
