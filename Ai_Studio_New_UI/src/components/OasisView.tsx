import React, { useState, useEffect, useRef } from 'react';
import { motion, AnimatePresence, useAnimation } from 'framer-motion';
import { 
  Store, 
  Trophy, 
  Gift, 
  ClipboardList, 
  Calendar as CalendarIcon,
  CheckCircle2,
  Sparkles,
  Zap,
  X,
  Star
} from 'lucide-react';

const LEVEL_THRESHOLDS = [0, 50, 150, 300, 500, 800, 1200, 1800, 2600, 3600];

export default function OasisView() {
  const [coconuts, setCoconuts] = useState(1250);
  const [energy, setEnergy] = useState(340);
  const [canHarvest, setCanHarvest] = useState(true);
  const [showTasks, setShowTasks] = useState(true);
  const [particles, setParticles] = useState<{id: number, x: number, y: number}[]>([]);
  const [levelUpBurst, setLevelUpBurst] = useState(false);
  const prevLevelRef = useRef(1);
  const treeControls = useAnimation();

  // Calculate level
  let level = 1;
  let nextThreshold = LEVEL_THRESHOLDS[1];
  let prevThreshold = LEVEL_THRESHOLDS[0];
  
  for (let i = 0; i < LEVEL_THRESHOLDS.length; i++) {
    if (energy >= LEVEL_THRESHOLDS[i]) {
      level = i + 1;
      prevThreshold = LEVEL_THRESHOLDS[i];
      nextThreshold = LEVEL_THRESHOLDS[i + 1] || LEVEL_THRESHOLDS[i];
    }
  }

  const progress = level === 10 ? 100 : ((energy - prevThreshold) / (nextThreshold - prevThreshold)) * 100;

  useEffect(() => {
    if (level > prevLevelRef.current) {
      setLevelUpBurst(true);
      treeControls.start({
        scale: [1, 1.3, 0.9, 1.1, 1],
        rotate: [0, -10, 10, -5, 0],
        transition: { duration: 0.8, type: "spring", bounce: 0.6 }
      });
      setTimeout(() => setLevelUpBurst(false), 2000);
    }
    prevLevelRef.current = level;
  }, [level, treeControls]);

  const handleHarvest = () => {
    if (!canHarvest) return;
    setCoconuts(prev => prev + 15);
    setCanHarvest(false);
  };

  const handleInjectEnergy = (e: React.MouseEvent<HTMLButtonElement>) => {
    if (coconuts >= 10) {
      // Spawn particle
      const rect = e.currentTarget.getBoundingClientRect();
      const newParticle = {
        id: Date.now(),
        x: rect.left + rect.width / 2,
        y: rect.top
      };
      setParticles(prev => [...prev, newParticle]);

      setCoconuts(prev => prev - 10);
      setEnergy(prev => prev + 20);

      // Remove particle after animation
      setTimeout(() => {
        setParticles(prev => prev.filter(p => p.id !== newParticle.id));
      }, 1000);
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="w-full h-full flex flex-col relative"
    >
      {/* Particles Layer */}
      <AnimatePresence>
        {particles.map(p => (
          <motion.div
            key={p.id}
            initial={{ opacity: 1, x: p.x, y: p.y, scale: 0.5 }}
            animate={{ 
              x: window.innerWidth / 2 - 20, 
              y: 200, 
              scale: [0.5, 1.5, 0],
              rotate: 360 
            }}
            exit={{ opacity: 0 }}
            transition={{ duration: 0.8, ease: "easeInOut" }}
            className="fixed z-[100] text-3xl drop-shadow-lg pointer-events-none"
          >
            🥥
          </motion.div>
        ))}
      </AnimatePresence>

      {/* Header */}
      <div className="px-6 pt-12 pb-4 flex justify-between items-center sticky top-0 bg-[#F5F5F7]/80 backdrop-blur-md z-50">
        <h1 className="text-3xl font-bold tracking-tight text-[#1C1C1E]">Oasis</h1>
        <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-full shadow-sm border-2 border-[#FF5A00]/20">
          <span className="text-xl drop-shadow-sm">🥥</span>
          <motion.span 
            key={coconuts}
            initial={{ scale: 1.5, color: '#FF5A00' }}
            animate={{ scale: 1, color: '#1C1C1E' }}
            transition={{ type: "spring", stiffness: 300, damping: 15 }}
            className="font-black text-xl tracking-tight"
            style={{ WebkitTextStroke: '1px rgba(0,0,0,0.1)' }}
          >
            {coconuts}
          </motion.span>
        </div>
      </div>

      {/* Tree of Life Section */}
      <div className="px-6 mb-8">
        <div className="bg-white rounded-[32px] p-8 shadow-sm relative overflow-hidden flex flex-col items-center justify-center min-h-[320px]">
          {/* Breathing Halo & Level Up Burst */}
          <motion.div 
            animate={{ 
              scale: levelUpBurst ? [1, 2, 1.5] : [1, 1.1, 1],
              opacity: levelUpBurst ? [0.8, 1, 0] : [0.3, 0.5, 0.3]
            }}
            transition={{ 
              duration: levelUpBurst ? 1 : 4, 
              repeat: levelUpBurst ? 0 : Infinity,
              ease: "easeInOut"
            }}
            className="absolute w-64 h-64 rounded-full blur-3xl"
            style={{
              background: levelUpBurst 
                ? 'radial-gradient(circle, #FFD700 0%, transparent 70%)' 
                : `radial-gradient(circle, ${level < 4 ? '#8BC34A' : level < 8 ? '#4CAF50' : '#009688'} 0%, transparent 70%)`
            }}
          />

          {/* Confetti (Level Up) */}
          <AnimatePresence>
            {levelUpBurst && (
              <motion.div className="absolute inset-0 pointer-events-none flex items-center justify-center">
                {Array.from({ length: 12 }).map((_, i) => (
                  <motion.div
                    key={i}
                    initial={{ opacity: 1, scale: 0, x: 0, y: 0 }}
                    animate={{ 
                      opacity: 0, 
                      scale: Math.random() * 1.5 + 0.5,
                      x: (Math.random() - 0.5) * 300,
                      y: (Math.random() - 0.5) * 300,
                      rotate: Math.random() * 360
                    }}
                    transition={{ duration: 1, ease: "easeOut" }}
                    className="absolute text-2xl"
                  >
                    <Star fill="#FFD700" color="#FFD700" />
                  </motion.div>
                ))}
              </motion.div>
            )}
          </AnimatePresence>

          {/* Tree Visual */}
          <motion.div 
            animate={treeControls}
            whileTap={{ scale: 0.95 }}
            className="relative z-10 text-9xl cursor-pointer drop-shadow-2xl"
          >
            {level < 3 ? '🌱' : level < 6 ? '🌿' : level < 9 ? '🌳' : '✨🌳✨'}
            
            {/* Harvest Bubble */}
            <AnimatePresence>
              {canHarvest && (
                <motion.div 
                  initial={{ opacity: 0, y: 10 }}
                  animate={{ opacity: 1, y: 0 }}
                  exit={{ opacity: 0, y: -20 }}
                  onClick={(e) => {
                    e.stopPropagation();
                    handleHarvest();
                  }}
                  className="absolute -bottom-4 left-1/2 -translate-x-1/2 bg-white px-4 py-2 rounded-full shadow-lg flex items-center gap-2 whitespace-nowrap"
                >
                  <span className="text-sm font-bold text-[#FF5A00]">Harvest +15 🥥</span>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>

          {/* Level & Energy Bar */}
          <div className="absolute bottom-6 left-6 right-6 z-10">
            <div className="flex justify-between items-end mb-2">
              <div>
                <p className="text-xs font-bold text-[#8E8E93] uppercase tracking-wider">Tree of Life</p>
                <p className="text-lg font-black text-[#1C1C1E]">Lv.{level}</p>
              </div>
              <button 
                onClick={handleInjectEnergy}
                className="bg-[#FF5A00] text-white text-xs font-bold px-3 py-1.5 rounded-full flex items-center gap-1 shadow-sm hover:bg-[#E04D00] transition-colors"
              >
                <Zap size={12} fill="currentColor" /> Inject (-10🥥)
              </button>
            </div>
            <div className="h-3 w-full bg-[#F0F0F0] rounded-full overflow-hidden">
              <motion.div 
                className="h-full bg-gradient-to-r from-[#8BC34A] to-[#4CAF50] rounded-full"
                initial={{ width: 0 }}
                animate={{ width: `${progress}%` }}
                transition={{ duration: 0.5 }}
              />
            </div>
            <p className="text-right text-[10px] text-[#8E8E93] mt-1 font-mono">
              {energy} / {level === 10 ? 'MAX' : nextThreshold}
            </p>
          </div>
        </div>
      </div>

      {/* Bento Grid */}
      <div className="px-6 grid grid-cols-2 gap-4 mb-8">
        <motion.div whileTap={{ scale: 0.95 }} className="bg-white p-5 rounded-[24px] shadow-sm flex flex-col items-center justify-center gap-3 aspect-square cursor-pointer">
          <div className="w-12 h-12 rounded-full bg-[#FFF0E5] text-[#FF5A00] flex items-center justify-center">
            <Store size={24} />
          </div>
          <div className="text-center">
            <h3 className="font-bold text-[#1C1C1E]">Coconut Shop</h3>
            <p className="text-xs text-[#8E8E93]">Exchange items</p>
          </div>
        </motion.div>

        <motion.div whileTap={{ scale: 0.95 }} className="bg-white p-5 rounded-[24px] shadow-sm flex flex-col items-center justify-center gap-3 aspect-square cursor-pointer">
          <div className="w-12 h-12 rounded-full bg-[#F4F8E6] text-[#8BC34A] flex items-center justify-center">
            <Trophy size={24} />
          </div>
          <div className="text-center">
            <h3 className="font-bold text-[#1C1C1E]">Achievements</h3>
            <p className="text-xs text-[#8E8E93]">12 / 45 Unlocked</p>
          </div>
        </motion.div>

        <motion.div whileTap={{ scale: 0.95 }} className="bg-white p-5 rounded-[24px] shadow-sm flex flex-col items-center justify-center gap-3 aspect-square cursor-pointer">
          <div className="w-12 h-12 rounded-full bg-[#F0F4F8] text-[#4A90E2] flex items-center justify-center">
            <Gift size={24} />
          </div>
          <div className="text-center">
            <h3 className="font-bold text-[#1C1C1E]">Gacha</h3>
            <p className="text-xs text-[#8E8E93]">30🥥 / Draw</p>
          </div>
        </motion.div>

        <motion.div whileTap={{ scale: 0.95 }} className="bg-white p-5 rounded-[24px] shadow-sm flex flex-col items-center justify-center gap-3 aspect-square cursor-pointer">
          <div className="w-12 h-12 rounded-full bg-[#F2F2F7] text-[#5856D6] flex items-center justify-center">
            <ClipboardList size={24} />
          </div>
          <div className="text-center">
            <h3 className="font-bold text-[#1C1C1E]">Bounties</h3>
            <p className="text-xs text-[#8E8E93]">Family tasks</p>
          </div>
        </motion.div>
      </div>

      {/* Newbie Tasks */}
      <AnimatePresence>
        {showTasks && (
          <motion.div 
            initial={{ opacity: 0, height: 0 }}
            animate={{ opacity: 1, height: 'auto' }}
            exit={{ opacity: 0, height: 0 }}
            className="px-6 mb-8 overflow-hidden"
          >
            <div className="bg-gradient-to-br from-[#FF5A00] to-[#FF7A00] rounded-[24px] p-6 text-white shadow-md shadow-[#FF5A00]/20">
              <div className="flex justify-between items-start mb-4">
                <div>
                  <h3 className="text-lg font-bold flex items-center gap-2"><Sparkles size={18} /> Welcome Tasks</h3>
                  <p className="text-sm text-white/80">Complete to earn coconuts!</p>
                </div>
                <button onClick={() => setShowTasks(false)} className="bg-white/20 p-1.5 rounded-full backdrop-blur-sm">
                  <X size={16} />
                </button>
              </div>
              <div className="space-y-3">
                <div className="bg-white/10 backdrop-blur-sm rounded-xl p-3 flex justify-between items-center">
                  <span className="text-sm font-medium">First Check-in</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-[#FFD60A]">+10 🥥</span>
                    <CheckCircle2 size={18} className="text-[#34C759]" />
                  </div>
                </div>
                <div className="bg-white/10 backdrop-blur-sm rounded-xl p-3 flex justify-between items-center">
                  <span className="text-sm font-medium">Inject Energy Once</span>
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-bold text-[#FFD60A]">+20 🥥</span>
                    <button className="bg-white text-[#FF5A00] text-xs font-bold px-3 py-1 rounded-full">Go</button>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>

      {/* Calendar System */}
      <div className="px-6 mb-8">
        <div className="bg-white rounded-[32px] p-6 shadow-sm">
          <div className="flex justify-between items-center mb-6">
            <div>
              <h3 className="text-lg font-bold text-[#1C1C1E]">Check-in Calendar</h3>
              <p className="text-xs text-[#8E8E93]">March 2026</p>
            </div>
            <div className="w-10 h-10 rounded-full bg-[#F5F5F7] flex items-center justify-center text-[#1C1C1E]">
              <CalendarIcon size={20} />
            </div>
          </div>
          
          {/* Simple Calendar Grid Placeholder */}
          <div className="grid grid-cols-7 gap-2 text-center mb-4">
            {['S', 'M', 'T', 'W', 'T', 'F', 'S'].map(d => (
              <div key={d} className="text-xs font-bold text-[#8E8E93]">{d}</div>
            ))}
            {Array.from({ length: 31 }).map((_, i) => {
              const isCheckedIn = i < 15 && i % 2 === 0;
              const isToday = i === 16;
              return (
                <div 
                  key={i} 
                  className={`aspect-square rounded-full flex items-center justify-center text-sm font-medium ${
                    isCheckedIn ? 'bg-[#34C759]/10 text-[#34C759]' : 
                    isToday ? 'bg-[#FF5A00] text-white shadow-sm' : 
                    'text-[#1C1C1E]'
                  }`}
                >
                  {i + 1}
                </div>
              );
            })}
          </div>
          
          <div className="flex justify-between items-center pt-4 border-t border-gray-100">
            <p className="text-sm font-medium text-[#1C1C1E]">Make-up Packs: <span className="text-[#FF5A00] font-bold">2</span></p>
            <button className="text-xs font-bold text-[#4A90E2] bg-[#F0F4F8] px-3 py-1.5 rounded-full">Use Pack</button>
          </div>
        </div>
      </div>
    </motion.div>
  );
}
