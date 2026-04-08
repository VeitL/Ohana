import React from 'react';

interface AvatarProps {
  furColor?: string;
  patternColor?: string;
  eyeColor?: string;
  className?: string;
}

export const RabbitAvatar: React.FC<AvatarProps> = ({
  furColor = '#0F172A',
  patternColor = '#0F172A',
  eyeColor = '#CBD5E1',
  className = 'w-full h-full',
}) => {
  return (
    <svg viewBox="0 0 160 160" className={className} xmlns="http://www.w3.org/2000/svg">

      {/* ── Body ── anchored to left edge */}
      <path
        d="M 0 160 L 88 160 C 136 160, 146 118, 88 108 L 0 108 Z"
        fill={furColor}
      />

      {/* ── Left tall ear (pattern) ── long upright rabbit ear */}
      <ellipse cx="62" cy="30" rx="14" ry="42" fill={patternColor} />
      {/* Left inner ear */}
      <ellipse cx="62" cy="32" rx="7" ry="32" fill={eyeColor} opacity="0.25" />

      {/* ── Right tall ear (fur) ── slightly tilted */}
      <ellipse
        cx="104" cy="28" rx="13" ry="40"
        fill={furColor}
        transform="rotate(8 104 28)"
      />
      {/* Right inner ear */}
      <ellipse
        cx="104" cy="30" rx="6" ry="30"
        fill={patternColor}
        opacity="0.22"
        transform="rotate(8 104 30)"
      />

      {/* ── Head ── compact round face */}
      <ellipse cx="85" cy="92" rx="50" ry="44" fill={furColor} />

      {/* ── Asymmetric pattern spot (right eye) ── */}
      <circle cx="108" cy="88" r="20" fill={patternColor} opacity="0.26" />

      {/* ── Left eye ── large round rabbit eye */}
      <ellipse cx="65" cy="90" rx="10" ry="10" fill={eyeColor} />
      <ellipse cx="65" cy="90" rx="6" ry="6.5" fill={furColor} />
      <circle cx="69" cy="86" r="2" fill={eyeColor} opacity="0.75" />

      {/* ── Right eye ── */}
      <ellipse cx="108" cy="90" rx="10" ry="10" fill={eyeColor} />
      <ellipse cx="108" cy="90" rx="6" ry="6.5" fill={furColor} />
      <circle cx="112" cy="86" r="2" fill={eyeColor} opacity="0.75" />

      {/* ── Tiny nose ── upside-down triangle */}
      <path
        d="M 82 110 L 85 106 L 88 110 Z"
        fill={patternColor}
        opacity="0.8"
      />

      {/* ── Split upper lip ── Y-shape */}
      <path
        d="M 85 110 L 85 116"
        stroke={patternColor}
        strokeWidth="1.5"
        fill="none"
        strokeLinecap="round"
        opacity="0.5"
      />
      <path
        d="M 85 116 Q 80 120 76 118 M 85 116 Q 90 120 94 118"
        stroke={patternColor}
        strokeWidth="1.5"
        fill="none"
        strokeLinecap="round"
        opacity="0.5"
      />

      {/* ── Cheek dots ── subtle whisker base */}
      <circle cx="72" cy="108" r="1.5" fill={patternColor} opacity="0.2" />
      <circle cx="76" cy="112" r="1.5" fill={patternColor} opacity="0.2" />
      <circle cx="98" cy="108" r="1.5" fill={patternColor} opacity="0.2" />
      <circle cx="94" cy="112" r="1.5" fill={patternColor} opacity="0.2" />

    </svg>
  );
};
