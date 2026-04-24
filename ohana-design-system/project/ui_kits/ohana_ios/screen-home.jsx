// Ohana — Home Dashboard screen
// Adapts GoDashboardView.swift: greeting, Life Tree hero, coconut balance,
// wallet cards (critters), today's quick actions, health alerts.

function OhanaHomeScreen() {
  return (
    <OhIslandBg>
      <div style={{ padding: '62px 20px 100px', display: 'flex', flexDirection: 'column', gap: 16 }}>
        {/* Header */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 4 }}>
          <div>
            <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer, letterSpacing: 0.3, textTransform: 'uppercase', fontWeight: 600 }}>早上好</div>
            <div style={{ fontFamily: 'Nunito, sans-serif', fontSize: 26, fontWeight: 900, color: OH.fg, letterSpacing: -0.6, lineHeight: 1.1 }}>Mei's 岛屿</div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <OhPill color={OH.primary}>
              <span style={{ fontSize: 15 }}>🥥</span>
              <span style={{ fontSize: 14 }}>1,284</span>
            </OhPill>
            <div style={{ width: 40, height: 40, borderRadius: 999, background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.15)', display: 'grid', placeItems: 'center', color: OH.fg }}>
              <OhIcon name="bell" size={18} color={OH.fg}/>
            </div>
          </div>
        </div>

        {/* Life Tree Hero */}
        <OhGlass padding={18}>
          <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
            <div style={{
              width: 72, height: 72, borderRadius: 20, position: 'relative',
              background: `radial-gradient(circle at 30% 30%, ${OH.primary}33, transparent 65%), linear-gradient(160deg, #1A0E4B, #0C1640)`,
              border: '1px solid rgba(200,255,0,0.4)',
              display: 'grid', placeItems: 'center',
            }}>
              <span style={{ fontSize: 40, lineHeight: 1 }}>🌴</span>
              <div style={{ position: 'absolute', top: -6, right: -6, background: OH.primary, color: OH.ink, borderRadius: 999, padding: '2px 7px', fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 10 }}>Lv.5</div>
            </div>
            <div style={{ flex: 1 }}>
              <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 16, color: OH.fg, marginBottom: 2 }}>生命之树 · Life Tree</div>
              <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgSec, marginBottom: 8 }}>离下一级还差 210 🥥 能量</div>
              <div style={{ position: 'relative', height: 6, background: 'rgba(255,255,255,0.08)', borderRadius: 999, overflow: 'hidden' }}>
                <div style={{ position: 'absolute', inset: 0, width: '68%', background: `linear-gradient(90deg, ${OH.primary}, ${OH.teal})`, borderRadius: 999 }}/>
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8, marginTop: 14 }}>
            <button style={{ flex: 1, height: 38, borderRadius: 999, background: OH.primary, color: OH.ink, border: 0, fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 13, boxShadow: '0 4px 12px rgba(224,255,0,0.25)' }}>注入能量</button>
            <button style={{ flex: 1, height: 38, borderRadius: 999, background: 'rgba(255,255,255,0.1)', color: OH.fg, border: '1px solid rgba(255,255,255,0.15)', fontFamily: 'Nunito, sans-serif', fontWeight: 700, fontSize: 13 }}>前往绿洲</button>
          </div>
        </OhGlass>

        {/* Critters section */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 4, padding: '0 4px' }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 15, color: OH.fg }}>我的 Critters</span>
          <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer }}>3 · 查看全部</span>
        </div>

        {/* Critter wallet card (stack of 2 visible) */}
        <div style={{ position: 'relative', height: 180 }}>
          {/* Back card peek */}
          <div style={{
            position: 'absolute', inset: '10px 16px 0 16px', height: 160, borderRadius: 22,
            background: 'linear-gradient(135deg, #5B6AFF, #273C75)', opacity: 0.55,
            transform: 'scale(0.95)', transformOrigin: 'bottom',
          }}/>
          {/* Front wallet card — dog */}
          <div style={{
            position: 'absolute', inset: 0, borderRadius: 24, overflow: 'hidden',
            boxShadow: '0 12px 32px rgba(0,0,0,0.3)',
          }}>
            <div style={{
              position: 'absolute', inset: 0,
              backgroundImage: 'url(../../assets/backgrounds/dog_golden_retriever.png)',
              backgroundSize: 'cover', backgroundPosition: 'center 30%',
              filter: 'blur(12px) saturate(110%)',
              transform: 'scale(1.15)',
            }}/>
            <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(0,0,0,0.1), rgba(10,10,20,0.75))' }}/>
            {/* Photo cutout */}
            <div style={{
              position: 'absolute', right: -6, bottom: -12, width: 155, height: 195,
              backgroundImage: 'url(../../assets/backgrounds/dog_golden_retriever.png)',
              backgroundSize: 'cover', backgroundPosition: 'center 25%',
              borderRadius: 24,
              maskImage: 'linear-gradient(to left, black 70%, transparent)',
              WebkitMaskImage: 'linear-gradient(to left, black 70%, transparent)',
            }}/>
            <div style={{ position: 'relative', padding: 16, color: OH.fg, height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}>
                <OhGlassPill><span>🐕</span><span>Golden · ♂ 3y</span></OhGlassPill>
                <OhGlassPill style={{ color: OH.primary }}><span>🔥</span><span>42 天</span></OhGlassPill>
              </div>
              <div>
                <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 30, letterSpacing: -0.8, lineHeight: 1 }}>Mochi</div>
                <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgSec, marginTop: 4 }}>上次遛狗 · 2h 前 · 1.2km</div>
              </div>
              <div style={{ display: 'flex', gap: 6 }}>
                <OhGlassPill style={{ padding: '5px 10px' }}><span style={{ color: OH.primary }}>●</span><span>健康</span></OhGlassPill>
                <OhGlassPill style={{ padding: '5px 10px' }}><span>24.3 kg</span></OhGlassPill>
              </div>
            </div>
          </div>
        </div>
        {/* Carousel dots */}
        <div style={{ display: 'flex', justifyContent: 'center', gap: 5, marginTop: -8 }}>
          <span style={{ width: 18, height: 4, borderRadius: 999, background: OH.fg }}/>
          <span style={{ width: 4, height: 4, borderRadius: 999, background: 'rgba(255,255,255,0.3)' }}/>
          <span style={{ width: 4, height: 4, borderRadius: 999, background: 'rgba(255,255,255,0.3)' }}/>
        </div>

        {/* Today's bento */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 4, padding: '0 4px' }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 15, color: OH.fg }}>今日 · Mochi</span>
          <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer }}>12 月 3 日</span>
        </div>
        <OhGlass padding={14}>
          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 10 }}>
            <OhBento label="步数" value="6,812" sub="目标 8,000" accent={OH.primary} icon={<OhIcon name="walk" size={14} color={OH.primary}/>}/>
            <OhBento label="喂食" value="2" unit="/3" sub="待 17:00 晚餐" accent={OH.orange} icon={<OhIcon name="food" size={14} color={OH.orange}/>}/>
            <OhBento label="饮水" value="380" unit="ml" sub="建议 500 ml" accent={OH.teal} icon={<OhIcon name="drop" size={14} color={OH.teal}/>}/>
            <OhBento label="今日 🥥" value="+42" sub="暴击 × 2 次" accent={OH.yellow} icon={<OhIcon name="bolt" size={14} color={OH.yellow}/>}/>
          </div>
        </OhGlass>

        {/* Alert row */}
        <div style={{
          display: 'flex', alignItems: 'center', gap: 10,
          padding: '12px 14px', borderRadius: 999,
          background: OH.yellow, color: OH.ink,
        }}>
          <span style={{ fontSize: 18 }}>⚠️</span>
          <div style={{ flex: 1 }}>
            <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 13 }}>狂犬疫苗 12 天后到期</div>
          </div>
          <OhIcon name="chev" size={16} color={OH.ink}/>
        </div>

        {/* Quick Access bar */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 2, padding: '0 4px' }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 15, color: OH.fg }}>Quick Access</span>
          <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgTer }}>编辑</span>
        </div>
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
          {[
            { emoji: '🚶', label: '遛狗', tint: OH.primary },
            { emoji: '🍽️', label: '喂食', tint: OH.orange },
            { emoji: '💧', label: '饮水', tint: OH.teal },
            { emoji: '💩', label: '铲屎', tint: '#A1887F' },
          ].map((a, i) => (
            <div key={i} style={{
              background: 'rgba(255,255,255,0.08)', border: '1px solid rgba(255,255,255,0.10)',
              borderRadius: 18, padding: '12px 6px',
              display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
            }}>
              <div style={{
                width: 40, height: 40, borderRadius: 14,
                background: `${a.tint}22`, border: `1px solid ${a.tint}44`,
                display: 'grid', placeItems: 'center', fontSize: 20,
              }}>{a.emoji}</div>
              <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 700, fontSize: 11, color: OH.fg }}>{a.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Floating Dock */}
      <div style={{
        position: 'absolute', bottom: 26, left: '50%', transform: 'translateX(-50%)',
        height: 62, padding: '0 6px',
        display: 'flex', alignItems: 'center', gap: 4,
        background: 'rgba(20,22,40,0.65)',
        backdropFilter: 'blur(28px) saturate(140%)',
        WebkitBackdropFilter: 'blur(28px) saturate(140%)',
        border: '1px solid rgba(255,255,255,0.12)',
        borderRadius: 22,
        boxShadow: '0 10px 30px rgba(0,0,0,0.35)',
        zIndex: 10,
      }}>
        {[
          { icon: 'house', label: '首页', active: true },
          { icon: 'cal',   label: '日历' },
          { icon: 'paw',   label: 'Critters' },
          { icon: 'tree',  label: '绿洲' },
        ].map((t, i) => (
          <div key={i} style={{
            display: 'flex', alignItems: 'center', gap: 6,
            padding: t.active ? '10px 14px' : '10px 12px',
            borderRadius: 16,
            background: t.active ? OH.primary : 'transparent',
            color: t.active ? OH.ink : OH.fgSec,
          }}>
            <OhIcon name={t.icon} size={18} color={t.active ? OH.ink : OH.fgSec}/>
            {t.active && <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 12 }}>{t.label}</span>}
          </div>
        ))}
      </div>
    </OhIslandBg>
  );
}

window.OhanaHomeScreen = OhanaHomeScreen;
