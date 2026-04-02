import { motion, AnimatePresence } from "motion/react";
import { useState, useEffect } from "react";
import { X } from "lucide-react";
import { cards } from "../data";

// Ohana Design System Colors
const goLime = "#C8FF00";
const goDarkBlue = "#0D1B3E";
const arkInk = "#1A1A2E";

// Animated Number Component
function AnimatedNumber({ value }: { value: number }) {
  const [display, setDisplay] = useState(0);
  
  useEffect(() => {
    let startTime: number | null = null;
    const duration = 1500; // 1.5 seconds
    
    const animate = (time: number) => {
      if (!startTime) startTime = time;
      const progress = Math.min((time - startTime) / duration, 1);
      // easeOutQuart
      const easeOutQuart = 1 - Math.pow(1 - progress, 4);
      setDisplay(value * easeOutQuart);
      
      if (progress < 1) {
        requestAnimationFrame(animate);
      }
    };
    
    requestAnimationFrame(animate);
  }, [value]);
  
  return <>{display.toFixed(1)}</>;
}

// Animation Variants for Staggered Entry
const staggerContainer = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: {
      staggerChildren: 0.08,
      delayChildren: 0.1,
    },
  },
  exit: {
    opacity: 0,
    transition: {
      staggerChildren: 0.04,
      staggerDirection: -1,
    },
  },
};

const bentoItem = {
  hidden: { opacity: 0, y: 20 },
  visible: { 
    opacity: 1, 
    y: 0, 
    transition: { type: "spring", stiffness: 400, damping: 30 }
  },
  exit: { opacity: 0, y: -10, transition: { duration: 0.15 } }
};

export default function WalletStack() {
  const [activeId, setActiveId] = useState<string | null>(null);
  const [isHoveringStack, setIsHoveringStack] = useState(false);
  const [toggles, setToggles] = useState({ feeding: false, watering: true });
  const activeCard = cards.find((c) => c.id === activeId);

  // Lock body scroll when a card is expanded
  useEffect(() => {
    if (activeId) {
      document.body.style.overflow = "hidden";
    } else {
      document.body.style.overflow = "auto";
    }
    return () => {
      document.body.style.overflow = "auto";
    };
  }, [activeId]);

  return (
    <div className="w-full h-full flex justify-center overflow-y-auto p-4 sm:p-8 relative bg-surface-base">
      {/* Ambient Background */}
      <div className="fixed inset-0 overflow-hidden pointer-events-none z-0">
        <motion.div
          animate={{
            x: [0, 50, -50, 0],
            y: [0, -50, 50, 0],
          }}
          transition={{ duration: 15, repeat: Infinity, ease: "linear" }}
          className="absolute top-[-10%] left-[-10%] w-[50vw] h-[50vw] rounded-full bg-blue-900/20 blur-[100px]"
        />
        <motion.div
          animate={{
            x: [0, -60, 60, 0],
            y: [0, 60, -60, 0],
          }}
          transition={{ duration: 20, repeat: Infinity, ease: "linear" }}
          className="absolute bottom-[-10%] right-[-10%] w-[60vw] h-[60vw] rounded-full bg-orange-900/10 blur-[120px]"
        />
      </div>

      {/* Base Wallet Stack */}
      <div 
        className="relative w-full max-w-[380px] h-[800px] mt-4 sm:mt-10 z-10"
        onMouseEnter={() => !activeId && setIsHoveringStack(true)}
        onMouseLeave={() => setIsHoveringStack(false)}
      >
        {cards.map((card, index) => {
          const isActive = activeId === card.id;
          // Fan out slightly when hovering the stack
          const yOffset = isHoveringStack && !activeId ? index * 85 : index * 70;

          return (
        <motion.div
          key={card.id}
          layoutId={`wallet-card-${card.id}`}
          className="absolute top-0 left-0 w-full h-[240px] cursor-pointer will-change-transform"
          style={{ 
            zIndex: index,
            transformOrigin: "top center"
          }}
          initial={false}
          animate={{ 
            y: yOffset,
            scale: isActive ? 1 : (isHoveringStack && !activeId ? 1.02 : 1),
            opacity: isActive ? 0 : 1, // Hide original when expanded
            rotateX: isHoveringStack && !activeId ? index * -2 : 0 // Slight 3D fan effect
          }}
          transition={{ 
            type: "spring", 
            stiffness: 400, 
            damping: 35, 
            mass: 0.8 
          }}
          whileHover={!isActive && !activeId ? { y: yOffset - 8, scale: 1.03, transition: { duration: 0.2 } } : {}}
          whileTap={{ scale: 0.97, y: yOffset + 2 }}
          onClick={() => {
            setIsHoveringStack(false);
            setActiveId(card.id);
          }}
        >
          {/* Peeking Pet (Behind the card) - Animated */}
          <motion.div 
            className="absolute -top-11 left-1/2 -translate-x-1/2 z-0 text-[65px] drop-shadow-lg pointer-events-none select-none"
            animate={{ y: [0, -6, 0], rotate: [0, 4, -4, 0] }}
            transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: index * 0.4 }}
          >
            {["🐱", "🐶", "🦊", "🐼"][index % 4]}
          </motion.div>

          {/* Paws (In front of the card) - Animated */}
          <div className="absolute -top-2 left-1/2 -translate-x-1/2 w-[60px] flex justify-between z-20 pointer-events-none">
            <motion.div 
              className="w-4 h-6 bg-[#f5f5f5] rounded-full shadow-[0_2px_4px_rgba(0,0,0,0.2)] border border-black/5 origin-bottom"
              animate={{ rotate: [-12, -18, -12] }}
              transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: index * 0.4 }}
            />
            <motion.div 
              className="w-4 h-6 bg-[#f5f5f5] rounded-full shadow-[0_2px_4px_rgba(0,0,0,0.2)] border border-black/5 origin-bottom"
              animate={{ rotate: [12, 18, 12] }}
              transition={{ duration: 5, repeat: Infinity, ease: "easeInOut", delay: index * 0.4 }}
            />
          </div>

          {/* Card Main Content (With overflow hidden to mask the pet's body) */}
          <div 
            className="absolute inset-0 rounded-[24px] overflow-hidden shadow-[0_8px_20px_rgba(0,0,0,0.35)] border border-border-subtle z-10"
            style={{ background: `linear-gradient(135deg, ${goDarkBlue} 0%, #1A2A6C 100%)` }}
          >
            <img 
              src={card.image} 
              alt={card.title} 
              className="absolute inset-0 w-full h-full object-cover opacity-50" 
              referrerPolicy="no-referrer"
            />
            <div className="absolute inset-0 bg-gradient-to-b from-black/40 via-transparent to-[#060E24]/90" />
            
            <div className="absolute inset-0 p-6 flex flex-col justify-between text-content-base">
              <div className="flex justify-between items-start">
                <div>
                  <h2 className="text-[24px] font-bold tracking-tight shadow-black/50 drop-shadow-md" style={{ fontFamily: 'SF Pro Rounded, system-ui, sans-serif' }}>{card.title}</h2>
                  <div className="mt-2 inline-flex items-center px-3 py-1 rounded-full bg-glass-bg backdrop-blur-md border border-border-subtle">
                    <span className="text-content-muted text-xs font-semibold tracking-wider uppercase">{card.subtitle}</span>
                  </div>
                </div>
                
                {/* Ohana style badge */}
                {index === 0 && (
                  <div className="w-10 h-10 rounded-full flex items-center justify-center shadow-lg" style={{ backgroundColor: goLime }}>
                    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke={arkInk} strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
                    </svg>
                  </div>
                )}
              </div>
              
              <div className="flex justify-between items-end">
                <div className="font-mono text-lg tracking-widest opacity-90 drop-shadow-md text-content-muted">
                  •••• {card.id.padStart(4, '0')}
                </div>
              </div>
            </div>
          </div>
        </motion.div>
          );
        })}
      </div>

      {/* Expanded App Store Style View */}
      <AnimatePresence>
        {activeId && activeCard && (
          <motion.div 
            className="fixed inset-0 z-50 flex justify-center items-end sm:items-center sm:p-8 perspective-[2000px]"
            initial={{ pointerEvents: "none" }}
            animate={{ pointerEvents: "auto" }}
            exit={{ pointerEvents: "none" }}
          >
            {/* Backdrop Blur - OPTIMIZED: Animate opacity only, keep blur static in CSS */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.3, ease: "easeInOut" }}
              className="absolute inset-0 bg-glass-bg backdrop-blur-xl will-change-opacity"
              onClick={() => setActiveId(null)}
            />

            {/* Ambient Breathing Glow (Ohana Blob Style) - OPTIMIZED: Removed heavy scale animation */}
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: [0, 0.4, 0.2, 0.4] }}
              exit={{ opacity: 0 }}
              transition={{ duration: 8, repeat: Infinity, repeatType: "reverse", ease: "easeInOut" }}
              className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[300px] h-[300px] rounded-full blur-[80px] pointer-events-none will-change-opacity"
              style={{ backgroundColor: '#4338FF' }}
            />
            
            <motion.div
              layoutId={`wallet-card-${activeCard.id}`}
              className="relative w-full sm:max-w-[420px] h-[calc(100%-120px)] sm:h-[85vh] z-10 flex flex-col will-change-transform"
              transition={{ type: "spring", stiffness: 350, damping: 32, mass: 0.8 }}
            >
              {/* Peeking Pet (Expanded) - Peeks out then hides behind card */}
              <motion.div 
                className="absolute -top-14 left-1/2 -translate-x-1/2 z-0 text-[85px] drop-shadow-2xl pointer-events-none select-none"
                initial={{ y: 80, opacity: 0 }}
                animate={{ 
                  y: [80, -20, -20, 150], 
                  opacity: [0, 1, 1, 0] 
                }}
                transition={{ 
                  duration: 2.5, 
                  times: [0, 0.15, 0.85, 1], 
                  ease: "easeInOut",
                  delay: 0.5 // Wait for the card to finish expanding before popping up
                }}
              >
                {["🐱", "🐶", "🦊", "🐼"][cards.findIndex(c => c.id === activeCard.id) % 4]}
              </motion.div>

              {/* Paws (Expanded) - Peeks out then hides with the pet */}
              <motion.div 
                className="absolute -top-2 left-1/2 -translate-x-1/2 w-[76px] flex justify-between z-20 pointer-events-none"
                initial={{ y: 40, opacity: 0 }}
                animate={{ 
                  y: [40, 0, 0, 100], 
                  opacity: [0, 1, 1, 0] 
                }}
                transition={{ 
                  duration: 2.5, 
                  times: [0, 0.15, 0.85, 1], 
                  ease: "easeInOut",
                  delay: 0.5 
                }}
              >
                <div className="w-5 h-7 bg-[#f5f5f5] rounded-full shadow-[0_2px_4px_rgba(0,0,0,0.2)] border border-black/5 transform -rotate-12 origin-bottom" />
                <div className="w-5 h-7 bg-[#f5f5f5] rounded-full shadow-[0_2px_4px_rgba(0,0,0,0.2)] border border-black/5 transform rotate-12 origin-bottom" />
              </motion.div>

              {/* Scrollable Inner Container */}
              <div 
                className="relative w-full h-full rounded-t-[32px] sm:rounded-[32px] overflow-y-auto overflow-x-hidden shadow-[0_32px_80px_rgba(0,0,0,0.5)] border-t border-border-subtle sm:border z-10 flex flex-col no-scrollbar bg-surface-base"
              >
                {/* Swipe Down Indicator */}
                <div className="w-full flex justify-center pt-3 pb-1 absolute top-0 left-0 z-30 pointer-events-none">
                  <div className="w-12 h-1.5 bg-glass-bg rounded-full" />
                </div>

                {/* Header with Back Button */}
                <div className="sticky top-0 z-20 px-6 pt-8 pb-2 flex items-center justify-between bg-surface-base/80 backdrop-blur-md">
                  <button onClick={() => setActiveId(null)} className="w-10 h-10 flex items-center justify-center text-content-base transition-transform active:scale-90">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m15 18-6-6 6-6"/></svg>
                  </button>
                  <div className="flex gap-2">
                    <button className="w-10 h-10 bg-glass-bg rounded-full flex items-center justify-center text-content-muted hover:bg-glass-hover transition-colors">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
                    </button>
                    <button className="w-10 h-10 bg-glass-bg rounded-full flex items-center justify-center text-content-muted hover:bg-glass-hover transition-colors">
                      <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                    </button>
                  </div>
                </div>

                {/* Expanded Content - Clean Minimal Layout (Dark Mode) */}
                <motion.div
                  variants={staggerContainer}
                  initial="hidden"
                  animate="visible"
                  exit="exit"
                  className="px-6 pt-2 leading-relaxed space-y-4 pb-24 flex-1"
                >
                  {/* Title Section */}
                  <div className="flex flex-col items-center mb-6">
                    <h1 className="text-3xl font-medium text-content-base">{activeCard.title}</h1>
                    <div className="flex gap-2 mt-4">
                      <div className="w-12 h-12 rounded-full border border-border-subtle flex items-center justify-center text-content-muted">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                      </div>
                      <div className="w-12 h-12 rounded-full border border-border-subtle bg-glass-bg flex items-center justify-center text-content-muted">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/></svg>
                      </div>
                      <div className="w-12 h-12 rounded-full border border-border-subtle bg-glass-bg flex items-center justify-center text-content-muted">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/></svg>
                      </div>
                      <div className="w-12 h-12 rounded-full border border-border-subtle bg-glass-bg flex items-center justify-center text-content-muted">
                        <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><circle cx="12" cy="12" r="10"/><path d="M12 8v8M8 12h8"/></svg>
                      </div>
                    </div>
                    <div className="mt-4 border border-border-subtle rounded-full px-4 py-1.5 text-sm text-content-muted font-medium">
                      Temperature
                    </div>
                  </div>

                  {/* Row 1: Weight & Activity */}
                  <div className="grid grid-cols-2 gap-4">
                    {/* Weight Card (Shrunk) */}
                    <motion.div 
                      variants={bentoItem} 
                      whileHover={{ y: -4, transition: { duration: 0.2 } }}
                      className="bg-surface-1 rounded-3xl p-5 shadow-[0_4px_20px_rgba(0,0,0,0.2)] relative overflow-hidden flex flex-col justify-between"
                    >
                      <div className="flex justify-between items-start mb-2">
                        <div className="text-sm font-medium text-content-base">Weight</div>
                        <div className="w-6 h-6 rounded-full bg-glass-bg flex items-center justify-center text-content-muted">
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M7 17l9.2-9.2M17 17V7H7"/></svg>
                        </div>
                      </div>
                      
                      <div className="flex flex-col items-center justify-center py-2 relative">
                        {/* Mini Arc Mockup */}
                        <svg className="absolute w-full h-full top-0 left-0" viewBox="0 0 100 50">
                          <path d="M 10 45 A 40 40 0 0 1 90 45" fill="none" stroke="#333336" strokeWidth="3" strokeLinecap="round" strokeDasharray="2 4"/>
                          <motion.path 
                            d="M 10 45 A 40 40 0 0 1 50 5" 
                            fill="none" 
                            stroke="#FF5A00" 
                            strokeWidth="3" 
                            strokeLinecap="round"
                            initial={{ pathLength: 0 }}
                            animate={{ pathLength: 1 }}
                            transition={{ duration: 1.5, ease: "easeOut", delay: 0.3 }}
                          />
                          <motion.circle 
                            cx="50" cy="5" r="3" fill="#FF5A00" 
                            initial={{ scale: 0, opacity: 0 }}
                            animate={{ scale: 1, opacity: 1 }}
                            transition={{ delay: 1.8, duration: 0.3, type: "spring" }}
                          />
                        </svg>
                        
                        <motion.div 
                          initial={{ opacity: 0, y: 5 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: 0.8, duration: 0.5 }}
                          className="text-3xl font-medium text-content-base mt-2 flex items-baseline z-10"
                        >
                          <AnimatedNumber value={9.0} /><span className="text-sm text-slate-500 ml-1">kg</span>
                        </motion.div>
                        
                        <div className="w-full flex justify-between px-2 mt-1 z-10">
                          <div className="text-[10px] text-slate-500 font-medium">8.0</div>
                          <div className="text-[10px] text-slate-500 font-medium">10.0</div>
                        </div>
                      </div>
                      <div className="mt-2 flex items-center gap-1">
                        <span className="bg-white/10 text-[#FF5A00] text-[10px] font-bold px-2 py-0.5 rounded-full">Normal</span>
                      </div>
                    </motion.div>

                    {/* Activity Card (Placeholder for now, can be walking or other) */}
                    <motion.div 
                      variants={bentoItem} 
                      whileHover={{ y: -4, transition: { duration: 0.2 } }}
                      className="bg-surface-1 rounded-3xl p-5 shadow-[0_4px_20px_rgba(0,0,0,0.2)] relative overflow-hidden flex flex-col justify-between"
                    >
                      <div className="flex justify-between items-start mb-2">
                        <div className="text-sm font-medium text-content-base">Activity</div>
                        <div className="w-6 h-6 rounded-full bg-glass-bg flex items-center justify-center text-[#C8FF00]">
                          <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/></svg>
                        </div>
                      </div>
                      <div className="flex-1 flex flex-col justify-center">
                        <div className="text-2xl font-medium text-content-base">45<span className="text-sm text-slate-500 ml-1">min</span></div>
                        <div className="text-xs text-slate-500 mt-1">Daily Goal: 60m</div>
                        <div className="w-full h-1.5 bg-glass-bg rounded-full mt-3 overflow-hidden">
                          <motion.div 
                            className="h-full bg-[#C8FF00]"
                            initial={{ width: 0 }}
                            animate={{ width: "75%" }}
                            transition={{ duration: 1, delay: 0.5 }}
                          />
                        </div>
                      </div>
                    </motion.div>
                  </div>

                  {/* Care & Diet Rows */}
                  <motion.div 
                    variants={bentoItem} 
                    whileHover={{ y: -4, transition: { duration: 0.2 } }}
                    className="bg-surface-1 rounded-[32px] p-4 shadow-[0_4px_20px_rgba(0,0,0,0.2)] space-y-2"
                  >
                    <motion.div 
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setToggles(prev => ({ ...prev, feeding: !prev.feeding }))}
                      className="flex items-center justify-between p-2 cursor-pointer rounded-2xl hover:bg-glass-hover transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <div className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors duration-300 ${toggles.feeding ? 'bg-[#FF5A00]/20 text-[#FF5A00]' : 'bg-glass-bg text-content-muted'}`}>
                          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                        </div>
                        <span className="font-medium text-content-base">Feeding</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-sm text-slate-500">{toggles.feeding ? 'On' : 'Off'}</span>
                        <div className={`w-12 h-7 rounded-full relative flex items-center px-1 transition-colors duration-300 ${toggles.feeding ? 'bg-[#FF5A00]' : 'bg-glass-bg'}`} style={{ justifyContent: toggles.feeding ? 'flex-end' : 'flex-start' }}>
                          <motion.div 
                            layout
                            className={`w-5 h-5 rounded-full shadow-sm ${toggles.feeding ? 'bg-white' : 'bg-glass-bg'}`}
                          ></motion.div>
                        </div>
                      </div>
                    </motion.div>

                    <motion.div 
                      whileTap={{ scale: 0.98 }}
                      onClick={() => setToggles(prev => ({ ...prev, watering: !prev.watering }))}
                      className="flex items-center justify-between p-2 cursor-pointer rounded-2xl hover:bg-glass-hover transition-colors"
                    >
                      <div className="flex items-center gap-4">
                        <motion.div 
                          animate={toggles.watering ? { scale: [1, 1.1, 1] } : { scale: 1 }}
                          transition={{ duration: 2, repeat: Infinity, ease: "easeInOut" }}
                          className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors duration-300 ${toggles.watering ? 'bg-[#FF5A00]/20 text-[#FF5A00]' : 'bg-glass-bg text-content-muted'}`}
                        >
                          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5"><path d="M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>
                        </motion.div>
                        <span className="font-medium text-content-base">Watering</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-sm text-slate-500">{toggles.watering ? 'On' : 'Off'}</span>
                        <div className={`w-12 h-7 rounded-full relative flex items-center px-1 transition-colors duration-300 ${toggles.watering ? 'bg-[#FF5A00]' : 'bg-glass-bg'}`} style={{ justifyContent: toggles.watering ? 'flex-end' : 'flex-start' }}>
                          <motion.div 
                            layout
                            className={`w-5 h-5 rounded-full shadow-sm ${toggles.watering ? 'bg-white' : 'bg-glass-bg'}`}
                          ></motion.div>
                        </div>
                      </div>
                    </motion.div>
                  </motion.div>

                  {/* Bottom Row: Scenes & Add */}
                  <div className="flex gap-4">
                    <motion.div 
                      variants={bentoItem} 
                      whileHover={{ y: -4, transition: { duration: 0.2 } }}
                      className="flex-1 bg-surface-1 rounded-[32px] p-5 shadow-[0_4px_20px_rgba(0,0,0,0.2)] flex flex-col justify-between"
                    >
                      <div className="flex justify-between items-start">
                        <div className="w-10 h-10 rounded-full border border-border-subtle flex items-center justify-center text-content-muted">
                          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>
                        </div>
                        <motion.button 
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          className="w-8 h-8 rounded-full bg-glass-bg border border-border-subtle flex items-center justify-center text-content-base hover:bg-glass-hover transition-colors"
                        >
                          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M7 17l9.2-9.2M17 17V7H7"/></svg>
                        </motion.button>
                      </div>
                      <div className="mt-4">
                        <div className="font-medium text-content-base">12 records</div>
                        <div className="text-sm text-slate-500">in total</div>
                      </div>
                    </motion.div>

                    <motion.div 
                      variants={bentoItem} 
                      whileHover={{ y: -4, transition: { duration: 0.2 } }}
                      className="flex-[1.2] bg-surface-2 rounded-[32px] p-5 flex items-center justify-between"
                    >
                      <div className="flex flex-col h-full justify-between">
                        <div className="font-medium text-content-base text-lg leading-tight">Daily<br/>Scene</div>
                        <div className="w-10 h-6 bg-surface-1 rounded-full relative mt-4 shadow-sm">
                          <motion.div 
                            layout
                            className="w-4 h-4 bg-[#FF5A00] rounded-full absolute left-1 top-1"
                          ></motion.div>
                        </div>
                      </div>
                      <motion.button 
                        whileHover={{ scale: 1.05 }}
                        whileTap={{ scale: 0.95 }}
                        animate={{ 
                          boxShadow: [
                            "0px 0px 0px 0px rgba(255,90,0,0.4)", 
                            "0px 0px 0px 15px rgba(255,90,0,0)"
                          ] 
                        }}
                        transition={{ 
                          boxShadow: { repeat: Infinity, duration: 2 },
                          scale: { type: "spring", stiffness: 400, damping: 17 }
                        }}
                        className="w-16 h-16 rounded-full bg-[#FF5A00] text-content-base flex items-center justify-center text-3xl font-light shadow-lg shadow-orange-500/20"
                      >
                        +
                      </motion.button>
                    </motion.div>
                  </div>
                </motion.div>
              </div> {/* Close Scrollable Inner Container */}
            </motion.div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
