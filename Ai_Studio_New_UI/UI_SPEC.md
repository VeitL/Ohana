# Pet Dashboard UI Design System

This document outlines the UI specifications for the Pet Dashboard application, featuring a clean, modern "Smart Home Control Panel" aesthetic. The design emphasizes clarity, large touch targets, and a playful yet sophisticated vibe.

## 1. Core Principles
- **Clean & Minimal:** Reduce visual noise. Use ample whitespace and clear hierarchy.
- **Tactile & Friendly:** Large rounded corners (32px) make the interface feel approachable and touch-friendly.
- **Focus on Data:** Use high contrast for primary data points (like weight or counts).
- **Vibrant Accents:** Use a signature vibrant orange to draw attention to primary actions and active states.

---

## 2. Color Palette

The system uses a strict dual-theme palette (Light and Dark) to ensure consistency.

### 2.1 Brand Accent
- **Primary Orange:** `#FF5A00` (Used for active toggles, primary FAB buttons, key data highlights)
- **Orange Light (Light Mode):** `#FFF0E5` (Used for subtle backgrounds behind orange icons)
- **Orange Dark (Dark Mode):** `rgba(255, 90, 0, 0.2)` (Used for subtle backgrounds behind orange icons)

### 2.2 Light Mode Theme
- **Background (App/Page):** `#F5F5F7` (A very light, cool gray to make white cards pop)
- **Surface (Cards):** `#FFFFFF` (Pure white)
- **Surface Secondary (Inset cards/toggles):** `#F0F2F5`
- **Text Primary:** `text-slate-900` (`#0F172A`)
- **Text Secondary:** `text-slate-400` (`#94A3B8`)
- **Borders/Dividers:** `border-slate-100` (`#F1F5F9`) or `border-slate-200` (`#E2E8F0`)
- **Icons (Inactive):** `text-slate-600` (`#475569`)

### 2.3 Dark Mode Theme
- **Background (App/Page):** `#0A0A0C` (Deep, almost black)
- **Surface (Cards):** `#1C1C1E` (Dark gray, elevated from background)
- **Surface Secondary (Inset cards/toggles):** `#2C2C2E`
- **Text Primary:** `#FFFFFF` (Pure white)
- **Text Secondary:** `text-slate-500` (`#64748B`) or `text-white/80`
- **Borders/Dividers:** `border-white/10` (Subtle semi-transparent white)
- **Icons (Inactive):** `text-white/80` or `text-white/60`

---

## 3. Typography

The application uses the system sans-serif font stack (Inter or SF Pro) for a native, clean feel.

- **Font Family:** `Inter`, system-ui, sans-serif
- **Weights:**
  - Regular (400): Body text, secondary labels.
  - Medium (500): Card titles, primary labels, medium-emphasis data.
  - Bold (700): Small tags, highly emphasized micro-copy.

### 3.1 Type Scale
- **Hero Data (e.g., Weight Value):** `text-5xl` (48px), Medium weight.
- **Page Title:** `text-3xl` (30px), Medium weight.
- **Card Title:** `text-lg` (18px), Medium weight.
- **Body/Standard Label:** `text-sm` (14px), Regular or Medium weight.
- **Micro/Meta Data:** `text-xs` (12px) or `text-[10px]`, Regular or Bold weight.

---

## 4. Components & Layout

### 4.1 Cards (Bento Grid Items)
Cards are the primary container for information, designed to look like physical, rounded tiles.

- **Border Radius:** `rounded-[32px]` (Extremely large, signature look).
- **Padding:** `p-4` to `p-6` depending on content density.
- **Shadow (Light Mode):** `shadow-[0_4px_20px_rgba(0,0,0,0.03)]` (Very subtle, soft drop shadow).
- **Shadow (Dark Mode):** `shadow-[0_4px_20px_rgba(0,0,0,0.2)]` (Slightly stronger to separate dark surfaces).
- **Layout:** Flexbox or Grid, typically with a header row (title + action icon) and a content area.

### 4.2 Buttons & Actions

#### Floating Action Button (FAB) / Primary Add
- **Shape:** Perfect circle (`rounded-full`).
- **Size:** Large (`w-16 h-16`).
- **Color:** Primary Orange (`bg-[#FF5A00]`).
- **Text/Icon:** White, `text-3xl`, Light weight (`font-light`).
- **Shadow:** Colored glow (`shadow-lg shadow-orange-500/30` in light mode, `shadow-orange-500/20` in dark mode).
- **Interaction:** `hover:scale-105 transition-transform`.

#### Secondary Action Buttons (Top right of cards)
- **Shape:** Perfect circle (`rounded-full`).
- **Size:** `w-10 h-10` or `w-8 h-8`.
- **Background (Light):** Pure white (`bg-white`) with a subtle border (`border-slate-100`).
- **Background (Dark):** Semi-transparent white (`bg-white/5`) with subtle border (`border-white/10`).
- **Icon Color:** Matches Text Secondary or Inactive Icon color.
- **Interaction:** `hover:bg-slate-50` (Light) or `hover:bg-white/10` (Dark).

#### Icon Containers (Decorative)
- **Shape:** Perfect circle (`rounded-full`).
- **Size:** `w-10 h-10` or `w-12 h-12`.
- **Background:** Often a very light tint of the icon color (e.g., `bg-[#FFF0E5]` for orange icons) or Surface Secondary.

### 4.3 Toggles & Switches (Smart Home Style)
Used for binary states (On/Off, Active/Inactive).

- **Container:** Pill shape (`rounded-full`), `w-12 h-7`.
- **Background (Off):** `bg-slate-200` (Light) or `bg-white/10` (Dark).
- **Background (On):** Primary Orange (`bg-[#FF5A00]`).
- **Knob:** `w-5 h-5 bg-white rounded-full shadow-sm`.
- **Positioning:** Absolute positioning within the container (`left-1` for Off, `right-1` for On).

### 4.4 Tags & Badges
Used for status or small metadata.

- **Shape:** Pill shape (`rounded-full`).
- **Padding:** `px-3 py-1` or `px-4 py-1.5`.
- **Text:** `text-[10px]` or `text-sm`, usually Bold or Medium.
- **Style Example (Status):** `bg-slate-900 text-white` (Light mode) or `bg-white text-[#1C1C1E]` (Dark mode).
- **Style Example (Outline):** `border border-slate-200 text-slate-600` (Light mode).

---

## 5. Spacing & Grid

- **Global Padding:** `px-6` for main page containers.
- **Card Gap:** `gap-4` between bento grid items.
- **Internal Spacing:** Use multiples of 4px (e.g., `mb-4`, `mt-6`, `space-y-2`).

## 6. Motion & Animation
- **Transitions:** Use `transition-colors` for hover states on buttons. Use `transition-transform` for scaling effects.
- **Scaling:** Active states (clicking) use `active:scale-90`. Hover states on primary buttons use `hover:scale-105`.
- **Page/Card Entry:** Use Framer Motion's `staggerChildren` to create a cascading entrance effect for bento cards.
