import React from 'react';

interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

export const CatAvatar: React.FC<AvatarProps> = ({
  furColor = '#0F172A',
  patternColor = '#0F172A',
  eyeColor = '#CBD5E1',
  className = 'w-full h-full',
}) => {
  return (
    <svg viewBox="0 0 160 160" className={className} xmlns="http://www.w3.org/2000/svg">

      {/* ── Body ── anchored to left edge */}
      <path
        d="M 0 160 L 90 160 C 138 160, 148 118, 90 107 L 0 107 Z"
        fill={furColor}
      />

      {/* ── Left ear (pattern) ── sharp triangle */}
      <path d="M 50 62 L 38 18 L 82 52 Z" fill={patternColor} />
      {/* Left inner ear — lighter inset */}
      <path d="M 54 59 L 46 28 L 76 53 Z" fill={eyeColor} opacity="0.18" />

      {/* ── Right ear (fur) ── */}
      <path d="M 90 52 L 124 18 L 132 64 Z" fill={furColor} />
      {/* Right inner ear */}
      <path d="M 94 52 L 120 26 L 127 61 Z" fill={patternColor} opacity="0.22" />

      {/* ── Head ── wider, rounder cat face */}
      <ellipse cx="85" cy="90" rx="53" ry="46" fill={furColor} />

      {/* ── Asymmetric pattern spot (right eye side) ── */}
      <circle cx="110" cy="86" r="22" fill={patternColor} opacity="0.28" />

      {/* ── Left eye ── almond, vertical slit pupil */}
      <ellipse cx="63" cy="88" rx="12" ry="10" fill={eyeColor} />
      {/* Slit pupil */}
      <ellipse cx="63" cy="88" rx="4" ry="8" fill={furColor} />
      {/* Eye shine */}
      <circle cx="67" cy="84" r="2.2" fill={eyeColor} opacity="0.75" />

      {/* ── Right eye ── */}
      <ellipse cx="110" cy="88" rx="12" ry="10" fill={eyeColor} />
      {/* Slit pupil */}
      <ellipse cx="110" cy="88" rx="4" ry="8" fill={furColor} />
      {/* Eye shine */}
      <circle cx="114" cy="84" r="2.2" fill={eyeColor} opacity="0.75" />

      {/* ── Nose ── small diamond shape */}
      <path
        d="M 82 109 L 85 105 L 88 109 L 85 112 Z"
        fill={patternColor}
        opacity="0.85"
      />

      {/* ── Muzzle pads ── subtle dots flanking nose */}
      <circle cx="77" cy="113" r="2" fill={patternColor} opacity="0.2" />
      <circle cx="93" cy="113" r="2" fill={patternColor} opacity="0.2" />

    </svg>
  );
};
