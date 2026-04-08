import React from 'react';

interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

export const DogAvatar: React.FC<AvatarProps> = ({
  furColor = '#0F172A',
  patternColor = '#0F172A',
  eyeColor = '#CBD5E1',
  className = 'w-full h-full',
}) => {
  return (
    <svg viewBox="0 0 160 160" className={className} xmlns="http://www.w3.org/2000/svg">

      {/* ── Body ── anchored to left edge */}
      <path
        d="M 0 160 L 92 160 C 140 160, 150 118, 92 106 L 0 106 Z"
        fill={furColor}
      />

      {/* ── Left floppy ear (pattern) ── hangs from left side of head */}
      <path
        d="M 42 68 C 20 62, 14 88, 22 108 C 30 122, 50 118, 52 100 C 54 86, 50 72, 42 68 Z"
        fill={patternColor}
      />

      {/* ── Right floppy ear (fur) ── */}
      <path
        d="M 118 68 C 140 62, 146 88, 138 108 C 130 122, 110 118, 108 100 C 106 86, 110 72, 118 68 Z"
        fill={furColor}
      />
      {/* Right ear inner shade */}
      <path
        d="M 120 72 C 137 68, 141 89, 135 105 C 129 116, 114 114, 112 102 C 110 90, 114 76, 120 72 Z"
        fill={patternColor}
        opacity="0.22"
      />

      {/* ── Head ── wide, friendly dog face */}
      <ellipse cx="85" cy="88" rx="57" ry="48" fill={furColor} />

      {/* ── Asymmetric pattern spot (right side) ── */}
      <circle cx="112" cy="84" r="24" fill={patternColor} opacity="0.25" />

      {/* ── Muzzle snout ── */}
      <ellipse cx="85" cy="110" rx="22" ry="14" fill={patternColor} opacity="0.18" />

      {/* ── Left eye ── large, round dog eye */}
      <ellipse cx="62" cy="86" rx="11" ry="11" fill={eyeColor} />
      <ellipse cx="62" cy="86" rx="6.5" ry="7" fill={furColor} />
      <circle cx="66" cy="82" r="2.5" fill={eyeColor} opacity="0.8" />

      {/* ── Right eye ── */}
      <ellipse cx="110" cy="86" rx="11" ry="11" fill={eyeColor} />
      <ellipse cx="110" cy="86" rx="6.5" ry="7" fill={furColor} />
      <circle cx="114" cy="82" r="2.5" fill={eyeColor} opacity="0.8" />

      {/* ── Big oval nose ── */}
      <ellipse cx="85" cy="108" rx="9" ry="6" fill={patternColor} opacity="0.9" />
      {/* Nostril highlights */}
      <circle cx="81" cy="107" r="2" fill={eyeColor} opacity="0.3" />
      <circle cx="89" cy="107" r="2" fill={eyeColor} opacity="0.3" />

      {/* ── Happy mouth curve ── */}
      <path
        d="M 76 116 Q 85 122 94 116"
        stroke={patternColor}
        strokeWidth="2"
        fill="none"
        strokeLinecap="round"
        opacity="0.6"
      />

    </svg>
  );
};
