import React from 'react';

interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

export const BirdAvatar: React.FC<AvatarProps> = ({
  furColor = '#0F172A',
  patternColor = '#0F172A',
  eyeColor = '#CBD5E1',
  className = 'w-full h-full',
}) => {
  return (
    <svg viewBox="0 0 160 160" className={className} xmlns="http://www.w3.org/2000/svg">

      {/* ── Body / wing ── flows from left edge */}
      <path
        d="M 0 160 L 86 160 C 134 160, 144 120, 86 110 L 0 110 Z"
        fill={furColor}
      />
      {/* Wing fold hint */}
      <path
        d="M 0 126 C 30 120, 60 118, 86 122"
        stroke={patternColor}
        strokeWidth="2"
        fill="none"
        opacity="0.3"
        strokeLinecap="round"
      />

      {/* ── Crown crest feathers ── three upswept plumes */}
      <path d="M 70 55 C 62 30, 68 14, 74 30 Z" fill={patternColor} />
      <path d="M 82 50 C 78 22, 86 8, 88 28 Z" fill={furColor} />
      <path d="M 94 56 C 92 28, 100 18, 100 36 Z" fill={patternColor} opacity="0.7" />

      {/* ── Head ── round bird head */}
      <ellipse cx="84" cy="88" rx="50" ry="46" fill={furColor} />

      {/* ── Asymmetric pattern spot (right side) ── */}
      <circle cx="108" cy="84" r="20" fill={patternColor} opacity="0.28" />

      {/* ── Cheek patch (left) ── */}
      <circle cx="60" cy="98" r="10" fill={patternColor} opacity="0.18" />

      {/* ── Left eye ── round, prominent bird eye with orbital ring */}
      <circle cx="64" cy="84" r="13" fill={eyeColor} opacity="0.15" />
      <ellipse cx="64" cy="84" rx="11" ry="11" fill={eyeColor} />
      <ellipse cx="64" cy="84" rx="6" ry="6.5" fill={furColor} />
      <circle cx="68" cy="80" r="2.5" fill={eyeColor} opacity="0.85" />

      {/* ── Right eye ── */}
      <circle cx="108" cy="84" r="12" fill={eyeColor} opacity="0.15" />
      <ellipse cx="108" cy="84" rx="10" ry="10" fill={eyeColor} />
      <ellipse cx="108" cy="84" rx="5.5" ry="6" fill={furColor} />
      <circle cx="112" cy="80" r="2.5" fill={eyeColor} opacity="0.85" />

      {/* ── Beak ── curved triangle, hooked tip */}
      <path
        d="M 78 104 L 84 96 L 94 104 Q 88 112 84 108 Q 80 112 78 104 Z"
        fill={patternColor}
        opacity="0.9"
      />
      {/* Beak highlight */}
      <path
        d="M 84 96 L 90 102"
        stroke={eyeColor}
        strokeWidth="1.5"
        fill="none"
        opacity="0.35"
        strokeLinecap="round"
      />

    </svg>
  );
};
