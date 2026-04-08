import React from 'react';

interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

export const HamsterAvatar: React.FC<AvatarProps> = ({
  furColor = '#0F172A',
  patternColor = '#0F172A',
  eyeColor = '#CBD5E1',
  className = 'w-full h-full',
}) => {
  return (
    <svg viewBox="0 0 160 160" className={className} xmlns="http://www.w3.org/2000/svg">

      {/* ── Body ── anchored to left edge, chubby */}
      <path
        d="M 0 160 L 94 160 C 144 160, 154 116, 94 104 L 0 104 Z"
        fill={furColor}
      />

      {/* ── Left chubby cheek pouch ── extends beyond head */}
      <ellipse cx="30" cy="100" rx="28" ry="22" fill={furColor} />
      {/* Left cheek inner (pattern tint) */}
      <ellipse cx="30" cy="102" rx="18" ry="14" fill={patternColor} opacity="0.2" />

      {/* ── Right chubby cheek pouch ── */}
      <ellipse cx="140" cy="100" rx="26" ry="20" fill={furColor} />
      {/* Right cheek inner */}
      <ellipse cx="140" cy="102" rx="16" ry="12" fill={patternColor} opacity="0.22" />

      {/* ── Left small ear ── rounded on top of head */}
      <ellipse cx="56" cy="58" rx="16" ry="14" fill={patternColor} />
      <ellipse cx="56" cy="60" rx="9" ry="9" fill={eyeColor} opacity="0.2" />

      {/* ── Right small ear ── */}
      <ellipse cx="106" cy="56" rx="15" ry="13" fill={furColor} />
      <ellipse cx="106" cy="58" rx="8" ry="8" fill={patternColor} opacity="0.24" />

      {/* ── Head ── extra wide, round */}
      <ellipse cx="82" cy="90" rx="58" ry="46" fill={furColor} />

      {/* ── Asymmetric pattern spot ── */}
      <circle cx="108" cy="84" r="22" fill={patternColor} opacity="0.26" />

      {/* ── Left eye ── big, shiny hamster eye */}
      <ellipse cx="60" cy="84" rx="12" ry="12" fill={eyeColor} />
      <ellipse cx="60" cy="84" rx="7" ry="7.5" fill={furColor} />
      <circle cx="65" cy="79" r="3" fill={eyeColor} opacity="0.8" />

      {/* ── Right eye ── */}
      <ellipse cx="108" cy="84" rx="12" ry="12" fill={eyeColor} />
      <ellipse cx="108" cy="84" rx="7" ry="7.5" fill={furColor} />
      <circle cx="113" cy="79" r="3" fill={eyeColor} opacity="0.8" />

      {/* ── Tiny button nose ── */}
      <ellipse cx="84" cy="107" rx="6" ry="4" fill={patternColor} opacity="0.85" />
      <circle cx="82" cy="106" r="1.5" fill={eyeColor} opacity="0.3" />

      {/* ── Mouth ── short curved line */}
      <path
        d="M 78 112 Q 84 117 90 112"
        stroke={patternColor}
        strokeWidth="1.8"
        fill="none"
        strokeLinecap="round"
        opacity="0.55"
      />

    </svg>
  );
};
