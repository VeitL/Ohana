import { motion, AnimatePresence, useMotionValue, useTransform, useSpring } from "motion/react";
import React, { useState, useEffect, useRef } from "react";
import { 
  X, Check, AlertCircle, Info, AlertTriangle, 
  Search, ChevronDown, Bell, Settings, User,
  Heart, Share2, MoreHorizontal, Play, Pause,
  Sparkles, Trash2, Image as ImageIcon
} from "lucide-react";

// Reusable Toggle Component
function Toggle({ defaultChecked = false, color = "#FF5A00", onChange }: { defaultChecked?: boolean, color?: string, onChange?: (val: boolean) => void }) {
  const [isOn, setIsOn] = useState(defaultChecked);
  return (
    <motion.div 
      whileTap={{ scale: 0.95 }}
      onClick={() => {
        const newVal = !isOn;
        setIsOn(newVal);
        onChange?.(newVal);
      }}
      className={`w-14 h-8 rounded-full relative flex items-center px-1 cursor-pointer transition-colors duration-300 ${isOn ? 'bg-opacity-100' : 'bg-glass-bg'}`}
      style={{ backgroundColor: isOn ? color : undefined, justifyContent: isOn ? 'flex-end' : 'flex-start' }}
    >
      <motion.div 
        layout
        className={`w-6 h-6 rounded-full shadow-md ${isOn ? 'bg-white' : 'bg-glass-bg'}`}
      />
    </motion.div>
  );
}

// Reusable Slider Component
function Slider({ color = "#FF5A00" }) {
  const [value, setValue] = useState(50);
  return (
    <div className="w-full flex items-center gap-4">
      <span className="text-xs text-content-muted font-mono w-8">{value}%</span>
      <div className="relative flex-1 h-2 bg-glass-bg rounded-full flex items-center">
        <div 
          className="absolute left-0 top-0 h-full rounded-full" 
          style={{ width: `${value}%`, backgroundColor: color }}
        />
        <input 
          type="range" 
          min="0" max="100" 
          value={value} 
          onChange={(e) => setValue(Number(e.target.value))}
          className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
        />
        <motion.div 
          className="absolute w-5 h-5 bg-white rounded-full shadow-lg border border-black/10 pointer-events-none"
          style={{ left: `calc(${value}% - 10px)` }}
          whileHover={{ scale: 1.2 }}
          whileTap={{ scale: 0.9 }}
        />
      </div>
    </div>
  );
}

// Reusable Segmented Control
function SegmentedControl({ options = ["Daily", "Weekly", "Monthly"] }) {
  const [active, setActive] = useState(options[0]);
  return (
    <div className="flex p-1 bg-surface-1 rounded-2xl border border-border-subtle">
      {options.map((opt) => (
        <div 
          key={opt}
          onClick={() => setActive(opt)}
          className="relative flex-1 py-2 px-4 text-center cursor-pointer text-sm font-medium z-10"
        >
          {active === opt && (
            <motion.div 
              layoutId="segmented-bg"
              className="absolute inset-0 bg-glass-bg rounded-xl z-[-1]"
              transition={{ type: "spring", stiffness: 400, damping: 30 }}
            />
          )}
          <span className={active === opt ? "text-content-base" : "text-content-muted"}>{opt}</span>
        </div>
      ))}
    </div>
  );
}

// Animated Accordion
function Accordion({ title, children, defaultOpen = false }: { title: string, children: React.ReactNode, defaultOpen?: boolean }) {
  const [isOpen, setIsOpen] = useState(defaultOpen);
  return (
    <div className="border border-border-subtle rounded-2xl overflow-hidden bg-surface-1">
      <button 
        onClick={() => setIsOpen(!isOpen)}
        className="w-full flex items-center justify-between p-4 text-left hover:bg-glass-hover transition-colors"
      >
        <span className="font-medium text-content-base">{title}</span>
        <motion.div animate={{ rotate: isOpen ? 180 : 0 }} transition={{ type: "spring", stiffness: 300, damping: 20 }}>
          <ChevronDown size={20} className="text-content-muted" />
        </motion.div>
      </button>
      <AnimatePresence initial={false}>
        {isOpen && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ type: "spring", stiffness: 300, damping: 25 }}
          >
            <div className="p-4 pt-0 text-content-muted text-sm leading-relaxed border-t border-border-subtle">
              {children}
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// Skeleton Loader
function Skeleton({ className }: { className?: string }) {
  return (
    <div className={`relative overflow-hidden bg-glass-bg rounded-xl ${className}`}>
      <motion.div
        className="absolute inset-0 bg-gradient-to-r from-transparent via-white/10 to-transparent"
        animate={{ x: ["-100%", "100%"] }}
        transition={{ repeat: Infinity, duration: 1.5, ease: "linear" }}
      />
    </div>
  );
}

// Animated Bar Chart
function AnimatedBarChart() {
  const [data, setData] = useState([40, 70, 45, 90, 65, 85, 50]);
  
  useEffect(() => {
    const interval = setInterval(() => {
      setData(data.map(() => Math.floor(Math.random() * 80) + 20));
    }, 3000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div className="flex items-end justify-between gap-2 h-32 w-full p-4 bg-surface-1 rounded-2xl border border-border-subtle">
      {data.map((h, i) => (
        <div key={i} className="flex-1 bg-glass-bg rounded-t-md relative group flex justify-center h-full items-end">
          <motion.div 
            initial={{ height: 0 }}
            animate={{ height: `${h}%` }}
            transition={{ type: "spring", stiffness: 100, damping: 15 }}
            className="w-full bg-[#FF5A00] rounded-t-md relative"
          >
            {/* Tooltip on hover */}
            <div className="absolute -top-8 left-1/2 -translate-x-1/2 bg-white text-black text-xs font-bold px-2 py-1 rounded opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none">
              {h}
            </div>
          </motion.div>
        </div>
      ))}
    </div>
  );
}

// 3D Tilt Card
function TiltCard() {
  const ref = useRef<HTMLDivElement>(null);
  const x = useMotionValue(0);
  const y = useMotionValue(0);

  // Smooth out the motion values
  const mouseXSpring = useSpring(x, { stiffness: 300, damping: 30 });
  const mouseYSpring = useSpring(y, { stiffness: 300, damping: 30 });

  // Map mouse position to rotation angle
  const rotateX = useTransform(mouseYSpring, [-0.5, 0.5], ["15deg", "-15deg"]);
  const rotateY = useTransform(mouseXSpring, [-0.5, 0.5], ["-15deg", "15deg"]);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    const width = rect.width;
    const height = rect.height;
    const mouseX = e.clientX - rect.left;
    const mouseY = e.clientY - rect.top;
    const xPct = mouseX / width - 0.5;
    const yPct = mouseY / height - 0.5;
    x.set(xPct);
    y.set(yPct);
  };

  const handleMouseLeave = () => {
    x.set(0);
    y.set(0);
  };

  return (
    <motion.div
      ref={ref}
      onMouseMove={handleMouseMove}
      onMouseLeave={handleMouseLeave}
      style={{ rotateX, rotateY, transformStyle: "preserve-3d" }}
      className="w-full aspect-[4/3] rounded-3xl bg-gradient-to-br from-[#0D1B3E] to-[#1A2A6C] p-6 relative shadow-2xl border border-border-subtle cursor-pointer flex flex-col justify-between"
    >
      <div style={{ transform: "translateZ(50px)" }}>
        <div className="w-12 h-12 rounded-full bg-glass-bg flex items-center justify-center text-[#C8FF00] mb-4">
          <Sparkles size={24} />
        </div>
        <h3 className="text-2xl font-bold text-content-base mb-2">3D Tilt Card</h3>
        <p className="text-content-muted text-sm">Hover over me to see the magnetic 3D rotation effect. Elements pop out in Z-space.</p>
      </div>
      <div style={{ transform: "translateZ(30px)" }} className="flex justify-end">
        <div className="px-4 py-2 rounded-full bg-glass-bg text-content-base text-sm font-medium backdrop-blur-md">
          Interactive
        </div>
      </div>
    </motion.div>
  );
}

// Swipeable List Item
function SwipeableItem() {
  return (
    <div className="relative w-full h-16 bg-red-500/20 rounded-2xl overflow-hidden flex items-center justify-end px-6">
      <Trash2 className="text-red-500" size={20} />
      <motion.div 
        drag="x" 
        dragConstraints={{ left: -80, right: 0 }} 
        dragElastic={0.1}
        className="absolute inset-0 bg-surface-2 rounded-2xl flex items-center px-6 border border-border-subtle cursor-grab active:cursor-grabbing"
      >
        <div className="flex items-center gap-4">
          <div className="w-8 h-8 rounded-full bg-glass-bg flex items-center justify-center"><User size={14} /></div>
          <span className="font-medium text-content-base">Swipe me left</span>
        </div>
      </motion.div>
    </div>
  );
}

// Animated Pill Tabs
function AnimatedTabs() {
  const tabs = ["Overview", "Activity", "Settings"];
  const [active, setActive] = useState(tabs[0]);
  return (
    <div className="flex space-x-1 bg-surface-base p-1.5 rounded-full w-max border border-border-subtle">
      {tabs.map(tab => (
        <button key={tab} onClick={() => setActive(tab)} className="relative px-6 py-2.5 text-sm font-medium rounded-full transition-colors">
          {active === tab && <motion.div layoutId="pill-tab" className="absolute inset-0 bg-glass-bg rounded-full z-0" transition={{ type: "spring", stiffness: 400, damping: 30 }} />}
          <span className={`relative z-10 ${active === tab ? 'text-content-base' : 'text-content-muted hover:text-content-muted'}`}>{tab}</span>
        </button>
      ))}
    </div>
  )
}

// Micro-interaction Like Button
function LikeButton() {
  const [liked, setLiked] = useState(false);
  return (
    <motion.button 
      whileTap={{ scale: 0.8 }} 
      onClick={() => setLiked(!liked)} 
      className="relative w-14 h-14 rounded-full bg-surface-2 border border-border-subtle flex items-center justify-center"
    >
       <motion.div animate={liked ? { scale: [1, 1.4, 1] } : {}} transition={{ duration: 0.4 }}>
         <Heart className={liked ? "fill-red-500 text-red-500" : "text-content-muted"} size={24} />
       </motion.div>
       <AnimatePresence>
         {liked && (
           <motion.div 
             initial={{ scale: 0.5, opacity: 1 }} 
             animate={{ scale: 2.5, opacity: 0 }} 
             transition={{ duration: 0.6, ease: "easeOut" }} 
             className="absolute inset-0 rounded-full border-2 border-red-500 pointer-events-none" 
           />
         )}
       </AnimatePresence>
    </motion.button>
  )
}

// Avatar Stack
function AvatarStack() {
  const colors = ["from-blue-500 to-cyan-500", "from-purple-500 to-pink-500", "from-orange-500 to-red-500", "from-emerald-500 to-teal-500"];
  return (
    <div className="flex -space-x-4">
      {colors.map((color, i) => (
        <motion.div 
          key={i} 
          whileHover={{ y: -4, zIndex: 10 }}
          className={`w-12 h-12 rounded-full border-2 border-surface-1 bg-gradient-to-br ${color} flex items-center justify-center text-content-base font-bold shadow-lg relative`}
        >
          U{i+1}
        </motion.div>
      ))}
      <div className="w-12 h-12 rounded-full border-2 border-surface-1 bg-glass-bg backdrop-blur-md flex items-center justify-center text-content-muted font-medium text-sm shadow-lg z-0">
        +3
      </div>
    </div>
  )
}

// Glassmorphism Card
function GlassCard() {
  return (
    <div className="relative w-full h-64 rounded-[32px] overflow-hidden flex items-center justify-center bg-surface-base">
      {/* Background Blobs */}
      <motion.div animate={{ rotate: 360 }} transition={{ duration: 20, repeat: Infinity, ease: "linear" }} className="absolute w-40 h-40 bg-[#C8FF00]/30 rounded-full blur-3xl -top-10 -left-10" />
      <motion.div animate={{ rotate: -360 }} transition={{ duration: 25, repeat: Infinity, ease: "linear" }} className="absolute w-40 h-40 bg-[#FF5A00]/20 rounded-full blur-3xl -bottom-10 -right-10" />
      
      {/* Glass Panel */}
      <div className="relative z-10 w-[85%] h-[75%] bg-white/[0.03] backdrop-blur-xl border border-border-subtle rounded-3xl p-6 flex flex-col justify-between shadow-2xl">
        <div className="flex justify-between items-start">
          <div className="w-12 h-12 rounded-full bg-glass-bg flex items-center justify-center"><ImageIcon size={20} className="text-content-muted" /></div>
          <div className="px-3 py-1 rounded-full bg-glass-bg text-xs font-medium text-content-muted">Glassmorphism</div>
        </div>
        <div>
          <div className="h-5 w-32 bg-glass-bg rounded-full mb-3" />
          <div className="h-3 w-48 bg-glass-bg rounded-full" />
        </div>
      </div>
    </div>
  )
}

// macOS/iOS Dock Component
function Dock() {
  const dockItems = [
    { icon: <Settings size={20} />, label: "Settings", active: true },
    { icon: <User size={20} />, label: "Profile", active: false },
    { icon: <Bell size={20} />, label: "Notifications", active: true },
    { icon: <Search size={20} />, label: "Search", active: false },
    { icon: <ImageIcon size={20} />, label: "Photos", active: false },
  ];

  const mouseX = useMotionValue(Infinity);

  return (
    <div className="flex items-center justify-center w-full py-12 bg-surface-base relative overflow-hidden rounded-[32px]">
      {/* Background Blobs for Glass Effect */}
      <motion.div animate={{ rotate: 360 }} transition={{ duration: 20, repeat: Infinity, ease: "linear" }} className="absolute w-64 h-64 bg-[#C8FF00]/20 rounded-full blur-3xl -top-20 -left-20" />
      <motion.div animate={{ rotate: -360 }} transition={{ duration: 25, repeat: Infinity, ease: "linear" }} className="absolute w-64 h-64 bg-[#FF5A00]/20 rounded-full blur-3xl -bottom-20 -right-20" />

      <motion.div 
        className="relative z-10 flex items-end gap-3 px-4 pb-3 pt-4 rounded-3xl bg-glass-bg backdrop-blur-2xl border border-border-subtle shadow-2xl"
        onMouseMove={(e) => mouseX.set(e.pageX)}
        onMouseLeave={() => mouseX.set(Infinity)}
      >
        {dockItems.map((item, i) => (
          <DockItem key={i} item={item} mouseX={mouseX} />
        ))}
      </motion.div>
    </div>
  );
}

const DockItem: React.FC<{ item: any, mouseX: any }> = ({ item, mouseX }) => {
  const ref = useRef<HTMLDivElement>(null);

  const distance = useTransform(mouseX, (val: number) => {
    const bounds = ref.current?.getBoundingClientRect() ?? { x: 0, width: 0 };
    return val - bounds.x - bounds.width / 2;
  });

  const widthSync = useTransform(distance, [-150, 0, 150], [48, 80, 48]);
  const width = useSpring(widthSync, { mass: 0.1, stiffness: 150, damping: 12 });

  return (
    <div className="flex flex-col items-center gap-1">
      <motion.div 
        ref={ref}
        style={{ width, height: width }}
        className="rounded-2xl bg-surface-1 border border-border-subtle flex items-center justify-center text-content-base shadow-lg cursor-pointer hover:bg-glass-hover transition-colors"
        whileTap={{ scale: 0.9 }}
      >
        <motion.div style={{ scale: useTransform(width, [48, 80], [1, 1.5]) }}>
          {item.icon}
        </motion.div>
      </motion.div>
      <div className={`w-1 h-1 rounded-full ${item.active ? 'bg-content-base' : 'bg-transparent'}`} />
    </div>
  );
}

// Magnetic Button
function MagneticButton({ children }: { children: React.ReactNode }) {
  const ref = useRef<HTMLButtonElement>(null);
  const [position, setPosition] = useState({ x: 0, y: 0 });

  const handleMouse = (e: React.MouseEvent<HTMLButtonElement>) => {
    const { clientX, clientY } = e;
    const { height, width, left, top } = ref.current!.getBoundingClientRect();
    const middleX = clientX - (left + width / 2);
    const middleY = clientY - (top + height / 2);
    setPosition({ x: middleX * 0.2, y: middleY * 0.2 });
  };

  const reset = () => {
    setPosition({ x: 0, y: 0 });
  };

  const { x, y } = position;

  return (
    <motion.button
      ref={ref}
      onMouseMove={handleMouse}
      onMouseLeave={reset}
      animate={{ x, y }}
      transition={{ type: "spring", stiffness: 150, damping: 15, mass: 0.1 }}
      className="px-8 py-4 bg-surface-base text-content-base rounded-full border border-border-subtle shadow-lg hover:bg-glass-hover transition-colors relative overflow-hidden"
    >
      <span className="relative z-10">{children}</span>
    </motion.button>
  );
}

// Shiny Text
function ShinyText({ text }: { text: string }) {
  return (
    <div className="relative inline-block overflow-hidden rounded-lg px-2">
      <span className="text-content-base font-bold text-4xl tracking-tight">{text}</span>
      <motion.div
        className="absolute inset-0 z-10 bg-gradient-to-r from-transparent via-white/60 to-transparent skew-x-[-20deg] w-1/2"
        initial={{ left: "-100%" }}
        animate={{ left: "200%" }}
        transition={{ repeat: Infinity, duration: 2.5, ease: "easeInOut", repeatDelay: 1 }}
      />
    </div>
  );
}

// Staggered List
function StaggeredList() {
  const [isOpen, setIsOpen] = useState(false);
  const items = ["Dashboard", "Analytics", "Settings", "Profile"];

  return (
    <div className="flex flex-col items-center">
      <motion.button
        whileTap={{ scale: 0.95 }}
        onClick={() => setIsOpen(!isOpen)}
        className="px-6 py-3 bg-surface-2 text-content-base rounded-2xl font-medium flex items-center gap-2"
      >
        Menu <motion.div animate={{ rotate: isOpen ? 180 : 0 }}><ChevronDown size={16} /></motion.div>
      </motion.button>
      
      <AnimatePresence>
        {isOpen && (
          <motion.div
            initial="hidden"
            animate="visible"
            exit="hidden"
            variants={{
              hidden: { opacity: 0, y: -10 },
              visible: { opacity: 1, y: 0, transition: { staggerChildren: 0.1 } }
            }}
            className="mt-4 flex flex-col gap-2 w-48 bg-surface-1 border border-border-subtle p-2 rounded-2xl shadow-xl"
          >
            {items.map((item, i) => (
              <motion.div
                key={i}
                variants={{
                  hidden: { opacity: 0, x: -20 },
                  visible: { opacity: 1, x: 0 }
                }}
                className="px-4 py-2 hover:bg-glass-hover rounded-xl cursor-pointer text-content-base text-sm font-medium"
              >
                {item}
              </motion.div>
            ))}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}

// Spotlight Card
function SpotlightCard() {
  const ref = useRef<HTMLDivElement>(null);
  const [position, setPosition] = useState({ x: 0, y: 0 });
  const [opacity, setOpacity] = useState(0);

  const handleMouseMove = (e: React.MouseEvent<HTMLDivElement>) => {
    if (!ref.current) return;
    const rect = ref.current.getBoundingClientRect();
    setPosition({ x: e.clientX - rect.left, y: e.clientY - rect.top });
  };

  return (
    <div
      ref={ref}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setOpacity(1)}
      onMouseLeave={() => setOpacity(0)}
      className="relative w-full h-48 rounded-[32px] bg-surface-2 border border-border-subtle overflow-hidden flex items-center justify-center"
    >
      <motion.div
        animate={{ opacity }}
        transition={{ duration: 0.3 }}
        className="pointer-events-none absolute -inset-px rounded-[32px] opacity-0 transition duration-300"
        style={{
          background: `radial-gradient(600px circle at ${position.x}px ${position.y}px, rgba(255,255,255,0.1), transparent 40%)`,
        }}
      />
      <div className="z-10 text-content-base font-medium flex flex-col items-center gap-2">
        <Sparkles size={24} className="text-[#FF5A00]" />
        <span>Spotlight Effect</span>
      </div>
    </div>
  );
}

export default function DesignSystem({ onClose }: { onClose: () => void }) {
  const [isLoading, setIsLoading] = useState(false);
  const [isDark, setIsDark] = useState(true);

  // Lock body scroll
  useEffect(() => {
    document.body.style.overflow = "hidden";
    return () => { document.body.style.overflow = "auto"; };
  }, []);

  useEffect(() => {
    if (isDark) {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [isDark]);

  return (
    <AnimatePresence>
      <motion.div 
        initial={{ opacity: 0, y: "100%" }}
        animate={{ opacity: 1, y: 0 }}
        exit={{ opacity: 0, y: "100%" }}
        transition={{ type: "spring", stiffness: 300, damping: 35 }}
        className="fixed inset-0 z-[100] bg-surface-base overflow-y-auto overflow-x-hidden"
      >
        {/* Header */}
        <div className="sticky top-0 z-50 bg-surface-base/80 backdrop-blur-xl border-b border-border-subtle px-6 py-4 flex items-center justify-between">
          <div>
            <h1 className="text-xl font-bold text-content-base tracking-tight">UI/UX Design Spec</h1>
            <p className="text-xs text-content-muted font-mono mt-1">v1.0.0 • Component Library</p>
          </div>
          <div className="flex items-center gap-4">
            <div className="flex items-center gap-2 bg-surface-1 px-3 py-1.5 rounded-full border border-border-subtle">
              <span className="text-xs font-medium text-content-muted">Light</span>
              <Toggle defaultChecked={isDark} color="#0D1B3E" onChange={(val) => setIsDark(val)} />
              <span className="text-xs font-medium text-content-muted">Dark</span>
            </div>
            <button 
              onClick={onClose}
              className="w-10 h-10 rounded-full bg-glass-bg border border-border-subtle flex items-center justify-center text-content-base hover:bg-glass-hover transition-colors"
            >
              <X size={20} />
            </button>
          </div>
        </div>

        <div className="max-w-5xl mx-auto p-6 sm:p-10 space-y-16 pb-32">
          
          {/* 1. Colors */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">01. Colors</h2>
            <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-6 gap-4">
              {[
                { name: "Primary", hex: "#FF5A00", text: "text-content-base" },
                { name: "Lime", hex: "#C8FF00", text: "text-black" },
                { name: "Dark Blue", hex: "#0D1B3E", text: "text-content-base" },
                { name: "Ink", hex: "#1A1A2E", text: "text-content-base" },
                { name: "Surface 1", hex: "#1C1C1E", text: "text-content-base" },
                { name: "Surface 2", hex: "#2C2C2E", text: "text-content-base" },
              ].map(color => (
                <div key={color.name} className="flex flex-col gap-3">
                  <div 
                    className="w-full aspect-square rounded-[24px] shadow-lg border border-border-subtle flex items-end p-4"
                    style={{ backgroundColor: color.hex }}
                  >
                    <span className={`text-xs font-mono font-bold ${color.text}`}>{color.hex}</span>
                  </div>
                  <span className="text-sm font-medium text-content-muted">{color.name}</span>
                </div>
              ))}
            </div>
          </section>

          {/* 2. Typography */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">02. Typography</h2>
            <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle space-y-8">
              <div>
                <div className="text-sm text-content-muted mb-2 font-mono">Display (5xl, Bold, Tight)</div>
                <div className="text-5xl font-bold tracking-tight text-content-base">The quick brown fox</div>
              </div>
              <div>
                <div className="text-sm text-content-muted mb-2 font-mono">Heading 1 (3xl, Medium)</div>
                <div className="text-3xl font-medium text-content-base">Jumps over the lazy dog</div>
              </div>
              <div>
                <div className="text-sm text-content-muted mb-2 font-mono">Heading 2 (xl, Medium)</div>
                <div className="text-xl font-medium text-content-base">Pack my box with five dozen liquor jugs</div>
              </div>
              <div>
                <div className="text-sm text-content-muted mb-2 font-mono">Body (base, Regular, 80% opacity)</div>
                <div className="text-base text-content-muted leading-relaxed max-w-2xl">
                  Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
                </div>
              </div>
              <div className="flex gap-12">
                <div>
                  <div className="text-sm text-content-muted mb-2 font-mono">Caption (sm, 50% opacity)</div>
                  <div className="text-sm text-content-muted">Small descriptive text</div>
                </div>
                <div>
                  <div className="text-sm text-content-muted mb-2 font-mono">Mono (sm, Widest)</div>
                  <div className="font-mono text-sm tracking-widest text-content-muted">0123456789</div>
                </div>
              </div>
            </div>
          </section>

          {/* 3. Buttons & Actions */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">03. Buttons & Actions</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col gap-6 items-start">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Primary & Secondary</div>
                
                <motion.button 
                  whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.95 }}
                  className="bg-[#FF5A00] text-content-base rounded-full px-8 py-4 font-medium shadow-[0_8px_20px_rgba(255,90,0,0.3)] flex items-center gap-2"
                >
                  <Play size={18} fill="currentColor" /> Primary Action
                </motion.button>

                <motion.button 
                  whileHover={{ scale: 1.02, backgroundColor: "rgba(255,255,255,0.15)" }} whileTap={{ scale: 0.95 }}
                  className="bg-glass-bg text-content-base rounded-full px-8 py-4 font-medium border border-border-subtle flex items-center gap-2"
                >
                  <Settings size={18} /> Secondary Action
                </motion.button>

                <motion.button 
                  whileHover={{ backgroundColor: "rgba(255,255,255,0.1)" }} whileTap={{ scale: 0.95 }}
                  className="text-content-muted hover:text-content-base rounded-full px-8 py-4 font-medium transition-colors flex items-center gap-2"
                >
                  Ghost Action
                </motion.button>
              </div>

              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col gap-6 items-start">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Icon & States</div>
                
                <div className="flex gap-4">
                  <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="w-14 h-14 rounded-full bg-[#FF5A00] text-content-base flex items-center justify-center shadow-lg shadow-orange-500/20">
                    <Heart size={24} />
                  </motion.button>
                  <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="w-14 h-14 rounded-full bg-glass-bg border border-border-subtle text-content-base flex items-center justify-center">
                    <Share2 size={24} />
                  </motion.button>
                  <motion.button whileHover={{ scale: 1.1 }} whileTap={{ scale: 0.9 }} className="w-14 h-14 rounded-full bg-glass-bg border border-border-subtle text-content-muted flex items-center justify-center">
                    <MoreHorizontal size={24} />
                  </motion.button>
                </div>

                <motion.button 
                  onClick={() => { setIsLoading(true); setTimeout(() => setIsLoading(false), 2000); }}
                  whileHover={{ scale: 1.02 }} whileTap={{ scale: 0.95 }}
                  className="bg-surface-2 text-content-base rounded-full px-8 py-4 font-medium border border-border-subtle flex items-center justify-center gap-3 min-w-[200px]"
                >
                  {isLoading ? (
                    <motion.div 
                      animate={{ rotate: 360 }} transition={{ duration: 1, repeat: Infinity, ease: "linear" }}
                      className="w-5 h-5 border-2 border-border-subtle border-t-white rounded-full"
                    />
                  ) : "Click to Load"}
                </motion.button>

                <button disabled className="bg-glass-bg text-content-muted rounded-full px-8 py-4 font-medium cursor-not-allowed">
                  Disabled State
                </button>
              </div>
            </div>
          </section>

          {/* 4. Inputs & Forms */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">04. Inputs & Forms</h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle space-y-6">
                <div>
                  <label className="block text-sm font-medium text-content-muted mb-2 ml-1">Default Input</label>
                  <div className="relative">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-content-muted" size={20} />
                    <input 
                      type="text" 
                      placeholder="Search anything..." 
                      className="w-full bg-surface-base border border-border-subtle rounded-2xl py-4 pl-12 pr-4 text-content-base placeholder:text-content-muted focus:outline-none focus:border-[#FF5A00] focus:ring-1 focus:ring-[#FF5A00] transition-all"
                    />
                  </div>
                </div>

                <div>
                  <label className="block text-sm font-medium text-content-muted mb-2 ml-1">Error State</label>
                  <div className="relative">
                    <AlertCircle className="absolute left-4 top-1/2 -translate-y-1/2 text-red-500" size={20} />
                    <input 
                      type="email" 
                      defaultValue="invalid-email@" 
                      className="w-full bg-surface-base border border-red-500/50 rounded-2xl py-4 pl-12 pr-4 text-content-base focus:outline-none focus:border-red-500 focus:ring-1 focus:ring-red-500 transition-all"
                    />
                  </div>
                  <p className="text-red-500 text-xs mt-2 ml-1">Please enter a valid email address.</p>
                </div>
              </div>

              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle space-y-8">
                <div>
                  <label className="block text-sm font-medium text-content-muted mb-4 ml-1">Segmented Control</label>
                  <SegmentedControl />
                </div>

                <div>
                  <label className="block text-sm font-medium text-content-muted mb-4 ml-1">Range Slider</label>
                  <Slider />
                  <div className="mt-4">
                    <Slider color="#C8FF00" />
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* 5. Controls & Badges */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">05. Controls & Badges</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col gap-6">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Toggles & Switches</div>
                
                <div className="flex items-center justify-between p-4 bg-surface-2 rounded-2xl">
                  <div className="flex items-center gap-3">
                    <Bell size={20} className="text-content-muted" />
                    <span className="text-content-base font-medium">Notifications</span>
                  </div>
                  <Toggle defaultChecked={true} />
                </div>

                <div className="flex items-center justify-between p-4 bg-surface-2 rounded-2xl">
                  <div className="flex items-center gap-3">
                    <User size={20} className="text-content-muted" />
                    <span className="text-content-base font-medium">Public Profile</span>
                  </div>
                  <Toggle defaultChecked={false} color="#C8FF00" />
                </div>
              </div>

              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col gap-6">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Status Badges</div>
                
                <div className="flex flex-wrap gap-3">
                  <div className="inline-flex items-center gap-1.5 bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 px-3 py-1.5 rounded-full text-xs font-medium">
                    <Check size={14} /> Success
                  </div>
                  <div className="inline-flex items-center gap-1.5 bg-amber-500/10 text-amber-400 border border-amber-500/20 px-3 py-1.5 rounded-full text-xs font-medium">
                    <AlertTriangle size={14} /> Warning
                  </div>
                  <div className="inline-flex items-center gap-1.5 bg-red-500/10 text-red-400 border border-red-500/20 px-3 py-1.5 rounded-full text-xs font-medium">
                    <AlertCircle size={14} /> Error
                  </div>
                  <div className="inline-flex items-center gap-1.5 bg-blue-500/10 text-blue-400 border border-blue-500/20 px-3 py-1.5 rounded-full text-xs font-medium">
                    <Info size={14} /> Information
                  </div>
                  <div className="inline-flex items-center gap-1.5 bg-glass-bg text-content-muted border border-border-subtle px-3 py-1.5 rounded-full text-xs font-medium">
                    Neutral
                  </div>
                </div>
              </div>
            </div>
          </section>

          {/* 6. Feedback & Components */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">06. Feedback & Components</h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              
              {/* Toast Example */}
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px] relative overflow-hidden">
                <div className="absolute inset-0 bg-gradient-to-br from-[#FF5A00]/5 to-transparent pointer-events-none" />
                
                <motion.div 
                  initial={{ y: 20, opacity: 0 }}
                  animate={{ y: 0, opacity: 1 }}
                  transition={{ delay: 0.5, type: "spring" }}
                  className="bg-surface-2 border border-border-subtle rounded-2xl p-4 flex items-center gap-4 shadow-2xl w-full max-w-sm z-10"
                >
                  <div className="w-10 h-10 rounded-full bg-emerald-500/20 flex items-center justify-center text-emerald-400 shrink-0">
                    <Check size={20} />
                  </div>
                  <div className="flex-1">
                    <div className="text-sm font-medium text-content-base">Update Successful</div>
                    <div className="text-xs text-content-muted mt-0.5">Your settings have been saved.</div>
                  </div>
                  <button className="text-content-muted hover:text-content-muted transition-colors">
                    <X size={16} />
                  </button>
                </motion.div>
              </div>

              {/* Progress & Loading */}
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle space-y-8">
                <div>
                  <div className="flex justify-between items-end mb-2">
                    <label className="block text-sm font-medium text-content-muted ml-1">Uploading File...</label>
                    <span className="text-xs font-mono text-[#FF5A00]">68%</span>
                  </div>
                  <div className="h-2 bg-glass-bg rounded-full overflow-hidden">
                    <motion.div 
                      initial={{ width: 0 }}
                      animate={{ width: "68%" }}
                      transition={{ duration: 1.5, ease: "easeOut" }}
                      className="h-full bg-[#FF5A00] rounded-full"
                    />
                  </div>
                </div>

                <div className="flex items-center gap-6 p-4 bg-surface-2 rounded-2xl border border-border-subtle">
                  <div className="relative w-12 h-12 flex items-center justify-center">
                    <svg className="w-full h-full animate-spin text-content-muted" viewBox="0 0 24 24">
                      <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="3" fill="none" />
                      <path className="opacity-75 text-[#C8FF00]" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                  </div>
                  <div>
                    <div className="text-sm font-medium text-content-base">Syncing Data</div>
                    <div className="text-xs text-content-muted mt-0.5">Please wait a moment</div>
                  </div>
                </div>
              </div>

            </div>
          </section>

          {/* 7. Advanced Animations */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">07. Advanced Animations</h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              
              {/* 3D Tilt Card */}
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex items-center justify-center min-h-[300px] perspective-[1000px]">
                <TiltCard />
              </div>

              <div className="flex flex-col gap-6">
                {/* Accordion & Staggered List */}
                <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col gap-6">
                  <div>
                    <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6">Accordion (Height Animation)</div>
                    <div className="space-y-3">
                      <Accordion title="What is this design system?" defaultOpen={true}>
                        This is a comprehensive UI/UX specification built with React and Framer Motion. It demonstrates fluid animations, micro-interactions, and a cohesive dark mode aesthetic.
                      </Accordion>
                      <Accordion title="How do the animations work?">
                        We use spring physics for most interactions to provide a natural, responsive feel. Layout animations handle size changes smoothly without jank.
                      </Accordion>
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6">Staggered Dropdown</div>
                    <StaggeredList />
                  </div>
                </div>

                {/* Skeletons & Charts */}
                <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle grid grid-cols-2 gap-6">
                  <div>
                    <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6">Skeleton Loader</div>
                    <div className="space-y-3">
                      <Skeleton className="w-12 h-12 rounded-full" />
                      <Skeleton className="w-full h-4" />
                      <Skeleton className="w-3/4 h-4" />
                    </div>
                  </div>
                  <div>
                    <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6">Live Data Chart</div>
                    <AnimatedBarChart />
                  </div>
                </div>
              </div>

            </div>
          </section>

          {/* 8. Navigation & Tabs */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">08. Navigation & Tabs</h2>
            <div className="flex flex-col gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px]">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6 text-left">Animated Pill Tabs</div>
                <AnimatedTabs />
              </div>
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px]">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6 text-left">macOS/iOS Glass Dock</div>
                <Dock />
              </div>
            </div>
          </section>

          {/* 9. Lists & Avatars */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">09. Lists & Avatars</h2>
            <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col justify-center gap-8">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Swipeable List Item</div>
                <SwipeableItem />
                <SwipeableItem />
              </div>
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col justify-center gap-8">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2">Avatar Stack</div>
                <div className="flex justify-center py-8">
                  <AvatarStack />
                </div>
              </div>
            </div>
          </section>

          {/* 10. Glassmorphism & Cards */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">10. Glassmorphism & Cards</h2>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6 text-left">Glassmorphism Panel</div>
                <GlassCard />
              </div>
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 mb-6 text-left">Spotlight Hover Card</div>
                <SpotlightCard />
              </div>
            </div>
          </section>

          {/* 11. Micro-interactions */}
          <section>
            <h2 className="text-sm font-mono text-content-muted uppercase tracking-widest mb-6">11. Micro-interactions</h2>
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px] gap-6">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 text-left">Particle Like Button</div>
                <LikeButton />
              </div>
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px] gap-6">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 text-left">Magnetic Button</div>
                <MagneticButton>Hover me</MagneticButton>
              </div>
              <div className="bg-surface-1 rounded-[32px] p-8 border border-border-subtle flex flex-col items-center justify-center min-h-[200px] gap-6">
                <div className="text-sm text-content-muted font-mono w-full border-b border-border-subtle pb-2 text-left">Shiny Text</div>
                <ShinyText text="Premium" />
              </div>
            </div>
          </section>

        </div>
      </motion.div>
    </AnimatePresence>
  );
}
