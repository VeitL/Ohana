import { useState } from "react";
import PetDashboard from "./components/PetDashboard";
import DesignSystem from "./components/DesignSystem";
import { Sparkles } from "lucide-react";

export default function App() {
  const [showDesignSystem, setShowDesignSystem] = useState(false);

  return (
    <div className="min-h-screen bg-[#F5F5F7] text-[#1C1C1E] flex flex-col font-sans selection:bg-[#FF5A00]/30 transition-colors duration-300">
      {/* Header for Design System Toggle (Optional, kept for utility) */}
      <header className="w-full p-4 flex items-center justify-end z-40 bg-transparent absolute top-0 pointer-events-none">
        <button 
          onClick={() => setShowDesignSystem(true)}
          className="pointer-events-auto flex items-center gap-2 px-3 py-1.5 rounded-full bg-white/80 backdrop-blur-md border border-[#E5E5EA] hover:bg-white transition-colors text-xs font-medium text-[#FF5A00] shadow-sm"
        >
          <Sparkles size={14} />
          UI Spec
        </button>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 relative overflow-hidden flex items-center justify-center h-screen">
        <PetDashboard />
      </main>

      {/* Design System Overlay */}
      {showDesignSystem && <DesignSystem onClose={() => setShowDesignSystem(false)} />}
    </div>
  );
}
