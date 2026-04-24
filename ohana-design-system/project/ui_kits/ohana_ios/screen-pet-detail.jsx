// Ohana — Pet Detail screen
// Adapts GoPetDetailView: cutout pet photo, bento stats, streak, quick-access grid, health alerts.

function OhanaPetDetailScreen() {
  return (
    <OhIslandBg>
      <div style={{ padding: '62px 20px 100px', display: 'flex', flexDirection: 'column', gap: 14 }}>
        {/* Top bar */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 6, color: OH.fgSec, fontFamily: 'Nunito, sans-serif', fontWeight: 700, fontSize: 14 }}>
            <div style={{ width: 36, height: 36, borderRadius: 999, background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.15)', display: 'grid', placeItems: 'center' }}>
              <OhIcon name="chev" size={18} color={OH.fg} /* flipped */ />
            </div>
          </div>
          <div style={{ display: 'flex', gap: 8 }}>
            <OhPill color={OH.primary}><span>🥥</span><span>1,284</span></OhPill>
            <div style={{ width: 36, height: 36, borderRadius: 999, background: 'rgba(255,255,255,0.1)', border: '1px solid rgba(255,255,255,0.15)', display: 'grid', placeItems: 'center' }}>
              <span style={{ fontSize: 16, color: OH.fg }}>⋯</span>
            </div>
          </div>
        </div>

        {/* Hero card: big portrait with broken-frame cutout feel */}
        <div style={{
          position: 'relative', borderRadius: 28, overflow: 'hidden',
          height: 280, background: 'linear-gradient(160deg, rgba(255,255,255,0.18), rgba(255,255,255,0.04))',
          border: '1px solid rgba(255,255,255,0.22)',
          boxShadow: '0 14px 34px rgba(0,0,0,0.3)',
        }}>
          <div style={{ position: 'absolute', inset: 0, backgroundImage: 'url(../../assets/backgrounds/dog_golden_retriever.png)', backgroundSize: 'cover', backgroundPosition: 'center 30%', filter: 'blur(28px) saturate(120%)', transform: 'scale(1.2)' }}/>
          <div style={{ position: 'absolute', inset: 0, background: 'linear-gradient(180deg, rgba(13,6,56,0.55) 0%, rgba(13,6,56,0.25) 40%, rgba(13,6,56,0.8) 100%)' }}/>
          {/* cutout */}
          <div style={{
            position: 'absolute', right: -20, bottom: -20, width: 260, height: 320,
            backgroundImage: 'url(../../assets/backgrounds/dog_golden_retriever.png)',
            backgroundSize: 'cover', backgroundPosition: 'center 20%',
            maskImage: 'radial-gradient(ellipse 70% 75% at 40% 50%, black 60%, transparent 90%)',
            WebkitMaskImage: 'radial-gradient(ellipse 70% 75% at 40% 50%, black 60%, transparent 90%)',
          }}/>
          <div style={{ position: 'relative', padding: 18, height: '100%', display: 'flex', flexDirection: 'column', justifyContent: 'space-between' }}>
            <div style={{ display: 'flex', gap: 6 }}>
              <OhGlassPill><span>🐕</span><span>Golden Retriever</span></OhGlassPill>
              <OhGlassPill><span>♂</span><span>3 y · 24.3 kg</span></OhGlassPill>
            </div>
            <div>
              <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 44, letterSpacing: -1.5, lineHeight: 1, color: OH.fg }}>Mochi</div>
              <div style={{ display: 'flex', gap: 8, marginTop: 10 }}>
                <OhPill color={OH.primary}><span>🔥</span><span>42 天</span></OhPill>
                <OhGlassPill style={{ color: OH.primary }}><span>●</span><span>健康</span></OhGlassPill>
                <OhGlassPill><span>🌟</span><span>Lv.12</span></OhGlassPill>
              </div>
            </div>
          </div>
        </div>

        {/* Metric: main number */}
        <OhGlass padding={16}>
          <div style={{ display: 'flex', alignItems: 'flex-end', justifyContent: 'space-between' }}>
            <div>
              <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, fontWeight: 600, color: OH.fgTer, textTransform: 'uppercase', letterSpacing: 0.4 }}>本周步数</div>
              <div style={{ display: 'flex', alignItems: 'baseline', gap: 6, marginTop: 2 }}>
                <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 52, color: OH.fg, letterSpacing: -2, lineHeight: 1 }}>48,206</span>
                <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 700, fontSize: 14, color: OH.fgSec }}>步</span>
              </div>
              <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.teal, marginTop: 4, fontWeight: 600 }}>↑ 比上周 +12%</div>
            </div>
            {/* Mini spark bars */}
            <div style={{ display: 'flex', alignItems: 'flex-end', gap: 5, height: 60 }}>
              {[28, 42, 36, 58, 48, 72, 64].map((h, i) => (
                <div key={i} style={{
                  width: 8, height: `${h}%`, borderRadius: 4,
                  background: i === 5 ? OH.primary : 'rgba(200,255,0,0.3)',
                }}/>
              ))}
            </div>
          </div>
        </OhGlass>

        {/* Bento grid */}
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: 10 }}>
          <OhBento label="饮水" value="380" unit="ml" accent={OH.teal} icon={<OhIcon name="drop" size={12} color={OH.teal}/>}/>
          <OhBento label="喂食" value="2/3" accent={OH.orange} icon={<OhIcon name="food" size={12} color={OH.orange}/>}/>
          <OhBento label="睡眠" value="8.4" unit="h" accent="#A855F7" icon={<OhIcon name="star" size={12} color="#A855F7"/>}/>
        </div>

        {/* Quick Access grid */}
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginTop: 4, padding: '0 4px' }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 15, color: OH.fg }}>Quick Access</span>
          <OhGlassPill><OhIcon name="plus" size={12} color={OH.fg}/><span>自定义</span></OhGlassPill>
        </div>
        <OhGlass padding={14}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10 }}>
            {[
              { e: '🚶', l: '遛狗',  c: OH.primary, hot: true },
              { e: '🍽️', l: '喂食',  c: OH.orange },
              { e: '💧', l: '饮水',  c: OH.teal },
              { e: '💩', l: '铲屎',  c: '#A1887F' },
              { e: '🛁', l: '洗澡',  c: '#48DBFB' },
              { e: '💊', l: '用药',  c: '#FD79A8' },
              { e: '⚖️', l: '称重',  c: '#FDCB6E' },
              { e: '💰', l: '记账',  c: OH.yellow },
            ].map((a, i) => (
              <div key={i} style={{
                background: `${a.c}1F`, border: `1px solid ${a.c}3A`,
                borderRadius: 14, padding: '10px 4px',
                display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4,
                position: 'relative',
              }}>
                {a.hot && <span style={{ position: 'absolute', top: 4, right: 6, width: 6, height: 6, borderRadius: 999, background: OH.red }}/>}
                <span style={{ fontSize: 22 }}>{a.e}</span>
                <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 11, color: OH.fg }}>{a.l}</span>
              </div>
            ))}
          </div>
        </OhGlass>

        {/* Recent activity */}
        <div style={{ padding: '0 4px' }}>
          <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 15, color: OH.fg }}>最近活动</span>
        </div>
        <OhGlass padding={0}>
          {[
            { e: '🚶', l: '晨间散步', sub: '1.2 km · 22 分钟', r: '+8 🥥', t: '2h ago', c: OH.primary },
            { e: '🍽️', l: '早餐', sub: '180 g 干粮', r: '+3 🥥', t: '5h ago', c: OH.orange },
            { e: '💧', l: '加水', sub: '换水 · 200 ml', r: '+2 🥥', t: '5h ago', c: OH.teal },
          ].map((r, i, arr) => (
            <div key={i} style={{
              display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px',
              borderBottom: i < arr.length - 1 ? '1px solid rgba(255,255,255,0.06)' : 'none',
            }}>
              <div style={{ width: 40, height: 40, borderRadius: 14, background: `${r.c}22`, border: `1px solid ${r.c}44`, display: 'grid', placeItems: 'center', fontSize: 18 }}>{r.e}</div>
              <div style={{ flex: 1 }}>
                <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 800, fontSize: 14, color: OH.fg }}>{r.l}</div>
                <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 12, color: OH.fgSec, marginTop: 2 }}>{r.sub}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 13, color: OH.primary }}>{r.r}</div>
                <div style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, color: OH.fgTer, marginTop: 2 }}>{r.t}</div>
              </div>
            </div>
          ))}
        </OhGlass>
      </div>
    </OhIslandBg>
  );
}

window.OhanaPetDetailScreen = OhanaPetDetailScreen;
