import React, { useState } from 'react';
import { motion, AnimatePresence } from 'framer-motion';
import { User, Plus, ChevronRight, Activity, Heart, Shield, Settings, Bell, Star } from 'lucide-react';
import { PetSilhouette } from './AddPetFlow';

const MOCK_PETS = [
  { id: '1', name: 'Max', species: 'dog', breed: 'Golden Retriever', age: '3 yrs', weight: '28kg', status: 'Healthy', color: '#FFB347', eyeColor: '#8B4513' },
  { id: '2', name: 'Luna', species: 'cat', breed: 'British Shorthair', age: '2 yrs', weight: '4.5kg', status: 'Vaccination Due', color: '#A9A9A9', eyeColor: '#FFD700' },
  { id: '3', name: 'Oreo', species: 'rabbit', breed: 'Holland Lop', age: '1 yr', weight: '1.2kg', status: 'Healthy', color: '#FFFFFF', eyeColor: '#FF0000' }
];

const MOCK_HUMANS = [
  { id: 'h1', name: 'Alex', role: 'Owner', avatar: 'https://i.pravatar.cc/150?u=alex' },
  { id: 'h2', name: 'Sarah', role: 'Co-owner', avatar: 'https://i.pravatar.cc/150?u=sarah' }
];

export default function FamilyOverview({ onAddPet }: { onAddPet: () => void }) {
  const [selectedEntity, setSelectedEntity] = useState<string | null>(null);

  return (
    <motion.div 
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0, y: -20 }}
      className="w-full h-full flex flex-col bg-[#0A0A0A] text-white overflow-y-auto pb-32"
    >
      {/* Header */}
      <div className="px-6 pt-12 pb-6 sticky top-0 bg-[#0A0A0A]/80 backdrop-blur-xl z-20 border-b border-white/10">
        <div className="flex justify-between items-center mb-2">
          <h1 className="text-3xl font-bold tracking-tight">Family</h1>
          <button className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center hover:bg-white/20 transition-colors">
            <Settings size={20} />
          </button>
        </div>
        <p className="text-gray-400 text-sm">Manage your pets and family members</p>
      </div>

      <div className="px-6 py-6 space-y-8">
        {/* Humans Section */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-200">Humans</h2>
            <button className="text-sm text-[#FF5A00] font-medium flex items-center gap-1">
              Invite <Plus size={16} />
            </button>
          </div>
          <div className="flex gap-4 overflow-x-auto pb-4 hide-scrollbar">
            {MOCK_HUMANS.map(human => (
              <motion.div 
                key={human.id}
                whileHover={{ y: -4 }}
                className="flex-shrink-0 w-24 flex flex-col items-center gap-2"
              >
                <div className="w-16 h-16 rounded-full overflow-hidden border-2 border-white/10 relative">
                  <img src={human.avatar} alt={human.name} className="w-full h-full object-cover" />
                  {human.role === 'Owner' && (
                    <div className="absolute bottom-0 right-0 w-5 h-5 bg-[#FF5A00] rounded-full border-2 border-[#0A0A0A] flex items-center justify-center">
                      <Star size={10} className="text-white" fill="currentColor" />
                    </div>
                  )}
                </div>
                <div className="text-center">
                  <div className="text-sm font-medium">{human.name}</div>
                  <div className="text-[10px] text-gray-500">{human.role}</div>
                </div>
              </motion.div>
            ))}
          </div>
        </section>

        {/* Pets Section */}
        <section>
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold text-gray-200">Pets</h2>
            <button 
              onClick={onAddPet}
              className="text-sm text-[#FF5A00] font-medium flex items-center gap-1"
            >
              Add Pet <Plus size={16} />
            </button>
          </div>
          
          <div className="space-y-4">
            {MOCK_PETS.map((pet, index) => (
              <motion.div
                key={pet.id}
                layoutId={`pet-card-${pet.id}`}
                onClick={() => setSelectedEntity(selectedEntity === pet.id ? null : pet.id)}
                className={`rounded-3xl border transition-all duration-300 overflow-hidden cursor-pointer ${
                  selectedEntity === pet.id 
                    ? 'bg-white/10 border-white/20 shadow-2xl' 
                    : 'bg-white/5 border-white/5 hover:bg-white/10'
                }`}
              >
                <div className="p-5 flex items-center gap-4">
                  <div className="w-16 h-16 rounded-2xl bg-white/10 flex items-center justify-center overflow-hidden relative">
                    <PetSilhouette 
                      species={pet.species as any} 
                      coatColor={pet.color} 
                      eyeColor={pet.eyeColor} 
                    />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center justify-between mb-1">
                      <h3 className="text-xl font-bold">{pet.name}</h3>
                      <div className={`px-2 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${
                        pet.status === 'Healthy' ? 'bg-green-500/20 text-green-400' : 'bg-yellow-500/20 text-yellow-400'
                      }`}>
                        {pet.status}
                      </div>
                    </div>
                    <p className="text-sm text-gray-400">{pet.breed} • {pet.age}</p>
                  </div>
                </div>

                <AnimatePresence>
                  {selectedEntity === pet.id && (
                    <motion.div
                      initial={{ height: 0, opacity: 0 }}
                      animate={{ height: 'auto', opacity: 1 }}
                      exit={{ height: 0, opacity: 0 }}
                      className="border-t border-white/10 bg-black/20"
                    >
                      <div className="p-5 grid grid-cols-3 gap-4">
                        <div className="flex flex-col items-center justify-center p-3 rounded-2xl bg-white/5">
                          <Activity size={20} className="text-[#FF5A00] mb-2" />
                          <div className="text-xs text-gray-400 mb-1">Activity</div>
                          <div className="font-semibold text-sm">High</div>
                        </div>
                        <div className="flex flex-col items-center justify-center p-3 rounded-2xl bg-white/5">
                          <Heart size={20} className="text-pink-500 mb-2" />
                          <div className="text-xs text-gray-400 mb-1">Health</div>
                          <div className="font-semibold text-sm">98%</div>
                        </div>
                        <div className="flex flex-col items-center justify-center p-3 rounded-2xl bg-white/5">
                          <Shield size={20} className="text-blue-500 mb-2" />
                          <div className="text-xs text-gray-400 mb-1">Vaccines</div>
                          <div className="font-semibold text-sm">Up to date</div>
                        </div>
                      </div>
                      <div className="px-5 pb-5 flex justify-end">
                        <button className="flex items-center gap-1 text-sm font-medium text-white/70 hover:text-white transition-colors">
                          View Full Profile <ChevronRight size={16} />
                        </button>
                      </div>
                    </motion.div>
                  )}
                </AnimatePresence>
              </motion.div>
            ))}
          </div>
        </section>
      </div>
    </motion.div>
  );
}
