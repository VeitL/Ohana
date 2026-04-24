// Ohana UI primitives — dark glass cards, pills, stat cells
// Used by the screen components. Globals: window.React

const OH = {
  primary: '#C8FF00',
  limeBright: '#E0FF00',
  ink: '#1A1A2E',
  yellow: '#FFF44F',
  orange: '#FF8C42',
  teal: '#00D4AA',
  red: '#FF4757',
  navyTop: '#2D4ECC',
  navyMid: '#1A2E8A',
  navyBot: '#0C1640',
  fg: '#FFFFFF',
  fgSec: 'rgba(255,255,255,0.70)',
  fgTer: 'rgba(255,255,255,0.45)',
};

// Glass card recipe from UltimateGlassCard in the Swift source
const glassBg = {
  background: 'linear-gradient(135deg, rgba(255,255,255,0.22), rgba(255,255,255,0.04) 50%, rgba(255,255,255,0.12))',
  backdropFilter: 'blur(24px) saturate(140%)',
  WebkitBackdropFilter: 'blur(24px) saturate(140%)',
  border: '1px solid rgba(255,255,255,0.22)',
  borderRadius: 24,
  boxShadow: '0 4px 12px rgba(0,0,0,0.18)',
};

function OhGlass({ children, style, padding = 16 }) {
  return <div style={{ ...glassBg, padding, ...style }}>{children}</div>;
}

// Floating blob background for phone content area
function OhIslandBg({ children }) {
  return (
    <div style={{
      position: 'relative', width: '100%', minHeight: '100%',
      background: `linear-gradient(180deg, ${OH.navyTop} 0%, ${OH.navyMid} 40%, ${OH.navyBot} 100%)`,
      color: OH.fg, overflow: 'hidden', isolation: 'isolate',
    }}>
      {/* floating blobs */}
      <div style={{ position: 'absolute', width: 260, height: 260, borderRadius: 999, top: -80, left: -60, background: OH.primary, opacity: 0.25, filter: 'blur(80px)', zIndex: 0 }}/>
      <div style={{ position: 'absolute', width: 300, height: 300, borderRadius: 999, top: 200, right: -120, background: '#5B6AFF', opacity: 0.45, filter: 'blur(90px)', zIndex: 0 }}/>
      <div style={{ position: 'absolute', width: 240, height: 240, borderRadius: 999, bottom: 120, left: -60, background: '#A855F7', opacity: 0.35, filter: 'blur(90px)', zIndex: 0 }}/>
      <div style={{ position: 'relative', zIndex: 1 }}>{children}</div>
    </div>
  );
}

function OhPill({ children, color = OH.primary, ink = OH.ink, style }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '6px 12px', borderRadius: 999,
      background: color, color: ink,
      fontFamily: 'Nunito, -apple-system, system-ui, sans-serif',
      fontWeight: 800, fontSize: 13, letterSpacing: -0.1,
      ...style,
    }}>{children}</div>
  );
}

function OhGlassPill({ children, style }) {
  return (
    <div style={{
      display: 'inline-flex', alignItems: 'center', gap: 6,
      padding: '6px 12px', borderRadius: 999,
      background: 'rgba(255,255,255,0.12)',
      border: '1px solid rgba(255,255,255,0.18)',
      backdropFilter: 'blur(18px)', WebkitBackdropFilter: 'blur(18px)',
      color: OH.fg,
      fontFamily: 'Nunito, -apple-system, system-ui, sans-serif',
      fontWeight: 700, fontSize: 12,
      ...style,
    }}>{children}</div>
  );
}

function OhBento({ label, value, unit, sub, accent = OH.primary, icon }) {
  return (
    <div style={{
      background: 'rgba(255,255,255,0.08)',
      border: '1px solid rgba(255,255,255,0.10)',
      borderRadius: 14, padding: 14,
      display: 'flex', flexDirection: 'column', gap: 6,
      minHeight: 92,
    }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
        <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, fontWeight: 600, color: OH.fgTer, letterSpacing: 0.3, textTransform: 'uppercase' }}>{label}</span>
        {icon}
      </div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 4 }}>
        <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 900, fontSize: 28, color: accent, letterSpacing: -1, lineHeight: 1 }}>{value}</span>
        {unit && <span style={{ fontFamily: 'Nunito, sans-serif', fontWeight: 700, fontSize: 12, color: OH.fgSec }}>{unit}</span>}
      </div>
      {sub && <span style={{ fontFamily: 'Inter, sans-serif', fontSize: 11, color: OH.fgSec }}>{sub}</span>}
    </div>
  );
}

// Tiny SF-Symbol-like icons rendered as inline SVGs
function OhIcon({ name, size = 16, color = 'currentColor' }) {
  const p = { width: size, height: size, viewBox: '0 0 24 24', fill: 'none', stroke: color, strokeWidth: 2, strokeLinecap: 'round', strokeLinejoin: 'round' };
  switch (name) {
    case 'house': return <svg {...p}><path d="M3 10l9-7 9 7v10a2 2 0 0 1-2 2h-4v-7h-6v7H5a2 2 0 0 1-2-2z"/></svg>;
    case 'cal':   return <svg {...p}><rect x="3" y="4" width="18" height="18" rx="3"/><path d="M16 2v4M8 2v4M3 10h18"/></svg>;
    case 'heart': return <svg {...p}><path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78L12 21.23l8.84-8.84a5.5 5.5 0 0 0 0-7.78z"/></svg>;
    case 'gear':  return <svg {...p}><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1a2 2 0 1 1-2.8-2.8l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1A1.7 1.7 0 0 0 4.6 9a1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z"/></svg>;
    case 'paw':   return <svg {...p}><circle cx="6" cy="10" r="2"/><circle cx="10" cy="5" r="2"/><circle cx="14" cy="5" r="2"/><circle cx="18" cy="10" r="2"/><path d="M8 14c0-3 2-5 4-5s4 2 4 5c0 2-1.5 3-4 3s-4-1-4-3z"/></svg>;
    case 'walk':  return <svg {...p}><circle cx="13" cy="4" r="2"/><path d="M7 22l3-6 3-3-2-4 4 3 3 2M10 13l-3-2"/></svg>;
    case 'drop':  return <svg {...p}><path d="M12 2s6 7 6 12a6 6 0 0 1-12 0c0-5 6-12 6-12z"/></svg>;
    case 'food':  return <svg {...p}><path d="M4 5v6a2 2 0 0 0 2 2v9M7 5v6M10 5v6M18 22V7c0-1.5-1-3-3-3v18z"/></svg>;
    case 'bolt':  return <svg {...p}><path d="M13 2 3 14h7l-1 8 10-12h-7l1-8z"/></svg>;
    case 'flame': return <svg {...p}><path d="M8.5 14.5A2.5 2.5 0 0 0 11 17c2.5 0 4-2 4-4 0-1.5-1-2.5-1-4 0-1.5 1-3 1-3-2 0-4 1-5 3-1-1-2-3-2-5 0 0-4 4-4 8a7 7 0 0 0 14 0c0-2-1-4-2-5 0 1-1 3-3 3"/></svg>;
    case 'plus':  return <svg {...p}><path d="M12 5v14M5 12h14"/></svg>;
    case 'chev':  return <svg {...p}><path d="M9 6l6 6-6 6"/></svg>;
    case 'bell':  return <svg {...p}><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9M13.7 21a2 2 0 0 1-3.4 0"/></svg>;
    case 'star':  return <svg {...p}><polygon points="12 2 15.1 8.3 22 9.3 17 14.1 18.2 21 12 17.8 5.8 21 7 14.1 2 9.3 8.9 8.3 12 2"/></svg>;
    case 'leaf':  return <svg {...p}><path d="M11 20A7 7 0 0 1 4 13c0-5 5-10 14-10 0 9-5 14-10 14-2 0-4-1-4-3"/><path d="M2 22c2-3 5-6 10-8"/></svg>;
    case 'pill':  return <svg {...p}><rect x="2" y="8" width="20" height="8" rx="4" transform="rotate(-30 12 12)"/><path d="M8.5 15.5l7-7" transform="rotate(-30 12 12)"/></svg>;
    case 'tree':  return <svg {...p}><path d="M12 2l5 7h-3l4 6h-4l3 5H7l3-5H6l4-6H7l5-7z"/></svg>;
    case 'shop':  return <svg {...p}><path d="M3 9h18l-2 11H5L3 9z"/><path d="M8 9V6a4 4 0 0 1 8 0v3"/></svg>;
    case 'map':   return <svg {...p}><polygon points="9 2 2 6 2 22 9 18 15 22 22 18 22 2 15 6 9 2"/><line x1="9" y1="2" x2="9" y2="18"/><line x1="15" y1="6" x2="15" y2="22"/></svg>;
    case 'play':  return <svg {...p}><polygon points="7 4 19 12 7 20 7 4" fill={color}/></svg>;
    default: return null;
  }
}

Object.assign(window, { OH, glassBg, OhGlass, OhIslandBg, OhPill, OhGlassPill, OhBento, OhIcon });
