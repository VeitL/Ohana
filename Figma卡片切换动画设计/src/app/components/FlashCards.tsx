import { useState, useRef } from "react";
import { motion, useMotionValue, useTransform, animate } from "motion/react";
import { Volume2, ChevronLeft, ChevronRight, RefreshCw } from "lucide-react";

interface Card {
  id: number;
  word: string;
  partOfSpeech: string;
  phonetic: string;
  translation: string;
  example?: string;
  color: [string, string];
}

const CARDS: Card[] = [
  {
    id: 1,
    word: "bestemming",
    partOfSpeech: "fn",
    phonetic: "bə'stɛ.mɪŋ",
    translation: "destination, final stop",
    example: "Wat is je bestemming?",
    color: ["#3d5af1", "#2541c4"],
  },
  {
    id: 2,
    word: "avontuur",
    partOfSpeech: "zn",
    phonetic: "ˌa.vɔn'tyːr",
    translation: "adventure, journey",
    example: "Het was een groot avontuur.",
    color: ["#7c3aed", "#5b21b6"],
  },
  {
    id: 3,
    word: "vriendelijk",
    partOfSpeech: "bn",
    phonetic: "'vrindələk",
    translation: "friendly, kind",
    example: "Ze is altijd vriendelijk.",
    color: ["#0ea5e9", "#0369a1"],
  },
  {
    id: 4,
    word: "verbeelding",
    partOfSpeech: "fn",
    phonetic: "vər'beːldɪŋ",
    translation: "imagination, fantasy",
    example: "Gebruik je verbeelding!",
    color: ["#10b981", "#047857"],
  },
  {
    id: 5,
    word: "ontdekking",
    partOfSpeech: "fn",
    phonetic: "ɔnt'dɛkɪŋ",
    translation: "discovery, finding",
    example: "Een geweldige ontdekking.",
    color: ["#f59e0b", "#b45309"],
  },
  {
    id: 6,
    word: "zonsondergang",
    partOfSpeech: "zn",
    phonetic: "'zɔnsɔndərɣɑŋ",
    translation: "sunset, sundown",
    example: "De zonsondergang was prachtig.",
    color: ["#ef4444", "#b91c1c"],
  },
];

// How many cards are visible in the stack at once (top + behind)
const VISIBLE = 3;

// Visual style for a given depth in the stack (0 = top, 1 = 2nd, 2 = 3rd…)
function depthStyle(d: number) {
  return {
    scale: 1 - d * 0.045,
    y: d * 16,
    rotate: d * -2,
  };
}

// The "back of stack" visual target for returning cards
const BACK_DEPTH = depthStyle(VISIBLE - 1);

// ─── Card face ────────────────────────────────────────────────────────────────

function CardFace({ card, onSound }: { card: Card; onSound: () => void }) {
  return (
    <div className="relative w-full h-full flex flex-col p-8 select-none overflow-hidden">
      {/* Decorative blob top-left */}
      <div
        className="absolute top-0 left-0 w-52 h-52 rounded-full pointer-events-none"
        style={{
          background: "rgba(255,255,255,0.22)",
          transform: "translate(-35%,-35%)",
          filter: "blur(1px)",
        }}
      />
      {/* Decorative blob bottom-right */}
      <div
        className="absolute bottom-0 right-0 w-40 h-40 rounded-full pointer-events-none"
        style={{
          background: "rgba(255,255,255,0.14)",
          transform: "translate(30%,30%)",
          filter: "blur(4px)",
        }}
      />

      {/* Sound button */}
      <div className="relative z-10 flex justify-end">
        <button
          onPointerDown={(e) => e.stopPropagation()}
          onClick={(e) => { e.stopPropagation(); onSound(); }}
          className="w-9 h-9 rounded-full flex items-center justify-center"
          style={{ background: "rgba(255,255,255,0.25)" }}
        >
          <Volume2 size={16} color="white" />
        </button>
      </div>

      {/* Word + phonetic */}
      <div className="relative z-10 flex-1 flex flex-col justify-center -mt-4">
        <div className="flex items-baseline gap-2 flex-wrap">
          <span
            className="text-white"
            style={{ fontSize: "2.4rem", fontWeight: 800, lineHeight: 1.1 }}
          >
            {card.word}
          </span>
          <span
            className="text-white"
            style={{ fontSize: "0.95rem", opacity: 0.65, fontStyle: "italic" }}
          >
            {card.partOfSpeech}
          </span>
        </div>
        <p
          className="text-white mt-2"
          style={{ fontSize: "1.05rem", opacity: 0.68, letterSpacing: "0.02em" }}
        >
          {card.phonetic}
        </p>
      </div>

      {/* Translation */}
      <div
        className="relative z-10 pt-4"
        style={{ borderTop: "1px solid rgba(255,255,255,0.2)" }}
      >
        <p className="text-white" style={{ fontSize: "1rem", opacity: 0.88 }}>
          {card.translation}
        </p>
        {card.example && (
          <p
            className="text-white mt-1"
            style={{ fontSize: "0.82rem", opacity: 0.45, fontStyle: "italic" }}
          >
            "{card.example}"
          </p>
        )}
      </div>
    </div>
  );
}

// ─── Top (draggable) card ─────────────────────────────────────────────────────

interface TopCardProps {
  card: Card;
  onCycle: (dragX: number) => void;
  animateIn: boolean; // if true, card enters from the 2nd-depth position
}

function TopCard({ card, onCycle, animateIn }: TopCardProps) {
  const dragX = useMotionValue(0);
  // Gentle tilt while dragging
  const dragRotate = useTransform(dragX, [-280, 0, 280], [-14, 0, 14]);

  const handleDragEnd = (_: unknown, info: { offset: { x: number } }) => {
    if (Math.abs(info.offset.x) > 80) {
      // Hand off current position to parent for the return animation
      onCycle(dragX.get());
    } else {
      animate(dragX, 0, { type: "spring", stiffness: 340, damping: 26 });
    }
  };

  const handleSound = () => {
    if ("speechSynthesis" in window) {
      const u = new SpeechSynthesisUtterance(card.word);
      u.lang = "nl-NL";
      speechSynthesis.speak(u);
    }
  };

  return (
    /* Outer div: handles the "come forward from depth-1" entry animation */
    <motion.div
      className="absolute inset-0"
      style={{ zIndex: VISIBLE + 2, originX: 0.5, originY: 1 }}
      initial={animateIn ? depthStyle(1) : false}
      animate={{ scale: 1, y: 0, rotate: 0 }}
      transition={{ type: "spring", stiffness: 300, damping: 26 }}
    >
      {/* Inner div: handles drag interaction & tilt */}
      <motion.div
        className="absolute inset-0"
        style={{ x: dragX, rotate: dragRotate, cursor: "grab" }}
        drag="x"
        dragConstraints={{ left: 0, right: 0 }}
        dragElastic={0.75}
        onDragEnd={handleDragEnd}
        whileTap={{ cursor: "grabbing" }}
      >
        <div
          className="w-full h-full rounded-3xl overflow-hidden"
          style={{
            background: `linear-gradient(135deg, ${card.color[0]}, ${card.color[1]})`,
            boxShadow: "0 28px 60px rgba(0,0,0,0.30), 0 8px 20px rgba(0,0,0,0.18)",
          }}
        >
          <CardFace card={card} onSound={handleSound} />
        </div>
      </motion.div>
    </motion.div>
  );
}

// ─── Background stack card ────────────────────────────────────────────────────

function StackCard({ card, depth }: { card: Card; depth: number }) {
  return (
    <motion.div
      key={card.id}
      className="absolute inset-0 rounded-3xl"
      animate={depthStyle(depth)}
      transition={{ type: "spring", stiffness: 300, damping: 28 }}
      style={{
        zIndex: VISIBLE - depth,
        originX: 0.5,
        originY: 1,
        background: `linear-gradient(135deg, ${card.color[0]}, ${card.color[1]})`,
        boxShadow: "0 8px 24px rgba(0,0,0,0.18)",
      }}
    />
  );
}

// ─── Ghost card that animates back into the stack ─────────────────────────────

function ReturningCard({ card, startX }: { card: Card; startX: number }) {
  return (
    <motion.div
      className="absolute inset-0 rounded-3xl overflow-hidden"
      /* Starts where the user released the drag, then slides back to the
         visual "back-of-stack" position. z-index 0 keeps it behind all other cards. */
      initial={{ x: startX, scale: 1, y: 0, rotate: 0 }}
      animate={{ x: 0, ...BACK_DEPTH }}
      transition={{ duration: 0.45, ease: [0.33, 1, 0.68, 1] }}
      style={{
        zIndex: 0,
        originX: 0.5,
        originY: 1,
        background: `linear-gradient(135deg, ${card.color[0]}, ${card.color[1]})`,
        boxShadow: "0 8px 24px rgba(0,0,0,0.18)",
      }}
    />
  );
}

// ─── Main ─────────────────────────────────────────────────────────────────────

export default function FlashCards() {
  // Ordered list of card indices; order[0] = top card
  const [order, setOrder] = useState<number[]>(CARDS.map((_, i) => i));
  const [swipeCount, setSwipeCount] = useState(0);
  // Ghost card currently animating back into the stack
  const [returningCard, setReturningCard] = useState<{ card: Card; startX: number } | null>(null);
  const busyRef = useRef(false);

  /** Move top card to the back of the deck */
  const cycleForward = (dragX: number) => {
    if (busyRef.current) return;
    busyRef.current = true;

    const topCard = CARDS[order[0]];
    // Show the ghost returning card
    setReturningCard({ card: topCard, startX: dragX });
    // Immediately update the deck order
    setOrder((prev) => [...prev.slice(1), prev[0]]);
    setSwipeCount((c) => c + 1);

    // Remove ghost after animation completes
    setTimeout(() => {
      setReturningCard(null);
      busyRef.current = false;
    }, 500);
  };

  /** Move the last card back to the top (undo) */
  const cycleBackward = () => {
    if (busyRef.current || swipeCount === 0) return;
    setOrder((prev) => [prev[prev.length - 1], ...prev.slice(0, -1)]);
    setSwipeCount((c) => c - 1);
  };

  const resetOrder = () => {
    busyRef.current = false;
    setOrder(CARDS.map((_, i) => i));
    setSwipeCount(0);
    setReturningCard(null);
  };

  const topCard = CARDS[order[0]];
  // Background cards: depths 1, 2, … (from nearest to farthest visible)
  const bgCards = order.slice(1, VISIBLE); // e.g., [order[1], order[2]]

  const round = Math.floor(swipeCount / CARDS.length) + 1;
  const posInRound = swipeCount % CARDS.length;

  return (
    <div
      className="min-h-screen flex flex-col items-center justify-center px-4"
      style={{ background: "linear-gradient(160deg, #f0f4ff 0%, #e6eaff 100%)" }}
    >
      {/* Header */}
      <div className="mb-10 text-center">
        <h1 className="text-gray-700" style={{ fontSize: "1.5rem", fontWeight: 700 }}>
          Nederlands Vocabulaire
        </h1>
        <p className="text-gray-400 mt-1" style={{ fontSize: "0.88rem" }}>
          Swipe or use arrows · Round {round}
        </p>
      </div>

      {/* ── Card stack ── */}
      <div className="relative" style={{ width: 320, height: 400 }}>
        {/*
          Rendering order (bottom → top in z):
            1. ReturningCard (z=0) — slides from drag position to back-of-stack
            2. StackCard depth=2 (z=1) — 3rd visible card
            3. StackCard depth=1 (z=2) — 2nd visible card
            4. TopCard (z=VISIBLE+2) — interactive front card
        */}

        {returningCard && (
          <ReturningCard card={returningCard.card} startX={returningCard.startX} />
        )}

        {bgCards.map((cardIdx, i) => (
          <StackCard
            key={CARDS[cardIdx].id}
            card={CARDS[cardIdx]}
            depth={i + 1}
          />
        ))}

        <TopCard
          key={`top-${topCard.id}-${swipeCount}`}
          card={topCard}
          onCycle={cycleForward}
          animateIn={swipeCount > 0}
        />
      </div>

      {/* Progress dots */}
      <div className="mt-9 flex items-center gap-[7px]">
        {CARDS.map((_, i) => {
          const posInOrder = order.indexOf(i);
          const isTop = posInOrder === 0;
          return (
            <motion.div
              key={i}
              className="rounded-full"
              animate={{
                width: isTop ? 26 : 8,
                background: isTop
                  ? "#3d5af1"
                  : posInOrder < VISIBLE
                  ? "#94a3b8"
                  : "#d1d5db",
              }}
              style={{ height: 8 }}
              transition={{ duration: 0.25 }}
            />
          );
        })}
      </div>

      {/* Position */}
      <p className="mt-3 text-gray-400" style={{ fontSize: "0.83rem" }}>
        {posInRound + 1} / {CARDS.length}
      </p>

      {/* Controls */}
      <div className="mt-6 flex items-center gap-4">
        <button
          onClick={cycleBackward}
          disabled={swipeCount === 0}
          className="w-12 h-12 rounded-full flex items-center justify-center transition-opacity"
          style={{
            background: "white",
            boxShadow: "0 4px 16px rgba(0,0,0,0.1)",
            opacity: swipeCount === 0 ? 0.3 : 1,
          }}
          title="Previous"
        >
          <ChevronLeft size={20} color="#64748b" />
        </button>

        <button
          onClick={resetOrder}
          className="w-10 h-10 rounded-full flex items-center justify-center"
          style={{ background: "white", boxShadow: "0 4px 16px rgba(0,0,0,0.1)" }}
          title="Reset"
        >
          <RefreshCw size={15} color="#64748b" />
        </button>

        <button
          onClick={() => cycleForward(0)}
          className="w-12 h-12 rounded-full flex items-center justify-center"
          style={{ background: "white", boxShadow: "0 4px 16px rgba(0,0,0,0.1)" }}
          title="Next"
        >
          <ChevronRight size={20} color="#64748b" />
        </button>
      </div>

      <p className="mt-5 text-gray-300" style={{ fontSize: "0.76rem" }}>
        drag left or right · tap 🔊 to pronounce
      </p>
    </div>
  );
}
