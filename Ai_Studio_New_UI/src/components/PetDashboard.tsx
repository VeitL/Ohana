// MARKER_XYZ_2026
import React, { useState, useEffect } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { PetAvatar } from './PetAvatars';
import OasisView from './OasisView';
import AddPetFlow from './AddPetFlow';
import FamilyOverview from './FamilyOverview';
import { 
  Settings, 
  Home, 
  Plus, 
  Bone, 
  Trash2, 
  Scale, 
  Wallet, 
  Footprints,
  ChevronRight,
  Bell,
  Calendar,
  PawPrint,
  Leaf,
  Check,
  X,
  CheckCircle2,
  Play,
  Pause,
  Square,
  Clock,
  MapPin,
  Droplets,
  Cloud,
  TreePine
} from 'lucide-react';

const CoconutIcon = ({ size = 24, className = "" }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className={className}>
    <circle cx="12" cy="12" r="10" />
    <circle cx="9" cy="10" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="15" cy="10" r="1.5" fill="currentColor" stroke="none" />
    <circle cx="12" cy="14" r="1.5" fill="currentColor" stroke="none" />
  </svg>
);
import { 
  AreaChart, 
  Area, 
  XAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer 
} from 'recharts';

// --- Mock Data ---
const PETS = [
  {
    id: '1',
    name: 'Luna',
    type: 'cat',
    breed: 'British Shorthair',
    color: 'from-[#FF7A00] to-[#FF5A00]',
    furColor: '#7C2D12',
    patternColor: '#431407',
    eyeColor: '#FEF08A',
    data: {
      feeding: '2h ago',
      water: '1h ago',
      litter: 'Needs cleaning',
      weight: '4.5 kg',
      weightChange: '↓ 0.2kg',
      weightChangeType: 'down',
      expenses: '$120',
      walkGoal: '30 mins'
    }
  },
  {
    id: '2',
    name: 'Max',
    type: 'dog',
    breed: 'Golden Retriever',
    color: 'from-[#7C3AED] to-[#4C1D95]',
    furColor: '#3B1F6E',
    patternColor: '#1E1040',
    eyeColor: '#C4B5FD',
    data: {
      feeding: '1h ago',
      water: '30m ago',
      litter: 'Clean',
      weight: '12.5 kg',
      weightChange: '↑ 0.5kg',
      weightChangeType: 'up',
      expenses: '$250',
      walkGoal: '60 mins'
    }
  },
  {
    id: '3',
    name: 'Mochi',
    type: 'rabbit',
    breed: 'Holland Lop',
    color: 'from-[#0891B2] to-[#0E7490]',
    furColor: '#164E63',
    patternColor: '#083344',
    eyeColor: '#67E8F9',
    data: {
      feeding: '4h ago',
      water: '2h ago',
      litter: 'Clean',
      weight: '2.1 kg',
      weightChange: '- 0.0kg',
      weightChangeType: 'neutral',
      expenses: '$60',
      walkGoal: '20 mins'
    }
  },
  {
    id: '4',
    name: 'Nori',
    type: 'hamster',
    breed: 'Syrian',
    color: 'from-[#D97706] to-[#B45309]',
    furColor: '#78350F',
    patternColor: '#451A03',
    eyeColor: '#FDE68A',
    data: {
      feeding: '3h ago',
      water: '1h ago',
      litter: 'Clean',
      weight: '0.14 kg',
      weightChange: '↑ 0.01kg',
      weightChangeType: 'up',
      expenses: '$30',
      walkGoal: '—'
    }
  },
  {
    id: '5',
    name: 'Kiwi',
    type: 'bird',
    breed: 'Budgerigar',
    color: 'from-[#059669] to-[#065F46]',
    furColor: '#064E3B',
    patternColor: '#022C22',
    eyeColor: '#6EE7B7',
    data: {
      feeding: '1h ago',
      water: '1h ago',
      litter: 'Clean',
      weight: '0.03 kg',
      weightChange: '- 0.0kg',
      weightChangeType: 'neutral',
      expenses: '$45',
      walkGoal: '—'
    }
  },
];

const GLOBAL_CHART_DATA = [
  { name: 'Mon', expenses: 12, activity: 45 },
  { name: 'Tue', expenses: 45, activity: 52 },
  { name: 'Wed', expenses: 0, activity: 38 },
  { name: 'Thu', expenses: 8, activity: 65 },
  { name: 'Fri', expenses: 25, activity: 48 },
  { name: 'Sat', expenses: 120, activity: 85 },
  { name: 'Sun', expenses: 15, activity: 70 },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.08 }
  },
  exit: {
    opacity: 0,
    transition: { staggerChildren: 0.04, staggerDirection: -1 }
  }
};

const feedingVariants = {
  hidden: { opacity: 0, y: -40, scale: 0.9 },
  visible: { opacity: 1, y: 0, scale: 1, transition: { type: "spring", stiffness: 400, damping: 20 } },
  exit: { opacity: 0, y: -20, scale: 0.9, transition: { duration: 0.15 } }
};

const waterVariants = {
  hidden: { opacity: 0, y: -40, scale: 0.9 },
  visible: { opacity: 1, y: 0, scale: 1, transition: { type: "spring", stiffness: 400, damping: 20 } },
  exit: { opacity: 0, y: -20, scale: 0.9, transition: { duration: 0.15 } }
};

const litterVariants = {
  hidden: { opacity: 0, x: -40, rotate: -10, scale: 0.9 },
  visible: { opacity: 1, x: 0, rotate: 0, scale: 1, transition: { type: "spring", stiffness: 350, damping: 20 } },
  exit: { opacity: 0, x: -20, rotate: -10, scale: 0.9, transition: { duration: 0.15 } }
};

const weightVariants = {
  hidden: { opacity: 0, scale: 0.8, y: 30 },
  visible: { opacity: 1, scale: 1, y: 0, transition: { type: "spring", stiffness: 300, damping: 25, mass: 1.2 } },
  exit: { opacity: 0, scale: 0.8, y: 20, transition: { duration: 0.15 } }
};

const expensesVariants = {
  hidden: { opacity: 0, rotateX: -45, y: 20, scale: 0.9 },
  visible: { opacity: 1, rotateX: 0, y: 0, scale: 1, transition: { type: "spring", stiffness: 300, damping: 20 } },
  exit: { opacity: 0, rotateX: 45, y: -20, scale: 0.9, transition: { duration: 0.15 } }
};

const walkVariants = {
  hidden: { opacity: 0, x: 40, scale: 0.9 },
  visible: { opacity: 1, x: 0, scale: 1, transition: { type: "spring", stiffness: 400, damping: 20 } },
  exit: { opacity: 0, x: 20, scale: 0.9, transition: { duration: 0.15 } }
};

const NAV_ITEMS = [
  { id: 'home', icon: Home, label: 'Home' },
  { id: 'calendar', icon: Calendar, label: 'Calendar' },
  { id: 'coconut', icon: CoconutIcon, label: 'Coconut', isSpecial: true },
  { id: 'pet', icon: PawPrint, label: 'Pet' },
  { id: 'plant', icon: Leaf, label: 'Plant' },
];

const Scenery = ({ isMoving }: { isMoving: boolean }) => {
  return (
    <div className="absolute inset-0 overflow-hidden rounded-t-[24px]">
      <style>{`
        @keyframes slideLeft {
          from { transform: translateX(0); }
          to { transform: translateX(-50%); }
        }
        .scenery-slide {
          animation: slideLeft 20s linear infinite;
        }
        .scenery-slide-fast {
          animation: slideLeft 10s linear infinite;
        }
        .paused {
          animation-play-state: paused;
        }
      `}</style>

      {/* Mountains Silhouette */}
      <div className={`absolute bottom-0 left-0 flex w-[200%] scenery-slide ${!isMoving ? 'paused' : ''} items-end opacity-20`}>
        <div className="w-1/2 flex items-end">
           <div className="w-32 h-24 bg-black" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
           <div className="w-48 h-32 bg-black -ml-16" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
           <div className="w-40 h-20 bg-black -ml-20" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
        </div>
        <div className="w-1/2 flex items-end">
           <div className="w-32 h-24 bg-black" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
           <div className="w-48 h-32 bg-black -ml-16" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
           <div className="w-40 h-20 bg-black -ml-20" style={{ clipPath: 'polygon(50% 0%, 0% 100%, 100% 100%)' }} />
        </div>
      </div>

      {/* Trees Silhouette */}
      <div className={`absolute bottom-0 left-0 flex w-[200%] scenery-slide-fast ${!isMoving ? 'paused' : ''} items-end opacity-30`}>
        <div className="w-1/2 flex items-end justify-around pb-1">
          <TreePine size={32} className="text-black" />
          <TreePine size={48} className="text-black" />
          <TreePine size={24} className="text-black" />
          <TreePine size={40} className="text-black" />
          <TreePine size={32} className="text-black" />
        </div>
        <div className="w-1/2 flex items-end justify-around pb-1">
          <TreePine size={32} className="text-black" />
          <TreePine size={48} className="text-black" />
          <TreePine size={24} className="text-black" />
          <TreePine size={40} className="text-black" />
          <TreePine size={32} className="text-black" />
        </div>
      </div>
    </div>
  );
};

export default function PetDashboard() {
  const [activePetIndex, setActivePetIndex] = useState(0);
  const [activeTab, setActiveTab] = useState('home');
  const [fedStatus, setFedStatus] = useState<Record<string, boolean>>({});
  const [waterStatus, setWaterStatus] = useState<Record<string, boolean>>({});
  const [expandedCard, setExpandedCard] = useState<string | null>(null);
  const [isWalking, setIsWalking] = useState(false);
  const [walkTime, setWalkTime] = useState(0);
  const [isWalkActive, setIsWalkActive] = useState(false);
  const [showSummary, setShowSummary] = useState(false);
  const [lastWalkStats, setLastWalkStats] = useState({ time: 0, distance: 0 });
  const [poopCount, setPoopCount] = useState(0);
  const [showAddPet, setShowAddPet] = useState(false);
  const [showWalkSettings, setShowWalkSettings] = useState(false);
  const [walkGoalMinutes, setWalkGoalMinutes] = useState(30);

  // Animation states
  const [foodDrops, setFoodDrops] = useState<Record<string, number[]>>({});
  const [litterAnimating, setLitterAnimating] = useState<Record<string, boolean>>({});
  const [expenseAnimating, setExpenseAnimating] = useState<Record<string, boolean>>({});
  const [feedingAnim, setFeedingAnim] = useState<Record<string, boolean>>({});
  const [waterAnim, setWaterAnim] = useState<Record<string, boolean>>({});
  const [litterAnim, setLitterAnim] = useState<Record<string, boolean>>({});
  const [poopDrops, setPoopDrops] = useState<Record<string, number[]>>({});
  const [waterDrops, setWaterDrops] = useState<Record<string, number[]>>({});

  const handleQuickFeed = (e: React.MouseEvent) => {
    e.stopPropagation();
    const petId = selectedPet.id;
    
    setFeedingAnim(prev => ({ ...prev, [petId]: true }));
    
    const newDrops = Array.from({ length: 5 }, (_, i) => Date.now() + i);
    setFoodDrops(prev => ({ ...prev, [petId]: newDrops }));
    
    setTimeout(() => {
      setFeedingAnim(prev => ({ ...prev, [petId]: false }));
      setFedStatus(prev => ({ ...prev, [petId]: true }));
    }, 1500);
  };

  const handleQuickWater = (e: React.MouseEvent) => {
    e.stopPropagation();
    const petId = selectedPet.id;
    
    setWaterAnim(prev => ({ ...prev, [petId]: true }));
    
    const newDrops = Array.from({ length: 5 }, (_, i) => Date.now() + i);
    setWaterDrops(prev => ({ ...prev, [petId]: newDrops }));
    
    setTimeout(() => {
      setWaterAnim(prev => ({ ...prev, [petId]: false }));
      setWaterStatus(prev => ({ ...prev, [petId]: true }));
    }, 1500);
  };

  const handleQuickClean = (e: React.MouseEvent) => {
    e.stopPropagation();
    const petId = selectedPet.id;
    
    setLitterAnim(prev => ({ ...prev, [petId]: true }));
    
    const newDrops = Array.from({ length: 3 }, (_, i) => Date.now() + i);
    setPoopDrops(prev => ({ ...prev, [petId]: newDrops }));
    
    setTimeout(() => {
      setLitterAnim(prev => ({ ...prev, [petId]: false }));
    }, 1500);
  };

  useEffect(() => {
    let interval: NodeJS.Timeout;
    if (isWalking) {
      interval = setInterval(() => setWalkTime(prev => prev + 1), 1000);
    } else if (!isWalking && walkTime !== 0) {
      clearInterval(interval!);
    }
    return () => clearInterval(interval!);
  }, [isWalking, walkTime]);

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60).toString().padStart(2, '0');
    const s = (seconds % 60).toString().padStart(2, '0');
    return `${m}:${s}`;
  };

  const selectedPet = PETS[activePetIndex];

  const handleNextPet = () => {
    setActivePetIndex((prev) => (prev + 1) % PETS.length);
  };

  const handleFeed = (e: React.MouseEvent) => {
    e.stopPropagation();
    const newId = Date.now();
    const drops = Array.from({ length: 6 }).map((_, i) => newId + i);
    setFoodDrops(prev => ({
      ...prev,
      [selectedPet.id]: [...(prev[selectedPet.id] || []), ...drops]
    }));
    setFedStatus(prev => ({ ...prev, [selectedPet.id]: true }));
    
    setTimeout(() => {
      setFoodDrops(prev => ({
        ...prev,
        [selectedPet.id]: (prev[selectedPet.id] || []).filter(id => !drops.includes(id))
      }));
    }, 1200);
  };

  const handleLitter = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (litterAnimating[selectedPet.id]) return;
    setLitterAnimating(prev => ({ ...prev, [selectedPet.id]: true }));
    setTimeout(() => {
      setLitterAnimating(prev => ({ ...prev, [selectedPet.id]: false }));
    }, 1500);
  };

  const handleExpense = (e: React.MouseEvent) => {
    e.stopPropagation();
    if (expenseAnimating[selectedPet.id]) return;
    setExpenseAnimating(prev => ({ ...prev, [selectedPet.id]: true }));
    setTimeout(() => {
      setExpenseAnimating(prev => ({ ...prev, [selectedPet.id]: false }));
    }, 2000);
  };

  return (
    <div className="relative w-full max-w-md mx-auto h-full bg-[#F5F5F7] overflow-y-auto pb-32 font-sans text-[#1C1C1E]">
      
      {activeTab === 'home' && (
        <motion.div 
          initial={{ opacity: 0 }}
          animate={{ opacity: 1 }}
          exit={{ opacity: 0 }}
        >
          {/* Top Navigation */}
          <div className="flex justify-between items-center p-6 pb-2">
            <motion.button whileTap={{ scale: 0.9 }} className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow-sm">
              <Settings size={20} className="text-[#8E8E93]" />
            </motion.button>
            <div className="flex gap-2">
              <motion.button 
                whileTap={{ scale: 0.9 }} 
                onClick={() => setShowAddPet(true)}
                className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow-sm text-[#FF5A00]"
              >
                <Plus size={20} />
              </motion.button>
              <motion.button whileTap={{ scale: 0.9 }} className="w-10 h-10 rounded-full bg-white flex items-center justify-center shadow-sm">
                <Bell size={20} className="text-[#8E8E93]" />
              </motion.button>
            </div>
          </div>

          {/* Greeting */}
          <div className="px-6 pt-4 pb-6">
            <h1 className="text-4xl font-semibold tracking-tight leading-tight">
              Hi Daniel,
              <br />
              <span className="text-[#8E8E93] font-normal">Welcome<br/>Home!</span>
            </h1>
          </div>

      {/* Stacked Cards (Replaces the old Pet Switcher) */}
      <div className="relative h-[380px] w-full flex justify-center items-center mt-2 mb-8 perspective-1000">
        <AnimatePresence mode="popLayout">
          {PETS.map((pet, index) => {
            const offset = (index - activePetIndex + PETS.length) % PETS.length;
            if (offset > 2) return null;
            const isTop = offset === 0;

            return (
              <motion.div
                key={pet.id}
                layout
                onClick={isTop ? handleNextPet : undefined}
                initial={{ opacity: 0, y: 100, scale: 0.8 }}
                animate={{ 
                  opacity: 1,
                  y: offset * 35,
                  scale: 1 - offset * 0.06,
                  rotate: offset === 0 ? 0 : offset === 1 ? -4 : 4,
                  zIndex: 30 - offset * 10,
                }}
                exit={{ opacity: 0, y: -100, scale: 0.8, transition: { duration: 0.2 } }}
                transition={{ type: "spring", stiffness: 300, damping: 25 }}
                className={`absolute aspect-square w-[80%] max-w-[320px] rounded-[32px] shadow-2xl overflow-hidden cursor-pointer bg-gradient-to-br ${pet.color}`}
                style={{ transformOrigin: "top center" }}
              >
                {/* Card Content */}
                <div className="absolute inset-0 p-6 flex flex-col justify-between z-20">
                  <div>
                    <span className="inline-block px-3 py-1 bg-black/20 backdrop-blur-md text-white text-xs font-bold tracking-wider rounded-full uppercase mb-2">
                      {pet.breed}
                    </span>
                    <h2 className="text-5xl font-black text-white tracking-tight uppercase leading-none">
                      {pet.name}
                    </h2>
                  </div>
                  <div className="flex justify-between items-end">
                    <div className="bg-white/20 backdrop-blur-md rounded-2xl p-3 text-white">
                      <p className="text-xs font-medium opacity-80 uppercase tracking-wider">Status</p>
                      <p className="font-bold">Happy & Active</p>
                    </div>
                    {isTop && (
                      <motion.div 
                        initial={{ opacity: 0, scale: 0 }}
                        animate={{ opacity: 1, scale: 1 }}
                        className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-black shadow-lg"
                      >
                        <ChevronRight size={24} />
                      </motion.div>
                    )}
                  </div>
                </div>
                
                {/* Pet Avatar SVG */}
                <div className="absolute inset-0 z-10 bg-gradient-to-t from-black/70 via-black/10 to-transparent" />
                <div className="absolute inset-0 z-0 overflow-hidden">
                  <div className="absolute inset-0 bg-white/5" />
                  <PetAvatar
                    species={pet.type}
                    furColor={pet.furColor}
                    patternColor={pet.patternColor}
                    eyeColor={pet.eyeColor}
                    className="absolute bottom-0 left-0 w-full h-full object-contain"
                  />
                </div>
              </motion.div>
            );
          })}
        </AnimatePresence>
      </div>

      {/* Action Module (Pet Specific) */}
      <div className="px-6 mb-8">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold bg-white px-4 py-1.5 rounded-full shadow-sm inline-block">
            {selectedPet?.name}'s Actions
          </h2>
          <div className="flex gap-2">
             <div className="w-8 h-8 rounded-full bg-white flex items-center justify-center shadow-sm">
                <span className="text-xs font-medium">🐾</span>
             </div>
          </div>
        </div>

        <AnimatePresence mode="wait">
          <motion.div 
            key={selectedPet.id}
            layout
            variants={containerVariants}
            initial="hidden"
            animate="visible"
            exit="exit"
            className="grid grid-cols-2 gap-4"
          >
            {/* Card 1: Feeding */}
            <motion.div 
              layout
              variants={feedingVariants}
              whileTap={expandedCard === 'feeding' ? {} : { scale: 0.95 }}
              onClick={() => {
                if (expandedCard !== 'feeding') {
                  // If we want to expand on click, we keep this.
                  // But we want the animation on click. Let's make the card trigger the animation, and add an expand button.
                  // Wait, let's keep the expand on the card, and the animation on the Plus button.
                  // No, the prompt says "feeding卡片应该从中间开一条缝", implying the card itself does it.
                  // Let's make the card trigger the animation, and add an expand button.
                  // Actually, let's just trigger the animation on click, and NOT expand?
                  // No, the user needs to see the history.
                  // Let's make the card trigger the animation, and add an expand button.
                }
              }}
              className={`rounded-[24px] flex flex-col relative cursor-pointer ${
                expandedCard === 'feeding' ? 'bg-white p-5 col-span-2 aspect-auto min-h-[340px] shadow-sm overflow-hidden' : 'bg-transparent aspect-square justify-between drop-shadow-sm'
              }`}
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
              {expandedCard === 'feeding' ? (
                <motion.div 
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ delay: 0.1 }}
                  className="flex flex-col h-full"
                >
                  <div className="flex justify-between items-start mb-6">
                    <div className="w-12 h-12 rounded-full bg-[#F0F4F8] flex items-center justify-center text-[#4A90E2]">
                      <Bone size={24} />
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        setExpandedCard(null);
                      }}
                      className="w-8 h-8 bg-[#F5F5F7] rounded-full flex items-center justify-center text-[#1C1C1E] hover:bg-gray-200 transition-colors"
                    >
                      <X size={16} />
                    </button>
                  </div>
                  
                  <h3 className="text-2xl font-bold mb-1">Feeding</h3>
                  <p className="text-sm text-[#8E8E93] mb-6">Manage {selectedPet.name}'s diet</p>
                  
                  <div className="space-y-3 mb-8">
                    <div className="bg-[#F5F5F7] p-4 rounded-2xl flex justify-between items-center">
                      <div>
                        <p className="text-sm font-semibold">Morning Portion</p>
                        <p className="text-xs text-[#8E8E93]">80g Dry Food</p>
                      </div>
                      <CheckCircle2 className="text-[#34C759]" size={20} />
                    </div>
                    <div className="bg-[#F5F5F7] p-4 rounded-2xl flex justify-between items-center border border-[#4A90E2]/20">
                      <div>
                        <p className="text-sm font-semibold">Evening Portion</p>
                        <p className="text-xs text-[#8E8E93]">80g Wet Food</p>
                      </div>
                      {fedStatus[selectedPet.id] ? (
                        <CheckCircle2 className="text-[#34C759]" size={20} />
                      ) : (
                        <div className="w-5 h-5 rounded-full border-2 border-[#C7C7CC]" />
                      )}
                    </div>
                  </div>

                  <button 
                    onClick={handleFeed}
                    className={`w-full py-4 rounded-2xl font-bold text-white transition-colors mt-auto z-10 ${
                      fedStatus[selectedPet.id] ? 'bg-[#34C759]' : 'bg-[#4A90E2]'
                    }`}
                  >
                    {fedStatus[selectedPet.id] ? 'Fed Successfully' : 'Mark as Fed'}
                  </button>
                  
                  {/* Food Drop Animation for Expanded State */}
                  <AnimatePresence>
                    {foodDrops[selectedPet.id]?.map((dropId, i) => (
                      <motion.div
                        key={dropId}
                        initial={{ y: -50, x: 150 + (i - 2.5) * 20, opacity: 0, scale: 0.5, rotate: 0 }}
                        animate={{ 
                          y: 280, 
                          opacity: [0, 1, 1, 0], 
                          scale: 1,
                          rotate: Math.random() * 360
                        }}
                        exit={{ opacity: 0 }}
                        transition={{ 
                          duration: 0.8, 
                          delay: i * 0.1, 
                          ease: "easeIn" 
                        }}
                        className="absolute top-0 left-0 w-4 h-4 bg-[#8B4513] rounded-full shadow-sm"
                        style={{ borderRadius: '40% 60% 70% 30% / 40% 50% 60% 50%' }}
                      />
                    ))}
                  </AnimatePresence>
                </motion.div>
              ) : (
                <div className="relative w-full h-full rounded-[24px] bg-transparent">
                  {/* Food Drop Animation (Background) */}
                  <AnimatePresence>
                    {foodDrops[selectedPet.id]?.map((dropId, i) => (
                      <motion.div
                        key={dropId}
                        initial={{ y: -20, x: (i - 2) * 15, opacity: 0, scale: 0.5, rotate: 0 }}
                        animate={{ 
                          y: 80, 
                          opacity: [0, 1, 1, 0], 
                          scale: 1,
                          rotate: Math.random() * 360
                        }}
                        exit={{ opacity: 0 }}
                        transition={{ 
                          duration: 0.6, 
                          delay: i * 0.1, 
                          ease: "easeIn" 
                        }}
                        className="absolute top-0 left-1/2 w-3 h-3 bg-[#8B4513] rounded-full shadow-sm z-10"
                        style={{ borderRadius: '40% 60% 70% 30% / 40% 50% 60% 50%' }}
                      />
                    ))}
                  </AnimatePresence>

                  {/* Top Half */}
                  <motion.div 
                    animate={{ y: feedingAnim[selectedPet.id] ? -12 : 0 }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                    className="absolute top-0 left-0 right-0 h-1/2 bg-white rounded-t-[24px] p-5 pb-0 flex justify-between items-start z-20"
                  >
                    <div className="w-10 h-10 rounded-full bg-[#F0F4F8] flex items-center justify-center text-[#4A90E2]">
                      <Bone size={20} />
                    </div>
                    <motion.button 
                      whileTap={{ scale: 0.8 }}
                      onClick={handleQuickFeed}
                      className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${
                        fedStatus[selectedPet.id] ? 'bg-[#34C759] text-white' : 'bg-[#F5F5F7] text-[#1C1C1E]'
                      }`}
                    >
                       {fedStatus[selectedPet.id] ? <Check size={16} /> : <Plus size={16} />}
                    </motion.button>
                  </motion.div>

                  {/* Bottom Half */}
                  <motion.div 
                    animate={{ y: feedingAnim[selectedPet.id] ? 12 : 0 }}
                    transition={{ type: "spring", stiffness: 300, damping: 20 }}
                    className="absolute bottom-0 left-0 right-0 h-1/2 bg-white rounded-b-[24px] p-5 pt-0 flex flex-col justify-end z-30"
                    style={{ 
                      boxShadow: feedingAnim[selectedPet.id] ? "0 -4px 12px rgba(0,0,0,0.05)" : "none",
                      borderTop: feedingAnim[selectedPet.id] ? "1px solid rgba(0,0,0,0.05)" : "1px solid transparent"
                    }}
                  >
                    <h3 className="text-lg font-semibold mb-1">Feeding</h3>
                    <p className="text-xs text-[#8E8E93]">
                      {fedStatus[selectedPet.id] ? 'Just now' : `Last: ${selectedPet?.data.feeding}`}
                    </p>
                  </motion.div>
                </div>
              )}
            </motion.div>

            {/* Card 1.5: Water */}
            <motion.div 
              layout
              variants={waterVariants}
              whileTap={{ scale: 0.95 }}
              onClick={() => {
                // handleQuickWater is used on the button
              }}
              className="bg-white rounded-[24px] p-5 shadow-sm flex flex-col justify-between aspect-square relative overflow-hidden cursor-pointer"
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
              {/* Wave Animation Background */}
              <div className="absolute bottom-0 left-0 right-0 w-full h-full overflow-hidden rounded-[24px] pointer-events-none z-0">
                {/* Back Wave */}
                <motion.div
                  initial={{ y: "100%" }}
                  animate={{ y: waterAnim[selectedPet.id] ? "40%" : "100%" }}
                  transition={{ duration: 0.8, ease: "easeInOut" }}
                  className="absolute bottom-0 left-0 w-[200%] h-[60%]"
                >
                  <motion.div
                    animate={{ x: ["-50%", "0%"] }}
                    transition={{ repeat: Infinity, duration: 2, ease: "linear" }}
                    className="w-full h-full"
                  >
                    <svg viewBox="0 0 800 200" className="w-full h-full opacity-30" preserveAspectRatio="none">
                      <path d="M0,50 Q100,0 200,50 T400,50 T600,50 T800,50 L800,200 L0,200 Z" fill="#4A90E2" />
                    </svg>
                  </motion.div>
                </motion.div>
                {/* Front Wave */}
                <motion.div
                  initial={{ y: "100%" }}
                  animate={{ y: waterAnim[selectedPet.id] ? "50%" : "100%" }}
                  transition={{ duration: 0.8, ease: "easeInOut", delay: waterAnim[selectedPet.id] ? 0.1 : 0 }}
                  className="absolute bottom-0 left-0 w-[200%] h-[50%]"
                >
                  <motion.div
                    animate={{ x: ["0%", "-50%"] }}
                    transition={{ repeat: Infinity, duration: 1.5, ease: "linear" }}
                    className="w-full h-full"
                  >
                    <svg viewBox="0 0 800 200" className="w-full h-full opacity-40" preserveAspectRatio="none">
                      <path d="M0,50 Q100,100 200,50 T400,50 T600,50 T800,50 L800,200 L0,200 Z" fill="#4A90E2" />
                    </svg>
                  </motion.div>
                </motion.div>
              </div>

              {/* Falling Water Drops */}
              <AnimatePresence>
                {waterDrops[selectedPet.id]?.map((dropId, i) => (
                  <motion.div
                    key={dropId}
                    initial={{ y: -20, x: (i - 2) * 10, opacity: 0, scale: 0.5 }}
                    animate={{ 
                      y: 120, 
                      opacity: [0, 1, 1, 0], 
                      scale: [0.5, 1, 1, 0.5],
                    }}
                    exit={{ opacity: 0 }}
                    transition={{ 
                      duration: 0.6, 
                      delay: i * 0.1, 
                      ease: "easeIn" 
                    }}
                    className="absolute top-0 left-1/2 w-2 h-6 bg-[#4A90E2] rounded-full shadow-sm z-10 opacity-60"
                  />
                ))}
              </AnimatePresence>

              {/* Top Content */}
              <div className="flex justify-between items-start z-10 relative">
                <div className="w-10 h-10 rounded-full bg-[#E6F0FA] flex items-center justify-center text-[#4A90E2]">
                  <Droplets size={20} />
                </div>
                <motion.button 
                  whileTap={{ scale: 0.8 }}
                  onClick={handleQuickWater}
                  className={`w-8 h-8 rounded-full flex items-center justify-center transition-colors ${
                    waterStatus[selectedPet.id] ? 'bg-[#4A90E2] text-white' : 'bg-[#F5F5F7] text-[#1C1C1E]'
                  }`}
                >
                  {waterStatus[selectedPet.id] ? <Check size={16} /> : <Plus size={16} />}
                </motion.button>
              </div>

              {/* Bottom Content */}
              <div className="z-10 relative">
                <h3 className="text-lg font-semibold mb-1">Water</h3>
                <p className="text-xs text-[#8E8E93]">
                  {waterStatus[selectedPet.id] ? 'Just now' : `Last: ${selectedPet?.data.water}`}
                </p>
              </div>
            </motion.div>

            {/* Card 2: Litter/Cleaning */}
            <motion.div 
              layout
              variants={litterVariants}
              whileTap={{ scale: 0.95 }}
              onClick={() => {
                // handleQuickClean is used on the button
              }}
              className="rounded-[24px] drop-shadow-sm flex flex-col justify-between aspect-square relative cursor-pointer bg-transparent"
              style={{ perspective: 1000 }}
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
              {/* Poop Drop Animation (Background) */}
              <AnimatePresence>
                {poopDrops[selectedPet.id]?.map((dropId, i) => (
                  <motion.div
                    key={dropId}
                    initial={{ y: -20, x: 30 + (i * 20), opacity: 0, scale: 0.5, rotate: 0 }}
                    animate={{ 
                      y: 90, 
                      opacity: [0, 1, 1, 0], 
                      scale: 1,
                      rotate: Math.random() * 360
                    }}
                    exit={{ opacity: 0 }}
                    transition={{ 
                      duration: 0.6, 
                      delay: i * 0.15, 
                      ease: "easeIn" 
                    }}
                    className="absolute top-0 left-0 w-4 h-4 bg-[#6B4423] rounded-full shadow-sm z-10"
                    style={{ borderRadius: '40% 60% 70% 30% / 40% 50% 60% 50%' }}
                  />
                ))}
              </AnimatePresence>

              {/* Top Half (Lid) */}
              <motion.div
                className="absolute top-0 left-0 right-0 h-[45%] bg-white rounded-t-[24px] p-5 pb-0 flex justify-between items-start z-20"
                style={{ transformOrigin: "100% 100%" }}
                animate={{ 
                  rotateZ: litterAnim[selectedPet.id] ? 15 : 0,
                }}
                transition={{ duration: 0.5, type: "spring", stiffness: 200, damping: 15 }}
              >
                <div className={`w-10 h-10 rounded-full flex items-center justify-center ${selectedPet?.data.litter === 'Needs cleaning' ? 'bg-[#FFF0F0] text-[#FF3B30]' : 'bg-[#F4F8E6] text-[#8BC34A]'}`}>
                  <Trash2 size={20} />
                </div>
                <motion.button 
                  whileTap={{ scale: 0.8 }}
                  onClick={handleQuickClean}
                  className="w-8 h-8 rounded-full bg-[#F5F5F7] flex items-center justify-center text-[#1C1C1E]"
                >
                   <Plus size={16} />
                </motion.button>
              </motion.div>

              {/* Bottom Half */}
              <motion.div
                className="absolute bottom-0 left-0 right-0 h-[55%] bg-white rounded-b-[24px] p-5 pt-0 flex flex-col justify-end z-30"
                style={{ 
                  boxShadow: litterAnim[selectedPet.id] ? "0 -4px 12px rgba(0,0,0,0.05)" : "none",
                  borderTop: "1px solid transparent"
                }}
              >
                <h3 className="text-lg font-semibold mb-1">Litter</h3>
                <p className="text-xs text-[#8E8E93]">
                  {litterAnim[selectedPet.id] ? 'Cleaning...' : selectedPet?.data.litter}
                </p>
              </motion.div>
            </motion.div>

            {/* Card 2.5: Expenses */}
            <motion.div 
              layout
              variants={expensesVariants}
              style={{ perspective: 1000 }}
              whileTap={{ scale: 0.95 }}
              onClick={handleExpense}
              className="bg-white rounded-[24px] p-5 shadow-sm flex flex-col justify-between aspect-square relative overflow-hidden cursor-pointer"
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
              <div className="flex justify-between items-start">
                <motion.div 
                  className="w-10 h-10 rounded-full bg-[#F2F2F7] flex items-center justify-center text-[#5856D6] z-10"
                  animate={expenseAnimating[selectedPet.id] ? {
                    y: [0, 5, 0],
                    scale: [1, 1.1, 1]
                  } : {}}
                  transition={{ duration: 0.3, delay: 0.4 }}
                >
                  <Wallet size={20} />
                </motion.div>
              </div>
              
              {/* Coin Animation */}
              <AnimatePresence>
                {expenseAnimating[selectedPet.id] && (
                  <motion.div
                    initial={{ y: -60, opacity: 0, scale: 0.5 }}
                    animate={{ y: 10, opacity: [0, 1, 1, 0], scale: 1 }}
                    exit={{ opacity: 0 }}
                    transition={{ duration: 0.6, ease: "easeIn" }}
                    className="absolute top-0 left-5 w-6 h-6 bg-[#FFCC00] rounded-full flex items-center justify-center shadow-md border-2 border-[#E6B800] z-0"
                  >
                    <span className="text-[10px] font-bold text-[#B38F00]">$</span>
                  </motion.div>
                )}
              </AnimatePresence>

              <div className="z-10">
                <h3 className="text-lg font-semibold mb-1">
                  {expenseAnimating[selectedPet.id] ? (
                    <motion.span
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="text-[#34C759]"
                    >
                      + $15
                    </motion.span>
                  ) : (
                    selectedPet?.data.expenses
                  )}
                </h3>
                <p className="text-xs text-[#8E8E93]">This Month</p>
              </div>
            </motion.div>

            {/* Card 3: Weight */}
            <motion.div 
              layout
              variants={weightVariants}
              whileTap={{ scale: 0.95 }}
              className="bg-white rounded-[24px] p-5 shadow-sm flex flex-col justify-between aspect-[2/1] col-span-2 relative overflow-hidden cursor-pointer"
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
               <div className="flex items-center justify-between w-full h-full">
                  <div className="flex items-center gap-4">
                    <div className="w-12 h-12 rounded-full bg-[#F4F8E6] flex items-center justify-center text-[#8BC34A]">
                      <Scale size={24} />
                    </div>
                    <div>
                      <h3 className="text-lg font-semibold">Weight</h3>
                      <p className="text-sm text-[#8E8E93]">
                        {selectedPet?.data.weight} 
                        <span className={`text-xs ml-1 ${
                          selectedPet?.data.weightChangeType === 'down' ? 'text-[#34C759]' : 
                          selectedPet?.data.weightChangeType === 'up' ? 'text-[#FF3B30]' : 
                          'text-[#8E8E93]'
                        }`}>
                          {selectedPet?.data.weightChange}
                        </span>
                      </p>
                    </div>
                  </div>
                  <div className="w-10 h-10 rounded-full bg-[#F5F5F7] flex items-center justify-center text-[#1C1C1E]">
                    <ChevronRight size={20} />
                  </div>
               </div>
            </motion.div>

            {/* Card 5: Walk/Activity */}
            <motion.div 
              layout
              variants={walkVariants}
              whileTap={expandedCard === 'walk' ? {} : { scale: 0.95 }}
              onClick={() => {
                if (expandedCard !== 'walk' && !isWalkActive) setExpandedCard('walk');
              }}
              className={`rounded-[24px] shadow-md flex flex-col relative cursor-pointer transition-colors ${
                expandedCard === 'walk' ? 'col-span-2 aspect-auto min-h-[480px] bg-white text-[#1C1C1E] p-5 overflow-hidden' : 'col-span-2 aspect-[2/1] text-white shadow-[#FF5A00]/20'
              }`}
              style={{ perspective: expandedCard !== 'walk' ? '1200px' : 'none' }}
              transition={{ layout: { type: "spring", stiffness: 300, damping: 25 } }}
            >
              {expandedCard === 'walk' ? (
                <motion.div 
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  transition={{ delay: 0.1 }}
                  className="flex flex-col h-full z-10"
                >
                  <div className="flex justify-between items-start mb-6">
                    <div className="w-12 h-12 rounded-full bg-[#FFF0E5] flex items-center justify-center text-[#FF5A00]">
                      <Footprints size={24} />
                    </div>
                    <button 
                      onClick={(e) => {
                        e.stopPropagation();
                        setExpandedCard(null);
                      }}
                      className="w-8 h-8 bg-[#F5F5F7] rounded-full flex items-center justify-center text-[#1C1C1E] hover:bg-gray-200 transition-colors"
                    >
                      <X size={16} />
                    </button>
                  </div>
                  
                  <h3 className="text-2xl font-bold mb-1">Walk History</h3>
                  <p className="text-sm text-[#8E8E93] mb-6">Recent activity for {selectedPet.name}</p>
                  
                  <div className="space-y-4 overflow-y-auto pb-4">
                    {/* History Item 1 */}
                    <div className="relative rounded-2xl overflow-hidden h-36 shadow-sm border border-gray-100">
                      <img src="https://images.unsplash.com/photo-1524661135-423995f22d0b?w=600&q=80" alt="Map" className="absolute inset-0 w-full h-full object-cover opacity-80" />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-black/10" />
                      <svg className="absolute inset-0 w-full h-full" preserveAspectRatio="none">
                        <path d="M 30 110 Q 100 30 180 90 T 320 50" fill="none" stroke="#FF5A00" strokeWidth="4" strokeDasharray="6 6" className="drop-shadow-md" />
                        <circle cx="30" cy="110" r="5" fill="#FF5A00" stroke="white" strokeWidth="2" />
                        <circle cx="320" cy="50" r="5" fill="white" stroke="#FF5A00" strokeWidth="2" />
                      </svg>
                      <div className="absolute inset-0 p-4 flex flex-col justify-end text-white">
                        <div className="flex justify-between items-end">
                          <div>
                            <p className="text-xs font-medium opacity-90 mb-1 drop-shadow-md">Today, 08:30 AM</p>
                            <p className="text-xl font-bold drop-shadow-md">2.4 km</p>
                          </div>
                          <div className="flex gap-3 text-sm font-medium drop-shadow-md">
                            <div className="flex items-center gap-1 bg-black/30 px-2 py-1 rounded-lg backdrop-blur-sm"><Clock size={14} /> 45m</div>
                            <div className="flex items-center gap-1 bg-black/30 px-2 py-1 rounded-lg backdrop-blur-sm">💩 x2</div>
                          </div>
                        </div>
                      </div>
                    </div>

                    {/* History Item 2 */}
                    <div className="relative rounded-2xl overflow-hidden h-36 shadow-sm border border-gray-100">
                      <img src="https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=600&q=80" alt="Map" className="absolute inset-0 w-full h-full object-cover opacity-80" />
                      <div className="absolute inset-0 bg-gradient-to-t from-black/90 via-black/40 to-black/10" />
                      <svg className="absolute inset-0 w-full h-full" preserveAspectRatio="none">
                        <path d="M 60 90 Q 160 130 220 60 T 340 100" fill="none" stroke="#FF5A00" strokeWidth="4" strokeDasharray="6 6" className="drop-shadow-md" />
                        <circle cx="60" cy="90" r="5" fill="#FF5A00" stroke="white" strokeWidth="2" />
                        <circle cx="340" cy="100" r="5" fill="white" stroke="#FF5A00" strokeWidth="2" />
                      </svg>
                      <div className="absolute inset-0 p-4 flex flex-col justify-end text-white">
                        <div className="flex justify-between items-end">
                          <div>
                            <p className="text-xs font-medium opacity-90 mb-1 drop-shadow-md">Yesterday, 18:15 PM</p>
                            <p className="text-xl font-bold drop-shadow-md">1.8 km</p>
                          </div>
                          <div className="flex gap-3 text-sm font-medium drop-shadow-md">
                            <div className="flex items-center gap-1 bg-black/30 px-2 py-1 rounded-lg backdrop-blur-sm"><Clock size={14} /> 32m</div>
                            <div className="flex items-center gap-1 bg-black/30 px-2 py-1 rounded-lg backdrop-blur-sm">💩 x1</div>
                          </div>
                        </div>
                      </div>
                    </div>
                  </div>
                </motion.div>
              ) : (
                <motion.div
                  className="w-full h-full relative"
                  style={{ transformStyle: 'preserve-3d' }}
                  animate={{ rotateX: isWalkActive ? -180 : 0 }}
                  transition={{ duration: 0.8, ease: "easeInOut", delay: isWalkActive ? 0 : 0.6 }}
                >
                  {/* FRONT FACE */}
                  <div 
                    className="absolute inset-0 bg-[#FF5A00] rounded-[24px] p-5 flex flex-col justify-between overflow-hidden"
                    style={{ backfaceVisibility: 'hidden' }}
                  >
                    {showSummary ? (
                      <div className="flex flex-col h-full justify-center items-center text-center relative z-10">
                        <div className="bg-white/20 p-3 rounded-full mb-2">
                          <Check size={24} className="text-white" />
                        </div>
                        <h3 className="text-xl font-bold mb-1">Walk Complete!</h3>
                        <div className="flex gap-4 text-sm opacity-90">
                          <p>Time: {formatTime(lastWalkStats.time)}</p>
                          <p>Dist: {lastWalkStats.distance.toFixed(2)} km</p>
                        </div>
                        
                        <button 
                          onClick={(e) => { e.stopPropagation(); setShowSummary(false); }}
                          className="mt-3 bg-white text-[#FF5A00] px-6 py-1.5 rounded-xl font-bold text-sm"
                        >
                          Done
                        </button>
                      </div>
                    ) : (
                      <>
                        <div className="flex justify-between items-start z-10 relative">
                          <div className="w-10 h-10 rounded-full bg-white/20 flex items-center justify-center text-white backdrop-blur-sm">
                            <Footprints size={20} />
                          </div>
                          <div className="flex gap-2 relative">
                            <motion.button 
                              whileTap={{ scale: 0.9 }}
                              onClick={(e) => {
                                e.stopPropagation();
                                setShowWalkSettings(!showWalkSettings);
                              }}
                              className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-sm flex items-center justify-center text-white font-bold text-sm border border-white/30 shadow-sm"
                            >
                              <Settings size={16} />
                            </motion.button>
                            
                            <AnimatePresence>
                              {showWalkSettings && (
                                <motion.div 
                                  initial={{ opacity: 0, y: 10, scale: 0.9 }}
                                  animate={{ opacity: 1, y: 0, scale: 1 }}
                                  exit={{ opacity: 0, y: 10, scale: 0.9 }}
                                  className="absolute top-12 right-0 bg-white rounded-2xl p-4 shadow-xl z-50 w-48 text-[#1C1C1E] border border-gray-100"
                                  onClick={(e) => e.stopPropagation()}
                                >
                                  <div className="text-sm font-semibold mb-2">Target Duration</div>
                                  <div className="flex items-center justify-between">
                                    <button 
                                      onClick={() => setWalkGoalMinutes(Math.max(5, walkGoalMinutes - 5))}
                                      className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200"
                                    >
                                      -
                                    </button>
                                    <div className="font-mono font-bold text-lg">{walkGoalMinutes}m</div>
                                    <button 
                                      onClick={() => setWalkGoalMinutes(walkGoalMinutes + 5)}
                                      className="w-8 h-8 rounded-full bg-gray-100 flex items-center justify-center hover:bg-gray-200"
                                    >
                                      +
                                    </button>
                                  </div>
                                </motion.div>
                              )}
                            </AnimatePresence>

                            <motion.button 
                              whileTap={{ scale: 0.9 }}
                              onClick={(e) => {
                                e.stopPropagation();
                                setWalkTime(0);
                                setPoopCount(0);
                                setShowWalkSettings(false);
                                setIsWalkActive(true);
                                setIsWalking(true);
                              }}
                              className="h-10 px-4 rounded-full bg-white text-[#FF5A00] flex items-center justify-center font-bold text-sm shadow-sm"
                            >
                              <Play size={16} className="mr-1" fill="currentColor" /> Start
                            </motion.button>
                          </div>
                        </div>
                        <div className="z-10 relative">
                          <h3 className="text-lg font-semibold mb-1">Walk & Activity</h3>
                          <p className="text-sm opacity-90">Goal: {walkGoalMinutes}m • Last: 2h ago</p>
                        </div>

                        {/* Background decoration */}
                        <motion.div 
                          className="absolute -bottom-6 -right-6 text-white/10 pointer-events-none z-0"
                          style={{ rotate: -15 }}
                        >
                          <Footprints size={120} />
                        </motion.div>
                      </>
                    )}
                  </div>

                  {/* BACK FACE */}
                  <div 
                    className="absolute inset-0 bg-[#E65100] rounded-[24px] shadow-inner"
                    style={{ backfaceVisibility: 'hidden', transform: 'rotateX(180deg)' }}
                  >
                    {/* SCENERY (Behind the top flap) */}
                    <div className="absolute top-0 left-0 w-full h-1/2 overflow-hidden rounded-t-[24px]">
                      <Scenery isMoving={isWalking} />
                    </div>

                    {/* TOP FLAP */}
                    <motion.div 
                      className="absolute top-0 left-0 w-full h-1/2 bg-[#FF5A00] rounded-t-[24px] origin-bottom z-10 flex items-center justify-center border-b border-black/10"
                      style={{ backfaceVisibility: 'hidden' }}
                      animate={{ rotateX: isWalkActive ? -180 : 0 }}
                      transition={{ duration: 0.8, ease: "easeInOut", delay: isWalkActive ? 0.6 : 0 }}
                    >
                      <Footprints size={48} className="text-white/20" />
                    </motion.div>

                    {/* BOTTOM HALF (Stats) */}
                    <div className="absolute bottom-0 left-0 w-full h-1/2 bg-[#FF5A00] rounded-b-[24px] p-4 flex flex-col justify-between z-20 shadow-[0_-10px_20px_rgba(0,0,0,0.1)]">
                      <div className="flex justify-between items-end">
                        <div>
                          <div className="flex items-start gap-1">
                            <p className="text-3xl font-mono font-bold leading-none">{formatTime(walkTime)}</p>
                            {isWalking && (
                              <motion.div 
                                animate={{ scale: [1, 1.5, 1], opacity: [1, 0.5, 1] }}
                                transition={{ repeat: Infinity, duration: 1.5 }}
                                className="w-2 h-2 bg-white rounded-full mt-1"
                              />
                            )}
                          </div>
                        </div>
                        <div className="text-right">
                          <p className="text-xl font-bold leading-none">{(walkTime * 0.0015).toFixed(2)} km</p>
                        </div>
                      </div>
                      
                      <div className="w-full h-1.5 bg-black/20 rounded-full overflow-hidden mt-2">
                        <motion.div 
                          className="h-full bg-white rounded-full"
                          initial={{ width: 0 }}
                          animate={{ width: `${Math.min(100, (walkTime / (walkGoalMinutes * 60)) * 100)}%` }}
                          transition={{ ease: "linear", duration: 1 }}
                        />
                      </div>

                      <div className="flex gap-2 mt-2">
                        <button 
                          onClick={(e) => { e.stopPropagation(); setIsWalking(!isWalking); }}
                          className="flex-1 bg-white/20 hover:bg-white/30 text-white py-1.5 rounded-xl font-bold flex items-center justify-center gap-2 transition-colors text-sm"
                        >
                          {isWalking ? <Pause size={16} /> : <Play size={16} />}
                        </button>
                        <button 
                          onClick={(e) => { 
                            e.stopPropagation(); 
                            setLastWalkStats({ time: walkTime, distance: walkTime * 0.0015 });
                            setIsWalking(false); 
                            setIsWalkActive(false); 
                            setShowSummary(true);
                          }}
                          className="flex-1 bg-red-500 hover:bg-red-600 text-white py-1.5 rounded-xl font-bold flex items-center justify-center gap-2 transition-colors text-sm"
                        >
                          <Square size={16} />
                        </button>
                      </div>
                    </div>
                  </div>
                </motion.div>
              )}
            </motion.div>
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Data Display Module (Global) */}
      <div className="px-6 mb-8">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-semibold bg-white px-4 py-1.5 rounded-full shadow-sm inline-block">
            Global Overview
          </h2>
          <button className="text-xs font-medium text-[#8E8E93] flex items-center gap-1 hover:text-[#1C1C1E] transition-colors">
            Details <ChevronRight size={14} />
          </button>
        </div>

        <div className="bg-white rounded-[32px] p-6 shadow-sm">
          <div className="flex items-end justify-between mb-6">
            <div>
              <p className="text-sm text-[#8E8E93] mb-1">Weekly Overview</p>
              <h3 className="text-3xl font-bold tracking-tight">Stats</h3>
            </div>
            <div className="flex gap-3">
              <span className="flex items-center gap-1 text-xs font-medium text-[#8E8E93]">
                <div className="w-2 h-2 rounded-full bg-[#FF5A00]"></div> Expenses
              </span>
              <span className="flex items-center gap-1 text-xs font-medium text-[#8E8E93]">
                <div className="w-2 h-2 rounded-full bg-[#4A90E2]"></div> Activity
              </span>
            </div>
          </div>

          <div className="h-48 w-full">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={GLOBAL_CHART_DATA} margin={{ top: 5, right: 0, left: 0, bottom: 0 }}>
                <defs>
                  <linearGradient id="colorExpenses" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#FF5A00" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#FF5A00" stopOpacity={0}/>
                  </linearGradient>
                  <linearGradient id="colorActivity" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#4A90E2" stopOpacity={0.3}/>
                    <stop offset="95%" stopColor="#4A90E2" stopOpacity={0}/>
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#E5E5EA" />
                <XAxis 
                  dataKey="name" 
                  axisLine={false} 
                  tickLine={false} 
                  tick={{ fontSize: 12, fill: '#8E8E93' }} 
                  dy={10}
                />
                <Tooltip 
                  contentStyle={{ borderRadius: '12px', border: 'none', boxShadow: '0 4px 12px rgba(0,0,0,0.1)' }}
                  labelStyle={{ fontWeight: 'bold', color: '#1C1C1E', marginBottom: '4px' }}
                />
                <Area 
                  type="monotone" 
                  dataKey="expenses" 
                  stroke="#FF5A00" 
                  strokeWidth={3}
                  fillOpacity={1} 
                  fill="url(#colorExpenses)" 
                />
                <Area 
                  type="monotone" 
                  dataKey="activity" 
                  stroke="#4A90E2" 
                  strokeWidth={3}
                  fillOpacity={1} 
                  fill="url(#colorActivity)" 
                />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
      </motion.div>
      )}

      {activeTab === 'coconut' && <OasisView />}
      
      {activeTab === 'pet' && (
        <FamilyOverview onAddPet={() => setShowAddPet(true)} />
      )}

      <AnimatePresence>
        {showAddPet && (
          <AddPetFlow 
            onClose={() => setShowAddPet(false)} 
            onComplete={(data) => {
              console.log('New Pet Data:', data);
              setShowAddPet(false);
            }} 
          />
        )}
      </AnimatePresence>

      {/* Bottom Navigation */}
      <div className="fixed bottom-6 left-1/2 -translate-x-1/2 w-[90%] max-w-[380px] bg-white/80 backdrop-blur-xl rounded-full shadow-[0_8px_30px_rgb(0,0,0,0.08)] border border-white/20 px-2 py-2 flex justify-between items-center z-50">
        {NAV_ITEMS.map((item) => {
          const isActive = activeTab === item.id;
          
          if (item.isSpecial) {
            return (
              <motion.button
                key={item.id}
                whileTap={{ scale: 0.9, rotate: 90 }}
                onClick={() => setActiveTab(item.id)}
                className={`w-14 h-14 rounded-full flex items-center justify-center text-white shadow-lg z-10 -mt-6 border-4 border-[#F5F5F7] transition-colors ${
                  isActive ? 'bg-[#1C1C1E] shadow-[#1C1C1E]/30' : 'bg-[#FF5A00] shadow-[#FF5A00]/30'
                }`}
              >
                <item.icon size={24} />
              </motion.button>
            );
          }

          return (
            <button
              key={item.id}
              onClick={() => setActiveTab(item.id)}
              className="relative w-12 h-12 flex items-center justify-center rounded-full"
            >
              {isActive && (
                <motion.div
                  layoutId="nav-indicator"
                  className="absolute inset-0 bg-[#F5F5F7] rounded-full"
                  transition={{ type: "spring", stiffness: 300, damping: 25 }}
                />
              )}
              <item.icon 
                size={20} 
                className={`relative z-10 transition-colors duration-300 ${isActive ? 'text-[#1C1C1E]' : 'text-[#8E8E93]'}`} 
              />
            </button>
          );
        })}
      </div>

    </div>
  );
}
