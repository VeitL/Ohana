import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { 
  ChevronLeft, Camera, Image as ImageIcon, Clipboard, X, 
  Check, Search, Calendar, MapPin, FileText, Palette, Users,
  PawPrint, Info, ShieldCheck, CheckCircle2, Sparkles
} from 'lucide-react';

const SPECIES = [
  { id: 'dog', icon: '🐶', label: 'Dog' },
  { id: 'cat', icon: '🐱', label: 'Cat' },
  { id: 'rabbit', icon: '🐰', label: 'Rabbit' },
  { id: 'hamster', icon: '🐹', label: 'Hamster' },
  { id: 'bird', icon: '🦜', label: 'Bird' },
  { id: 'other', icon: '🐾', label: 'Other' },
];

const MOCK_BREEDS: Record<string, string[]> = {
  dog: ['Golden Retriever', 'Labrador', 'French Bulldog', 'Poodle', 'German Shepherd', 'Shiba Inu', 'Corgi'],
  cat: ['British Shorthair', 'Ragdoll', 'Siamese', 'Persian', 'Maine Coon', 'Sphynx', 'Scottish Fold'],
};

const COLORS = [
  { id: 'orange', hex: '#FF9500', name: 'Orange' },
  { id: 'black', hex: '#1C1C1E', name: 'Black' },
  { id: 'white', hex: '#F5F5F7', name: 'White' },
  { id: 'brown', hex: '#A2845E', name: 'Brown' },
  { id: 'gray', hex: '#8E8E93', name: 'Gray' },
  { id: 'mixed', hex: 'linear-gradient(45deg, #FF9500, #1C1C1E)', name: 'Mixed' },
];

const EYE_COLORS = [
  { id: 'blue', hex: '#4A90E2', name: 'Blue' },
  { id: 'green', hex: '#34C759', name: 'Green' },
  { id: 'brown', hex: '#8B4513', name: 'Brown' },
  { id: 'yellow', hex: '#FFCC00', name: 'Yellow' },
  { id: 'black', hex: '#1C1C1E', name: 'Black' },
];

export const PetSilhouette = ({ species, coatColor, eyeColor, onEyeClick, onBodyClick, className = "w-full h-full" }: { species: string, coatColor: string, eyeColor: string, onEyeClick?: (e: React.MouseEvent) => void, onBodyClick?: (e: React.MouseEvent) => void, className?: string }) => {
  const coatHex = COLORS.find(c => c.id === coatColor)?.hex || '#E5E5EA';
  const eyeHex = EYE_COLORS.find(c => c.id === eyeColor)?.hex || '#1C1C1E';
  const actualCoatHex = coatColor === 'mixed' ? 'url(#mixed-coat)' : coatHex;

  const renderShape = () => {
    switch(species) {
      case 'cat':
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,80 C25,50 40,30 50,30 C60,30 75,50 75,80 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,45 C30,25 70,25 70,45 C70,60 30,60 30,45 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,35 L25,15 L45,25 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M70,35 L75,15 L55,25 Z" />
              <path d="M32,32 L28,20 L40,26 Z" fill="#FFB6C1" opacity="0.8" />
              <path d="M68,32 L72,20 L60,26 Z" fill="#FFB6C1" opacity="0.8" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="40" cy="40" r="6" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="60" cy="40" r="6" />
              <circle cx="38" cy="38" r="2" fill="white" />
              <circle cx="58" cy="38" r="2" fill="white" />
            </g>
            <g className="pointer-events-none">
              <path d="M48,48 L52,48 L50,51 Z" fill="#FFB6C1" />
              <path d="M50,51 Q45,55 40,52" stroke="#333" strokeWidth="1.5" fill="none" strokeLinecap="round" />
              <path d="M50,51 Q55,55 60,52" stroke="#333" strokeWidth="1.5" fill="none" strokeLinecap="round" />
            </g>
          </svg>
        );
      case 'dog':
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,80 C25,50 40,35 50,35 C60,35 75,50 75,80 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,45 C25,20 75,20 75,45 C75,65 25,65 25,45 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,35 C15,35 15,60 25,60 C30,60 30,45 25,35 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M75,35 C85,35 85,60 75,60 C70,60 70,45 75,35 Z" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="38" cy="42" r="5" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="62" cy="42" r="5" />
              <circle cx="36" cy="40" r="1.5" fill="white" />
              <circle cx="60" cy="40" r="1.5" fill="white" />
            </g>
            <g className="pointer-events-none">
              <ellipse cx="50" cy="52" rx="6" ry="4" fill="#333" />
              <path d="M50,56 Q50,62 42,60" stroke="#333" strokeWidth="1.5" fill="none" strokeLinecap="round" />
              <path d="M50,56 Q50,62 58,60" stroke="#333" strokeWidth="1.5" fill="none" strokeLinecap="round" />
              <path d="M46,60 Q50,66 54,60" fill="#FFB6C1" />
            </g>
          </svg>
        );
      case 'rabbit':
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,80 C30,55 40,40 50,40 C60,40 70,55 70,80 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,50 C30,30 70,30 70,50 C70,65 30,65 30,50 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M35,35 C30,10 40,5 45,30 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M65,35 C70,10 60,5 55,30 Z" />
              <path d="M37,32 C34,15 40,12 43,28 Z" fill="#FFB6C1" opacity="0.8" />
              <path d="M63,32 C66,15 60,12 57,28 Z" fill="#FFB6C1" opacity="0.8" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="38" cy="48" r="4" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="62" cy="48" r="4" />
              <circle cx="37" cy="47" r="1" fill="white" />
              <circle cx="61" cy="47" r="1" fill="white" />
            </g>
            <g className="pointer-events-none">
              <path d="M48,54 L52,54 L50,57 Z" fill="#FFB6C1" />
              <path d="M50,57 Q45,60 42,58" stroke="#333" strokeWidth="1" fill="none" strokeLinecap="round" />
              <path d="M50,57 Q55,60 58,58" stroke="#333" strokeWidth="1" fill="none" strokeLinecap="round" />
            </g>
          </svg>
        );
      case 'bird':
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,60 C30,30 70,30 70,60 C70,80 30,80 30,60 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M30,55 C20,65 20,75 35,70 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M70,55 C80,65 80,75 65,70 Z" />
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M40,75 L50,90 L60,75 Z" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="40" cy="48" r="4" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="60" cy="48" r="4" />
              <circle cx="39" cy="47" r="1.5" fill="white" />
              <circle cx="59" cy="47" r="1.5" fill="white" />
            </g>
            <g className="pointer-events-none">
              <path d="M45,55 L55,55 L50,65 Z" fill="#FF9500" />
            </g>
          </svg>
        );
      case 'hamster':
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,65 C25,30 75,30 75,65 C75,90 25,90 25,65 Z" />
              <motion.circle animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} cx="30" cy="35" r="10" />
              <motion.circle animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} cx="70" cy="35" r="10" />
              <circle cx="30" cy="35" r="6" fill="#FFB6C1" opacity="0.8" />
              <circle cx="70" cy="35" r="6" fill="#FFB6C1" opacity="0.8" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="38" cy="50" r="5" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="62" cy="50" r="5" />
              <circle cx="37" cy="48" r="1.5" fill="white" />
              <circle cx="61" cy="48" r="1.5" fill="white" />
            </g>
            <g className="pointer-events-none">
              <ellipse cx="50" cy="58" rx="3" ry="2" fill="#FFB6C1" />
              <path d="M50,60 Q45,65 40,62" stroke="#333" strokeWidth="1" fill="none" strokeLinecap="round" />
              <path d="M50,60 Q55,65 60,62" stroke="#333" strokeWidth="1" fill="none" strokeLinecap="round" />
              <circle cx="30" cy="60" r="4" fill="#FFB6C1" opacity="0.5" />
              <circle cx="70" cy="60" r="4" fill="#FFB6C1" opacity="0.5" />
            </g>
          </svg>
        );
      default:
        return (
          <svg viewBox="0 0 100 100" className={`${className} drop-shadow-xl`}>
            <g onClick={onBodyClick} className="cursor-pointer">
              <motion.path animate={{ fill: actualCoatHex }} transition={{ duration: 0.4 }} d="M25,60 C25,20 75,20 75,60 C75,90 25,90 25,60 Z" />
            </g>
            <g onClick={onEyeClick} className="cursor-pointer">
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="35" cy="45" r="6" />
              <motion.circle animate={{ fill: eyeHex }} transition={{ duration: 0.4 }} cx="65" cy="45" r="6" />
              <circle cx="33" cy="43" r="2" fill="white" />
              <circle cx="63" cy="43" r="2" fill="white" />
            </g>
            <g className="pointer-events-none">
              <circle cx="50" cy="55" r="4" fill="#333" />
            </g>
          </svg>
        );
    }
  };

  return (
    <motion.div 
      animate={{ y: [0, -8, 0], rotate: [-1, 1, -1] }} 
      transition={{ duration: 4, repeat: Infinity, ease: "easeInOut" }}
      className="w-full h-full relative z-10"
    >
      <svg width="0" height="0" className="absolute">
        <defs>
          <linearGradient id="mixed-coat" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#FF9500" />
            <stop offset="100%" stopColor="#1C1C1E" />
          </linearGradient>
        </defs>
      </svg>
      {renderShape()}
    </motion.div>
  );
};

interface AddPetFlowProps {
  onClose: () => void;
  onComplete: (data: any) => void;
}

export default function AddPetFlow({ onClose, onComplete }: AddPetFlowProps) {
  const [step, setStep] = useState(0);
  const [direction, setDirection] = useState(1);
  const [activePicker, setActivePicker] = useState<'coat' | 'eye' | null>(null);
  const [formData, setFormData] = useState({
    name: '',
    species: '',
    breed: '',
    avatar: '',
    birthday: '',
    gotchaDay: '',
    gender: '',
    neutered: false,
    country: '',
    city: '',
    passport: '',
    microchip: '',
    coatColor: '',
    eyeColor: '',
    themeColor: '#FF5A00',
    familyRelations: []
  });

  const nextStep = () => {
    if (step < 9) {
      setDirection(1);
      setStep(s => s + 1);
    } else {
      onComplete(formData);
    }
  };

  const prevStep = () => {
    if (step > 0) {
      setDirection(-1);
      setStep(s => s - 1);
    } else {
      onClose();
    }
  };

  const updateData = (fields: Partial<typeof formData>) => {
    setFormData(prev => ({ ...prev, ...fields }));
  };

  const slideVariants = {
    enter: (dir: number) => ({
      x: dir > 0 ? '100%' : '-100%',
      opacity: 0
    }),
    center: {
      x: 0,
      opacity: 1
    },
    exit: (dir: number) => ({
      x: dir < 0 ? '100%' : '-100%',
      opacity: 0
    })
  };

  const renderStep = () => {
    switch (step) {
      case 0:
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold mb-2">Let's meet your pet!</h2>
              <p className="text-[#8E8E93] text-sm">What's their name and species?</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Pet Name <span className="text-red-500">*</span></label>
                <div className="relative">
                  <input 
                    type="text" 
                    value={formData.name}
                    onChange={(e) => updateData({ name: e.target.value })}
                    placeholder="e.g. Luna"
                    className="w-full bg-[#F5F5F7] rounded-2xl px-4 py-4 text-lg font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00] transition-all"
                  />
                  {formData.name && (
                    <div className="absolute right-4 top-1/2 -translate-y-1/2 text-[#34C759] flex items-center gap-1 text-xs font-bold">
                      <CheckCircle2 size={16} /> Unique
                    </div>
                  )}
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Species</label>
                <div className="grid grid-cols-3 gap-3">
                  {SPECIES.map(s => (
                    <button
                      key={s.id}
                      onClick={() => updateData({ species: s.id, breed: '' })}
                      className={`flex flex-col items-center justify-center p-4 rounded-2xl border-2 transition-all ${
                        formData.species === s.id 
                          ? 'border-[#FF5A00] bg-[#FFF0E5] text-[#FF5A00]' 
                          : 'border-transparent bg-[#F5F5F7] text-[#8E8E93] hover:bg-gray-200'
                      }`}
                    >
                      <span className="text-3xl mb-2">{s.icon}</span>
                      <span className="text-xs font-bold">{s.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            </div>
          </div>
        );
      case 1:
        const breeds = MOCK_BREEDS[formData.species] || ['Mixed Breed', 'Unknown'];
        return (
          <div className="space-y-6 h-full flex flex-col">
            <div>
              <h2 className="text-2xl font-bold mb-2">What breed is {formData.name || 'your pet'}?</h2>
              <p className="text-[#8E8E93] text-sm">Select from the database or type your own.</p>
            </div>
            <div className="relative">
              <Search className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
              <input 
                type="text" 
                placeholder="Search breeds..."
                className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
              />
            </div>
            <div className="flex-1 overflow-y-auto space-y-2 pb-20">
              {breeds.map(b => (
                <button
                  key={b}
                  onClick={() => updateData({ breed: b })}
                  className={`w-full text-left px-6 py-4 rounded-2xl font-medium transition-all ${
                    formData.breed === b ? 'bg-[#FF5A00] text-white shadow-md' : 'bg-[#F5F5F7] text-[#1C1C1E] hover:bg-gray-200'
                  }`}
                >
                  {b}
                </button>
              ))}
            </div>
          </div>
        );
      case 2:
        return (
          <div className="space-y-8">
            <div>
              <h2 className="text-2xl font-bold mb-2">Set an Avatar</h2>
              <p className="text-[#8E8E93] text-sm">Show off {formData.name || 'your pet'}'s best look!</p>
            </div>
            <div className="flex justify-center">
              <div className="w-48 h-48 rounded-full bg-[#F5F5F7] border-4 border-dashed border-gray-300 flex items-center justify-center relative overflow-hidden">
                {formData.avatar ? (
                  <img src={formData.avatar} alt="Avatar" className="w-full h-full object-cover" />
                ) : (
                  <div className="w-32 h-32 opacity-50">
                    <PetSilhouette 
                      species={formData.species} 
                      coatColor={formData.coatColor} 
                      eyeColor={formData.eyeColor} 
                    />
                  </div>
                )}
              </div>
            </div>
            <div className="grid grid-cols-3 gap-4">
              <button className="flex flex-col items-center gap-2 p-4 bg-[#F5F5F7] rounded-2xl hover:bg-gray-200 transition-colors">
                <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[#FF5A00] shadow-sm"><Camera size={24} /></div>
                <span className="text-xs font-bold">Camera</span>
              </button>
              <button className="flex flex-col items-center gap-2 p-4 bg-[#F5F5F7] rounded-2xl hover:bg-gray-200 transition-colors">
                <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[#4A90E2] shadow-sm"><ImageIcon size={24} /></div>
                <span className="text-xs font-bold">Photos</span>
              </button>
              <button className="flex flex-col items-center gap-2 p-4 bg-[#F5F5F7] rounded-2xl hover:bg-gray-200 transition-colors">
                <div className="w-12 h-12 bg-white rounded-full flex items-center justify-center text-[#34C759] shadow-sm"><Clipboard size={24} /></div>
                <span className="text-xs font-bold">Paste</span>
              </button>
            </div>
            <div className="bg-[#FFF0E5] p-4 rounded-2xl flex items-start gap-3 text-[#FF5A00]">
              <Sparkles size={20} className="shrink-0 mt-0.5" />
              <p className="text-xs font-medium leading-relaxed">
                <strong>Smart Cutout:</strong> We'll automatically remove the background to create a perfect sticker of your pet!
              </p>
            </div>
          </div>
        );
      case 3:
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold mb-2">Important Dates</h2>
              <p className="text-[#8E8E93] text-sm">We'll calculate their age automatically.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Birthday</label>
                <div className="relative">
                  <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="date" 
                    value={formData.birthday}
                    onChange={(e) => updateData({ birthday: e.target.value })}
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
                {formData.birthday && (
                  <p className="text-xs text-[#FF5A00] font-bold mt-2 ml-2">≈ 2 human years old</p>
                )}
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Gotcha Day (Adoption Day)</label>
                <div className="relative">
                  <Calendar className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="date" 
                    value={formData.gotchaDay}
                    onChange={(e) => updateData({ gotchaDay: e.target.value })}
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
              </div>
            </div>
          </div>
        );
      case 4:
        return (
          <div className="space-y-8">
            <div>
              <h2 className="text-2xl font-bold mb-2">Gender & Health</h2>
              <p className="text-[#8E8E93] text-sm">Basic health profile.</p>
            </div>
            <div>
              <label className="block text-sm font-medium mb-4">Gender</label>
              <div className="grid grid-cols-3 gap-3">
                {[
                  { id: 'boy', label: 'Boy', icon: '♂️', color: 'bg-[#E5F0FF] text-[#4A90E2] border-[#4A90E2]' },
                  { id: 'girl', label: 'Girl', icon: '♀️', color: 'bg-[#FFE5F0] text-[#FF2D55] border-[#FF2D55]' },
                  { id: 'unknown', label: 'Unknown', icon: '❓', color: 'bg-[#F5F5F7] text-[#8E8E93] border-transparent' }
                ].map(g => (
                  <button
                    key={g.id}
                    onClick={() => updateData({ gender: g.id })}
                    className={`flex flex-col items-center justify-center p-4 rounded-2xl border-2 transition-all ${
                      formData.gender === g.id ? g.color : 'border-transparent bg-[#F5F5F7] text-[#8E8E93]'
                    }`}
                  >
                    <span className="text-2xl mb-1">{g.icon}</span>
                    <span className="text-xs font-bold">{g.label}</span>
                  </button>
                ))}
              </div>
            </div>
            <div className="bg-[#F5F5F7] p-4 rounded-2xl flex justify-between items-center">
              <div>
                <h4 className="font-bold text-[#1C1C1E]">Neutered / Spayed</h4>
                <p className="text-xs text-[#8E8E93]">Has {formData.name || 'your pet'} been fixed?</p>
              </div>
              <button 
                onClick={() => updateData({ neutered: !formData.neutered })}
                className={`w-14 h-8 rounded-full p-1 transition-colors ${formData.neutered ? 'bg-[#34C759]' : 'bg-gray-300'}`}
              >
                <motion.div 
                  layout
                  className="w-6 h-6 bg-white rounded-full shadow-sm"
                  animate={{ x: formData.neutered ? 24 : 0 }}
                />
              </button>
            </div>
          </div>
        );
      case 5:
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold mb-2">Birthplace</h2>
              <p className="text-[#8E8E93] text-sm">Where is {formData.name || 'your pet'} from?</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Country</label>
                <div className="relative">
                  <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="text" 
                    value={formData.country}
                    onChange={(e) => updateData({ country: e.target.value })}
                    placeholder="e.g. United Kingdom"
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">City</label>
                <div className="relative">
                  <MapPin className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="text" 
                    value={formData.city}
                    onChange={(e) => updateData({ city: e.target.value })}
                    placeholder="e.g. London"
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
              </div>
            </div>
          </div>
        );
      case 6:
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold mb-2">Documents</h2>
              <p className="text-[#8E8E93] text-sm">Keep their IDs handy.</p>
            </div>
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium mb-2">Passport Number</label>
                <div className="relative">
                  <FileText className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="text" 
                    value={formData.passport}
                    onChange={(e) => updateData({ passport: e.target.value })}
                    placeholder="Optional"
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
              </div>
              <div>
                <label className="block text-sm font-medium mb-2">Microchip (15 digits)</label>
                <div className="relative">
                  <ShieldCheck className="absolute left-4 top-1/2 -translate-y-1/2 text-[#8E8E93]" size={20} />
                  <input 
                    type="text" 
                    value={formData.microchip}
                    onChange={(e) => updateData({ microchip: e.target.value })}
                    placeholder="e.g. 981020000000000"
                    maxLength={15}
                    className="w-full bg-[#F5F5F7] rounded-2xl pl-12 pr-4 py-4 font-medium focus:outline-none focus:ring-2 focus:ring-[#FF5A00]"
                  />
                </div>
              </div>
            </div>
          </div>
        );
      case 7:
        return (
          <motion.div 
            initial="hidden"
            animate="visible"
            variants={{
              visible: { transition: { staggerChildren: 0.1 } }
            }}
            className="space-y-6 pb-10"
          >
            <motion.div variants={{ hidden: { opacity: 0, y: 20 }, visible: { opacity: 1, y: 0 } }}>
              <h2 className="text-2xl font-bold mb-2">Appearance</h2>
              <p className="text-[#8E8E93] text-sm">Tap the silhouette to customize.</p>
            </motion.div>

            <motion.div 
              variants={{ hidden: { opacity: 0, scale: 0.9 }, visible: { opacity: 1, scale: 1 } }}
              className="bg-[#F5F5F7] rounded-3xl p-6 flex flex-col items-center justify-center relative overflow-hidden mt-4 min-h-[300px]"
            >
              <motion.div 
                animate={{ backgroundColor: formData.themeColor }}
                transition={{ duration: 0.5 }}
                className="absolute inset-0 opacity-20" 
              />
              <motion.div
                animate={{ 
                  scale: [1, 1.2, 1],
                  opacity: [0.3, 0.6, 0.3]
                }}
                transition={{ duration: 3, repeat: Infinity, ease: "easeInOut" }}
                className="absolute w-48 h-48 rounded-full blur-3xl"
                style={{ backgroundColor: formData.themeColor }}
              />
              
              <div className="w-48 h-48 relative z-10">
                <PetSilhouette 
                  species={formData.species} 
                  coatColor={formData.coatColor} 
                  eyeColor={formData.eyeColor}
                  onEyeClick={(e) => {
                    e.stopPropagation();
                    setActivePicker('eye');
                  }}
                  onBodyClick={(e) => {
                    e.stopPropagation();
                    setActivePicker('coat');
                  }}
                />
              </div>
              
              <AnimatePresence>
                {activePicker === 'coat' && (
                  <motion.div 
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 20 }}
                    className="absolute bottom-4 left-4 right-4 bg-white/90 backdrop-blur-md p-4 rounded-2xl shadow-xl z-20"
                  >
                    <div className="flex justify-between items-center mb-3">
                      <span className="text-sm font-bold">Coat Color</span>
                      <button onClick={() => setActivePicker(null)} className="p-1 bg-gray-100 rounded-full"><X size={14} /></button>
                    </div>
                    <div className="flex flex-wrap gap-2 justify-center">
                      {COLORS.map(c => (
                        <motion.button
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          key={c.id}
                          onClick={() => updateData({ coatColor: c.id })}
                          className={`w-8 h-8 rounded-full border-2 transition-colors ${formData.coatColor === c.id ? 'border-[#FF5A00]' : 'border-transparent shadow-sm'}`}
                          style={{ background: c.hex }}
                        />
                      ))}
                    </div>
                  </motion.div>
                )}

                {activePicker === 'eye' && (
                  <motion.div 
                    initial={{ opacity: 0, y: 20 }}
                    animate={{ opacity: 1, y: 0 }}
                    exit={{ opacity: 0, y: 20 }}
                    className="absolute bottom-4 left-4 right-4 bg-white/90 backdrop-blur-md p-4 rounded-2xl shadow-xl z-20"
                  >
                    <div className="flex justify-between items-center mb-3">
                      <span className="text-sm font-bold">Eye Color</span>
                      <button onClick={() => setActivePicker(null)} className="p-1 bg-gray-100 rounded-full"><X size={14} /></button>
                    </div>
                    <div className="flex flex-wrap gap-2 justify-center">
                      {EYE_COLORS.map(c => (
                        <motion.button
                          whileHover={{ scale: 1.1 }}
                          whileTap={{ scale: 0.9 }}
                          key={c.id}
                          onClick={() => updateData({ eyeColor: c.id })}
                          className={`w-8 h-8 rounded-full border-2 transition-colors ${formData.eyeColor === c.id ? 'border-[#FF5A00]' : 'border-transparent shadow-sm'}`}
                          style={{ background: c.hex }}
                        />
                      ))}
                    </div>
                  </motion.div>
                )}
              </AnimatePresence>

              <motion.p 
                animate={{ color: formData.themeColor }}
                className="mt-4 font-bold relative z-10"
              >
                {activePicker ? 'Select a color' : 'Tap eyes or body to edit'}
              </motion.p>
            </motion.div>

            <motion.div variants={{ hidden: { opacity: 0, y: 20 }, visible: { opacity: 1, y: 0 } }}>
              <label className="block text-sm font-medium mb-3">Profile Theme Color</label>
              <div className="flex gap-3">
                {['#FF5A00', '#4A90E2', '#34C759', '#5856D6', '#FF2D55'].map(color => (
                  <motion.button
                    whileHover={{ scale: 1.1 }}
                    whileTap={{ scale: 0.9 }}
                    key={color}
                    onClick={() => updateData({ themeColor: color })}
                    className={`w-8 h-8 rounded-full border-2 transition-colors ${formData.themeColor === color ? 'border-black' : 'border-transparent shadow-sm'}`}
                    style={{ backgroundColor: color }}
                  />
                ))}
              </div>
            </motion.div>
          </motion.div>
        );
      case 8:
        return (
          <div className="space-y-6">
            <div>
              <h2 className="text-2xl font-bold mb-2">Family Relations</h2>
              <p className="text-[#8E8E93] text-sm">Does {formData.name || 'your pet'} have siblings here?</p>
            </div>
            
            <div className="bg-[#F5F5F7] rounded-2xl p-8 text-center flex flex-col items-center justify-center border-2 border-dashed border-gray-300">
              <Users size={48} className="text-gray-300 mb-4" />
              <h4 className="font-bold text-[#1C1C1E] mb-1">No other pets yet</h4>
              <p className="text-xs text-[#8E8E93]">Add more pets later to build their family tree!</p>
            </div>
          </div>
        );
      case 9:
        return (
          <div className="space-y-6 h-full flex flex-col">
            <div>
              <h2 className="text-2xl font-bold mb-2">All Set!</h2>
              <p className="text-[#8E8E93] text-sm">Here is {formData.name || 'your pet'}'s new ID card.</p>
            </div>
            
            <div className="flex-1 flex items-center justify-center py-8">
              <motion.div 
                initial={{ scale: 0.8, rotateY: 90 }}
                animate={{ scale: 1, rotateY: 0 }}
                transition={{ type: "spring", damping: 20, stiffness: 100 }}
                className="w-full aspect-[1.6/1] rounded-3xl shadow-2xl p-6 relative overflow-hidden text-white flex flex-col justify-between"
                style={{ backgroundColor: formData.themeColor }}
              >
                <div className="absolute top-0 right-0 w-64 h-64 bg-white/10 rounded-full blur-3xl -translate-y-1/2 translate-x-1/4" />
                
                <div className="flex justify-between items-start relative z-10">
                  <div>
                    <h3 className="text-3xl font-black uppercase tracking-tight">{formData.name || 'Pet Name'}</h3>
                    <p className="font-medium opacity-90">{formData.breed || 'Mixed Breed'}</p>
                  </div>
                  <div className="w-16 h-16 bg-white/20 backdrop-blur-md rounded-full flex items-center justify-center border border-white/30 overflow-hidden">
                    {formData.avatar ? (
                      <img src={formData.avatar} alt="Avatar" className="w-full h-full object-cover" />
                    ) : (
                      <div className="w-12 h-12">
                        <PetSilhouette 
                          species={formData.species} 
                          coatColor={formData.coatColor} 
                          eyeColor={formData.eyeColor} 
                        />
                      </div>
                    )}
                  </div>
                </div>

                <div className="grid grid-cols-3 gap-4 relative z-10">
                  <div>
                    <p className="text-[10px] uppercase tracking-wider opacity-70 mb-1">Species</p>
                    <p className="font-bold text-sm capitalize">{formData.species || 'Unknown'}</p>
                  </div>
                  <div>
                    <p className="text-[10px] uppercase tracking-wider opacity-70 mb-1">Gender</p>
                    <p className="font-bold text-sm capitalize">{formData.gender || 'Unknown'}</p>
                  </div>
                  <div>
                    <p className="text-[10px] uppercase tracking-wider opacity-70 mb-1">Birthplace</p>
                    <p className="font-bold text-sm truncate">{formData.city || 'Unknown'}</p>
                  </div>
                </div>
              </motion.div>
            </div>
          </div>
        );
      default:
        return null;
    }
  };

  return (
    <motion.div 
      initial={{ opacity: 0, y: '100%' }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: '100%' }}
      transition={{ type: 'spring', damping: 25, stiffness: 200 }}
      className="fixed inset-0 z-[100] bg-white flex flex-col font-sans"
    >
      {/* Header */}
      <div className="flex items-center justify-between p-6 pb-2">
        <button 
          onClick={prevStep}
          className="w-10 h-10 rounded-full bg-[#F5F5F7] flex items-center justify-center hover:bg-gray-200 transition-colors"
        >
          {step === 0 ? <X size={20} /> : <ChevronLeft size={20} />}
        </button>
        
        <div className="flex gap-1">
          {Array.from({ length: 10 }).map((_, i) => (
            <div 
              key={i} 
              className={`h-1.5 rounded-full transition-all duration-300 ${
                i === step ? 'w-6 bg-[#FF5A00]' : i < step ? 'w-2 bg-[#FF5A00]/40' : 'w-2 bg-gray-200'
              }`} 
            />
          ))}
        </div>

        <div className="w-10" /> {/* Spacer for centering */}
      </div>

      {/* Content Area */}
      <div className="flex-1 overflow-hidden relative px-6 py-4">
        <AnimatePresence initial={false} custom={direction} mode="wait">
          <motion.div
            key={step}
            custom={direction}
            variants={slideVariants}
            initial="enter"
            animate="center"
            exit="exit"
            transition={{ type: "spring", stiffness: 300, damping: 30 }}
            className="absolute inset-0 px-6 py-4 h-full"
          >
            {renderStep()}
          </motion.div>
        </AnimatePresence>
      </div>

      {/* Footer / Next Button */}
      <div className="p-6 bg-white border-t border-gray-100">
        <button 
          onClick={nextStep}
          disabled={step === 0 && !formData.name}
          className={`w-full py-4 rounded-full font-bold text-lg transition-all flex items-center justify-center gap-2 ${
            (step === 0 && !formData.name) 
              ? 'bg-gray-200 text-gray-400 cursor-not-allowed' 
              : 'bg-[#1C1C1E] text-white hover:bg-black active:scale-[0.98]'
          }`}
        >
          {step === 9 ? (
            <>Complete <Check size={20} /></>
          ) : (
            'Continue'
          )}
        </button>
      </div>
    </motion.div>
  );
}
