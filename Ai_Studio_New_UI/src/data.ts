export interface CardData {
  id: string;
  title: string;
  subtitle: string;
  image: string;
  color: string;
}

export const cards: CardData[] = [
  {
    id: "1",
    title: "Neon Nights",
    subtitle: "Cyberpunk Cityscapes",
    image: "https://picsum.photos/seed/neon/800/1200",
    color: "from-purple-500 to-indigo-600",
  },
  {
    id: "2",
    title: "Serene Peaks",
    subtitle: "Mountain Escapes",
    image: "https://picsum.photos/seed/mountain/800/1200",
    color: "from-emerald-400 to-teal-600",
  },
  {
    id: "3",
    title: "Urban Pulse",
    subtitle: "Street Photography",
    image: "https://picsum.photos/seed/urban/800/1200",
    color: "from-orange-400 to-red-600",
  },
  {
    id: "4",
    title: "Ocean Deep",
    subtitle: "Marine Life",
    image: "https://picsum.photos/seed/ocean/800/1200",
    color: "from-blue-400 to-cyan-600",
  },
  {
    id: "5",
    title: "Desert Sands",
    subtitle: "Golden Dunes",
    image: "https://picsum.photos/seed/desert/800/1200",
    color: "from-yellow-400 to-orange-500",
  },
];
