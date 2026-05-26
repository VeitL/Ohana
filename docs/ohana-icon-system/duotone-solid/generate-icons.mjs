import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const iconsDir = join(here, "icons");
const variableIconsDir = join(here, "icons-variable");

const classes = `
  .primary { fill: var(--ohana-icon-primary, #1f8a8a); }
  .primary-soft { fill: var(--ohana-icon-primary, #1f8a8a); opacity: .22; }
  .accent { fill: var(--ohana-icon-accent, #ff755f); }
  .accent-soft { fill: var(--ohana-icon-accent, #ff755f); opacity: .28; }
  .primary-line {
    fill: none;
    stroke: var(--ohana-icon-primary, #1f8a8a);
    stroke-width: 4.2;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
  .accent-line {
    fill: none;
    stroke: var(--ohana-icon-accent, #ff755f);
    stroke-width: 3;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
  .primary-thin-line {
    fill: none;
    stroke: var(--ohana-icon-primary, #1f8a8a);
    stroke-width: 2.1;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
  .accent-thin-line {
    fill: none;
    stroke: var(--ohana-icon-accent, #ff755f);
    stroke-width: 2.1;
    stroke-linecap: round;
    stroke-linejoin: round;
  }
`;

const icons = [
  {
    id: "feed",
    zh: "喂食",
    en: "Feeding",
    primary: "#1f8a8a",
    accent: "#ff755f",
    shapes: `
      <ellipse class="primary-soft" cx="16" cy="13.3" rx="10.2" ry="4.8"/>
      <path class="primary" d="M5.6 13.7h20.8l-1.5 7.5A5.8 5.8 0 0 1 19.2 26h-6.4a5.8 5.8 0 0 1-5.7-4.8l-1.5-7.5Z"/>
      <rect class="primary" x="9.3" y="23.6" width="13.4" height="2.7" rx="1.35"/>
      <path class="accent" d="M16 21.7c-1.8-1-3-2.3-3-3.6 0-1 .7-1.7 1.5-1.7.6 0 1.1.3 1.5.9.4-.6.9-.9 1.5-.9.8 0 1.5.7 1.5 1.7 0 1.3-1.2 2.6-3 3.6Z"/>
      <circle class="accent" cx="11.3" cy="11.8" r="2.05"/>
      <circle class="accent" cx="15.8" cy="10.6" r="2.45"/>
      <circle class="accent" cx="20.2" cy="12" r="2"/>
    `
  },
  {
    id: "calendar",
    zh: "日历",
    en: "Calendar",
    primary: "#3f74d8",
    accent: "#9bdc4a",
    shapes: `
      <rect class="primary" x="5.5" y="6.5" width="21" height="20" rx="5.5"/>
      <rect class="accent" x="9" y="10" width="14" height="3" rx="1.5"/>
      <circle class="accent" cx="11.3" cy="17.3" r="1.55"/>
      <circle class="accent-soft" cx="16" cy="17.3" r="1.55"/>
      <circle class="accent-soft" cx="20.7" cy="17.3" r="1.55"/>
      <rect class="accent" x="14.1" y="20.2" width="7.9" height="3.2" rx="1.6"/>
    `
  },
  {
    id: "walk",
    zh: "遛狗",
    en: "Dog walking",
    primary: "#2b8f78",
    accent: "#c8ff3d",
    shapes: `
      <path class="accent-thin-line" d="M7.2 9.2c3.4.3 6.1 2.2 8.8 5.1"/>
      <circle class="accent-soft" cx="6.8" cy="9" r="2.1"/>
      <rect class="primary" x="12.2" y="16.2" width="9.2" height="5.4" rx="2.7"/>
      <circle class="primary" cx="22.3" cy="15.2" r="3.05"/>
      <ellipse class="primary" cx="25" cy="16.3" rx="2.1" ry="1.45"/>
      <path class="primary" d="M24.3 13 27 11.8l-.4 3.4-2.3-2.2Z"/>
      <path class="primary-thin-line" d="M12.6 17.4 9.5 15.5"/>
      <rect class="primary" x="13.4" y="20.7" width="2" height="4.4" rx="1"/>
      <rect class="primary" x="18.1" y="20.7" width="2" height="4.4" rx="1"/>
      <circle class="accent" cx="23.2" cy="14.8" r=".75"/>
      <rect class="accent" x="17.7" y="13.2" width="4.1" height="1.8" rx=".9"/>
    `
  },
  {
    id: "water",
    zh: "饮水",
    en: "Water",
    primary: "#1c9ec2",
    accent: "#7be4d4",
    shapes: `
      <path class="primary" d="M16 4.8c4.8 5.7 7.1 9.5 7.1 13.1a7.1 7.1 0 0 1-14.2 0c0-3.6 2.3-7.4 7.1-13.1Z"/>
      <path class="accent" d="M7.2 20.2h17.6l-1 3.3A4.3 4.3 0 0 1 19.7 26h-7.4a4.3 4.3 0 0 1-4.1-2.5l-1-3.3Z"/>
      <ellipse class="accent-soft" cx="16" cy="20.3" rx="8.8" ry="3"/>
    `
  },
  {
    id: "potty",
    zh: "如厕",
    en: "Potty cleanup",
    primary: "#7b6ac8",
    accent: "#ffb36b",
    shapes: `
      <rect class="primary" x="5.8" y="7" width="20.4" height="18.5" rx="5.8"/>
      <rect class="primary-soft" x="9.2" y="10.8" width="13.6" height="10.7" rx="3.6"/>
      <text class="accent" x="16" y="18.7" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="8.1" font-weight="900">WC</text>
      <rect class="accent-soft" x="10.2" y="22.5" width="11.6" height="2.1" rx="1.05"/>
    `
  },
  {
    id: "medicine",
    zh: "用药",
    en: "Medicine",
    primary: "#e0668c",
    accent: "#f7d46a",
    shapes: `
      <g transform="rotate(-35 16 16)">
        <rect class="primary" x="5.4" y="12" width="21.2" height="8" rx="4"/>
        <rect class="accent" x="16" y="12.4" width="10.1" height="7.2" rx="3.6"/>
        <circle class="primary-soft" cx="11.8" cy="16" r="2.1"/>
      </g>
    `
  },
  {
    id: "groom",
    zh: "洗护",
    en: "Grooming",
    primary: "#2d88c8",
    accent: "#ff9a6a",
    shapes: `
      <rect class="primary" x="5.6" y="8" width="20.8" height="5.6" rx="2.8"/>
      <rect class="primary" x="5.6" y="10.8" width="4.7" height="15.1" rx="2.35"/>
      <rect class="accent" x="12.4" y="13.4" width="1.75" height="10.6" rx=".88"/>
      <rect class="accent" x="15.5" y="13.4" width="1.75" height="10.6" rx=".88"/>
      <rect class="accent" x="18.6" y="13.4" width="1.75" height="10.6" rx=".88"/>
      <rect class="accent" x="21.7" y="13.4" width="1.75" height="10.6" rx=".88"/>
      <circle class="accent-soft" cx="8" cy="20.9" r="1.25"/>
    `
  },
  {
    id: "health",
    zh: "健康记录",
    en: "Health record",
    primary: "#2e7d6f",
    accent: "#ff6d78",
    shapes: `
      <rect class="primary" x="7" y="6" width="18" height="21" rx="5.2"/>
      <rect class="primary-soft" x="11" y="9.7" width="10" height="2.8" rx="1.4"/>
      <path class="accent" d="M16 23.1s-5.4-3.1-5.4-6.8c0-2 1.3-3.4 3.1-3.4 1.1 0 1.9.5 2.3 1.3.4-.8 1.2-1.3 2.3-1.3 1.8 0 3.1 1.4 3.1 3.4 0 3.7-5.4 6.8-5.4 6.8Z"/>
    `
  },
  {
    id: "sleep",
    zh: "休息",
    en: "Sleep",
    primary: "#5f6fd8",
    accent: "#ffd36c",
    shapes: `
      <path class="primary" d="M5.7 25.5 16 8.4l10.3 17.1H5.7Z"/>
      <path class="primary-soft" d="M16 8.4v17.1H5.7L16 8.4Z"/>
      <path class="accent" d="M16 16.7 21 25.5H11l5-8.8Z"/>
      <rect class="primary" x="6.2" y="24.2" width="19.6" height="2.4" rx="1.2"/>
      <text class="accent" x="23.5" y="8.6" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="5.5" font-weight="900">Z</text>
      <text class="accent" x="26.6" y="13" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="4.5" font-weight="900">Z</text>
      <text class="accent-soft" x="20" y="5.9" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="4" font-weight="900">Z</text>
    `
  },
  {
    id: "vet",
    zh: "疫苗/就诊",
    en: "Vaccination and vet visit",
    primary: "#298b9b",
    accent: "#c8ff3d",
    shapes: `
      <path class="primary" d="M16 4.8 24.4 8v6.8c0 5.5-3.1 9.8-8.4 12.4-5.3-2.6-8.4-6.9-8.4-12.4V8L16 4.8Z"/>
      <rect class="accent" x="14.2" y="10.6" width="3.6" height="11" rx="1.8"/>
      <rect class="accent" x="10.5" y="14.3" width="11" height="3.6" rx="1.8"/>
    `
  },
  {
    id: "weight",
    zh: "体重",
    en: "Weight",
    primary: "#6370c8",
    accent: "#7be4d4",
    shapes: `
      <rect class="primary" x="5.5" y="8" width="21" height="18.5" rx="6"/>
      <rect class="primary-soft" x="10" y="11" width="12" height="3" rx="1.5"/>
      <path class="accent-line" d="M16 17.3 20 13.5"/>
      <circle class="accent" cx="16" cy="17.3" r="2.45"/>
    `
  },
  {
    id: "reminder",
    zh: "提醒",
    en: "Reminder",
    primary: "#3f74d8",
    accent: "#ff755f",
    shapes: `
      <path class="primary" d="M10 20.7v-5.9a6 6 0 1 1 12 0v5.9l2 2.5H8l2-2.5Z"/>
      <path class="primary" d="M13.1 24.2h5.8a3 3 0 0 1-5.8 0Z"/>
      <circle class="accent" cx="23.3" cy="8.7" r="3.2"/>
    `
  },
  {
    id: "plant-water",
    zh: "植物浇水",
    en: "Plant watering",
    primary: "#2f8e62",
    accent: "#55d4d8",
    shapes: `
      <path class="primary" d="M9.2 17.4h13.6l-1 5.1A4.4 4.4 0 0 1 17.5 26h-3a4.4 4.4 0 0 1-4.3-3.5l-1-5.1Z"/>
      <path class="primary" d="M15.1 17.8c-.2-4.5-3.1-7.4-7.4-7.8.4 4.3 3.3 7.1 7.4 7.8Z"/>
      <path class="primary" d="M16.8 16.8c.3-4.7 3.2-7.9 7.5-8.8-.1 4.6-3 7.8-7.5 8.8Z"/>
      <path class="accent" d="M24.3 14.2c1.9 2.3 2.8 3.8 2.8 5.2a2.8 2.8 0 0 1-5.6 0c0-1.4.9-2.9 2.8-5.2Z"/>
    `
  },
  {
    id: "play",
    zh: "玩耍",
    en: "Play",
    primary: "#ff755f",
    accent: "#7be4d4",
    shapes: `
      <path class="primary" d="M10.1 11.9h11.8c2.8 0 5 2.2 5 5v3.5a3.5 3.5 0 0 1-6.3 2.1l-1.2-1.6h-6.8l-1.2 1.6a3.5 3.5 0 0 1-6.3-2.1v-3.5c0-2.8 2.2-5 5-5Z"/>
      <rect class="accent" x="9.3" y="16.1" width="6.2" height="2.1" rx="1.05"/>
      <rect class="accent" x="11.3" y="14.1" width="2.1" height="6.2" rx="1.05"/>
      <circle class="accent" cx="21" cy="16.4" r="1.55"/>
      <circle class="accent-soft" cx="23.9" cy="19" r="1.55"/>
    `
  },
  {
    id: "bath",
    zh: "洗澡",
    en: "Bath",
    primary: "#20a0b8",
    accent: "#ffd36c",
    shapes: `
      <path class="primary" d="M6.5 17.2h19l-1.1 5.2A4.8 4.8 0 0 1 19.7 26h-7.4a4.8 4.8 0 0 1-4.7-3.6l-1.1-5.2Z"/>
      <path class="primary-line" d="M9 16.5c1.8-2.2 3.9-2.2 5.7 0 1.8 2.2 3.9 2.2 5.7 0"/>
      <circle class="accent" cx="22.6" cy="8.3" r="2.3"/>
      <circle class="accent-soft" cx="18.6" cy="11.2" r="1.6"/>
    `
  },
  {
    id: "task",
    zh: "任务",
    en: "Task",
    primary: "#2b8f78",
    accent: "#c8ff3d",
    shapes: `
      <rect class="primary" x="6.5" y="6.5" width="19" height="19" rx="6"/>
      <path class="accent-line" d="m11.5 16.4 3 3.1 6.4-7"/>
      <circle class="accent-soft" cx="22.7" cy="22.7" r="2.2"/>
    `
  },
  {
    id: "food-stock",
    zh: "食物库存",
    en: "Food stock",
    primary: "#2b8f78",
    accent: "#ffb36b",
    shapes: `
      <path class="primary" d="M9.1 9.5h13.8l1.5 15.3A3.2 3.2 0 0 1 21.2 28H10.8a3.2 3.2 0 0 1-3.2-3.2L9.1 9.5Z"/>
      <path class="primary-soft" d="M11.2 5.2h9.6l2.1 4.3H9.1l2.1-4.3Z"/>
      <rect class="accent" x="11" y="13" width="10" height="2.4" rx="1.2"/>
      <rect class="accent" x="11" y="17" width="8.2" height="2.4" rx="1.2" opacity=".74"/>
      <rect class="accent" x="11" y="21" width="5.8" height="2.4" rx="1.2" opacity=".48"/>
    `
  },
  {
    id: "dry-food",
    zh: "干粮",
    en: "Dry food",
    primary: "#d7863f",
    accent: "#7be4d4",
    shapes: `
      <circle class="primary" cx="11.2" cy="12" r="2.65"/>
      <circle class="primary" cx="16" cy="10.6" r="2.65"/>
      <circle class="primary" cx="20.8" cy="12" r="2.65"/>
      <circle class="primary" cx="9.4" cy="17.2" r="2.65"/>
      <circle class="primary" cx="14.2" cy="17.2" r="2.65"/>
      <circle class="primary" cx="19" cy="17.2" r="2.65"/>
      <circle class="primary" cx="23.8" cy="17.2" r="2.65"/>
      <circle class="primary" cx="12.2" cy="22.3" r="2.65"/>
      <circle class="primary" cx="17" cy="22.3" r="2.65"/>
      <circle class="primary" cx="21.8" cy="22.3" r="2.65"/>
      <circle class="accent" cx="16" cy="16.8" r="1.2"/>
    `
  },
  {
    id: "wet-food",
    zh: "湿粮",
    en: "Wet food",
    primary: "#d86a76",
    accent: "#ffd36c",
    shapes: `
      <ellipse class="primary-soft" cx="16" cy="8.8" rx="8.3" ry="3.2"/>
      <path class="primary" d="M7.7 8.8h16.6v14.3c0 2-3.7 3.6-8.3 3.6s-8.3-1.6-8.3-3.6V8.8Z"/>
      <ellipse class="primary" cx="16" cy="8.8" rx="8.3" ry="3.2"/>
      <rect class="accent" x="10.1" y="14.4" width="11.8" height="5.4" rx="2.7"/>
      <ellipse class="primary-soft" cx="16" cy="23.2" rx="7.8" ry="2.6"/>
    `
  },
  {
    id: "treat",
    zh: "零食",
    en: "Treat",
    primary: "#ff755f",
    accent: "#7be4d4",
    shapes: `
      <rect class="primary" x="8.2" y="11" width="15.6" height="10" rx="5" transform="rotate(-24 16 16)"/>
      <circle class="accent" cx="8.8" cy="20.7" r="3"/>
      <circle class="accent-soft" cx="23.2" cy="11.3" r="2.5"/>
      <rect class="accent" x="13.4" y="13.9" width="5.2" height="2.7" rx="1.35" transform="rotate(-24 16 15.25)"/>
    `
  },
  {
    id: "food-bag",
    zh: "粮袋",
    en: "Food bag",
    primary: "#2b8f78",
    accent: "#ffb36b",
    shapes: `
      <path class="primary" d="M9.1 9.5h13.8l1.5 15.3A3.2 3.2 0 0 1 21.2 28H10.8a3.2 3.2 0 0 1-3.2-3.2L9.1 9.5Z"/>
      <path class="primary-soft" d="M11.2 5.2h9.6l2.1 4.3H9.1l2.1-4.3Z"/>
      <rect class="accent" x="11" y="13" width="10" height="2.4" rx="1.2"/>
      <rect class="accent" x="11" y="17" width="8.2" height="2.4" rx="1.2" opacity=".74"/>
      <rect class="accent" x="11" y="21" width="5.8" height="2.4" rx="1.2" opacity=".48"/>
    `
  },
  {
    id: "feeder",
    zh: "自动喂食器",
    en: "Auto feeder",
    primary: "#3f74d8",
    accent: "#c8ff3d",
    shapes: `
      <rect class="primary" x="10.5" y="5" width="11" height="15.2" rx="4.4"/>
      <path class="primary" d="M7.4 19h17.2l-1.1 4.1A4.2 4.2 0 0 1 19.5 26h-7a4.2 4.2 0 0 1-4-2.9L7.4 19Z"/>
      <rect class="accent" x="13" y="9" width="6" height="3" rx="1.5"/>
      <circle class="accent-soft" cx="16" cy="16" r="2.6"/>
    `
  },
  {
    id: "water-change",
    zh: "换水",
    en: "Water change",
    primary: "#1c9ec2",
    accent: "#c8ff3d",
    shapes: `
      <path class="primary" d="M14.1 5.2c4.4 5.1 6.5 8.4 6.5 11.7a6.5 6.5 0 0 1-13 0c0-3.3 2.1-6.6 6.5-11.7Z"/>
      <path class="accent-line" d="M23.6 11a5.6 5.6 0 0 1 .8 7.7"/>
      <path class="accent-line" d="m24.4 18.8 3.2-.6-.8-3.1"/>
      <path class="accent-line" d="M21.6 24a5.6 5.6 0 0 1-.8-7.7"/>
      <path class="accent-line" d="m20.8 16.2-3.2.6.8 3.1"/>
    `
  },
  {
    id: "litter",
    zh: "猫砂",
    en: "Litter",
    primary: "#7b6ac8",
    accent: "#ffb36b",
    shapes: `
      <path class="primary" d="M6.7 17h18.6l-1.5 6.1A4.1 4.1 0 0 1 19.8 26h-7.6a4.1 4.1 0 0 1-4-2.9L6.7 17Z"/>
      <ellipse class="primary-soft" cx="16" cy="16.9" rx="9.3" ry="3.7"/>
      <circle class="accent" cx="9.7" cy="16.5" r=".78"/>
      <circle class="accent" cx="12.1" cy="15.2" r=".68"/>
      <circle class="accent" cx="14.5" cy="16.8" r=".76"/>
      <circle class="accent" cx="17.1" cy="15.5" r=".7"/>
      <circle class="accent" cx="19.5" cy="17.1" r=".8"/>
      <circle class="accent" cx="22" cy="15.8" r=".66"/>
      <circle class="accent-soft" cx="10.9" cy="19.1" r=".66"/>
      <circle class="accent-soft" cx="13.8" cy="18.5" r=".74"/>
      <circle class="accent-soft" cx="16.5" cy="19.5" r=".68"/>
      <circle class="accent-soft" cx="19.2" cy="18.8" r=".72"/>
      <circle class="accent-soft" cx="21.8" cy="19.5" r=".62"/>
    `
  },
  {
    id: "cleanup",
    zh: "清洁",
    en: "Cleanup",
    primary: "#2d88c8",
    accent: "#ffd36c",
    shapes: `
      <rect class="primary" x="8.4" y="17.4" width="15.8" height="6.2" rx="3.1" transform="rotate(-18 16.3 20.5)"/>
      <rect class="primary" x="13.5" y="7" width="4" height="13.5" rx="2" transform="rotate(-18 15.5 13.8)"/>
      <circle class="accent" cx="22.7" cy="8.5" r="2.2"/>
      <circle class="accent-soft" cx="25.4" cy="13" r="1.35"/>
      <circle class="accent-soft" cx="8.2" cy="24.5" r="1.5"/>
    `
  },
  {
    id: "walk-map",
    zh: "散步地图",
    en: "Walk map",
    primary: "#2b8f78",
    accent: "#c8ff3d",
    shapes: `
      <path class="primary" d="M16 5.2a6.2 6.2 0 0 1 6.2 6.2c0 4.7-6.2 10.4-6.2 10.4S9.8 16.1 9.8 11.4A6.2 6.2 0 0 1 16 5.2Z"/>
      <circle class="accent" cx="16" cy="11.5" r="2.4"/>
      <path class="primary-line" d="M7.5 24.8c3.3-2.2 6.7-2.3 10.3 0 2.3 1.5 4.7 1.5 6.8-.1"/>
    `
  },
  {
    id: "distance",
    zh: "距离",
    en: "Distance",
    primary: "#6370c8",
    accent: "#7be4d4",
    shapes: `
      <path class="primary-line" d="M7.8 22.4C11.6 15 20.4 18.6 23.8 10"/>
      <circle class="accent" cx="7.8" cy="22.4" r="3"/>
      <circle class="primary" cx="23.8" cy="10" r="3"/>
      <rect class="accent-soft" x="21.4" y="5.2" width="5.6" height="3.2" rx="1.6"/>
    `
  },
  {
    id: "training",
    zh: "训练",
    en: "Training",
    primary: "#ff755f",
    accent: "#c8ff3d",
    shapes: `
      <circle class="primary" cx="16" cy="16" r="10.4"/>
      <circle class="accent-soft" cx="16" cy="16" r="6.2"/>
      <circle class="accent" cx="16" cy="16" r="2.7"/>
      <rect class="primary" x="22.2" y="5.5" width="5.4" height="3.2" rx="1.6" transform="rotate(35 24.9 7.1)"/>
    `
  },
  {
    id: "mood",
    zh: "心情",
    en: "Mood",
    primary: "#5f6fd8",
    accent: "#ffd36c",
    shapes: `
      <circle class="primary" cx="16" cy="16" r="10.2"/>
      <circle class="accent" cx="20.2" cy="12.2" r="2.1"/>
      <path class="accent-line" d="M11.2 17.8c2.4 2.6 7.2 2.6 9.6 0"/>
    `
  },
  {
    id: "check-in",
    zh: "打卡",
    en: "Check-in",
    primary: "#2b8f78",
    accent: "#c8ff3d",
    shapes: `
      <rect class="primary" x="6.5" y="6.5" width="19" height="19" rx="9.5"/>
      <path class="accent-line" d="m10.8 16.2 3.6 3.6 7-8"/>
      <circle class="accent-soft" cx="23.1" cy="22.6" r="2.2"/>
    `
  },
  {
    id: "family",
    zh: "家庭",
    en: "Family",
    primary: "#298b9b",
    accent: "#ff9a6a",
    shapes: `
      <circle class="primary" cx="12.3" cy="10.6" r="4.2"/>
      <circle class="accent" cx="20.1" cy="11.9" r="3.4"/>
      <path class="primary" d="M5.8 24.6c.6-5 3.4-8 7-8s6.3 3 7 8H5.8Z"/>
      <path class="accent-soft" d="M15.4 24.6c.5-4 2.8-6.4 5.7-6.4 2.7 0 4.9 2.4 5.4 6.4H15.4Z"/>
    `
  },
  {
    id: "profile",
    zh: "档案",
    en: "Profile",
    primary: "#3f74d8",
    accent: "#7be4d4",
    shapes: `
      <rect class="primary" x="6.5" y="5.8" width="19" height="21" rx="5.5"/>
      <circle class="accent" cx="16" cy="13" r="3.4"/>
      <path class="accent-soft" d="M10.8 22.5c.6-3.6 2.6-5.5 5.2-5.5s4.6 1.9 5.2 5.5H10.8Z"/>
    `
  },
  {
    id: "privacy",
    zh: "隐私",
    en: "Privacy",
    primary: "#27313a",
    accent: "#c8ff3d",
    shapes: `
      <rect class="primary" x="7.8" y="14" width="16.4" height="12" rx="4.2"/>
      <path class="primary-line" d="M11.5 14v-2.2a4.5 4.5 0 0 1 9 0V14"/>
      <circle class="accent" cx="16" cy="20.1" r="2.3"/>
    `
  },
  {
    id: "expense",
    zh: "花费",
    en: "Expense",
    primary: "#2f8e62",
    accent: "#ffd36c",
    shapes: `
      <rect class="primary" x="6" y="9" width="20" height="15.8" rx="5"/>
      <rect class="accent-soft" x="8.6" y="12" width="14.8" height="3" rx="1.5"/>
      <text class="accent" x="16" y="21.4" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="10.6" font-weight="900">$</text>
    `
  },
  {
    id: "insurance",
    zh: "保险",
    en: "Insurance",
    primary: "#6370c8",
    accent: "#7be4d4",
    shapes: `
      <path class="primary" d="M16 4.8 24.5 8v6.3c0 5.8-3.1 10.3-8.5 12.9-5.4-2.6-8.5-7.1-8.5-12.9V8L16 4.8Z"/>
      <path class="accent-line" d="m11.9 15.9 2.8 2.9 5.5-6.2"/>
    `
  },
  {
    id: "document",
    zh: "文档",
    en: "Document",
    primary: "#3f74d8",
    accent: "#ffb36b",
    shapes: `
      <path class="primary" d="M9 5.5h10.4l4.1 4.2v16.8H9V5.5Z"/>
      <path class="accent-soft" d="M19.1 5.6v5h4.5l-4.5-5Z"/>
      <rect class="accent" x="12" y="15.1" width="8" height="2.4" rx="1.2"/>
      <rect class="accent-soft" x="12" y="19.6" width="6.2" height="2.4" rx="1.2"/>
    `
  },
  {
    id: "photo",
    zh: "照片",
    en: "Photo",
    primary: "#298b9b",
    accent: "#ffd36c",
    shapes: `
      <rect class="primary" x="6" y="8" width="20" height="16" rx="5"/>
      <circle class="accent" cx="20.8" cy="12.6" r="2.1"/>
      <path class="accent-soft" d="M9.4 22.2 14 16.8l3.4 3.8 2.1-2.3 3.5 3.9H9.4Z"/>
    `
  },
  {
    id: "birthday",
    zh: "生日",
    en: "Birthday",
    primary: "#ff755f",
    accent: "#ffd36c",
    shapes: `
      <rect class="primary" x="7" y="15.2" width="18" height="10.3" rx="4"/>
      <rect class="accent-soft" x="9" y="12.2" width="14" height="4.8" rx="2.4"/>
      <rect class="primary" x="14.6" y="6.6" width="2.8" height="6.8" rx="1.4"/>
      <path class="accent" d="M16 4.3c1.5 1.8 2.2 2.8 2.2 3.8a2.2 2.2 0 0 1-4.4 0c0-1 .7-2 2.2-3.8Z"/>
    `
  },
  {
    id: "reward",
    zh: "奖励",
    en: "Reward",
    primary: "#b87935",
    accent: "#c8ff3d",
    shapes: `
      <circle class="primary" cx="16" cy="12.6" r="7.5"/>
      <path class="primary" d="m11.4 18 3.2 8.5 2.2-3 3.2 1.4-3.2-8.3-5.4 1.4Z"/>
      <circle class="accent" cx="16" cy="12.6" r="3.2"/>
    `
  },
  {
    id: "temperature",
    zh: "温湿度",
    en: "Temperature",
    primary: "#20a0b8",
    accent: "#ff755f",
    shapes: `
      <rect class="primary" x="13" y="5.2" width="6" height="15" rx="3"/>
      <circle class="primary" cx="16" cy="22" r="5.2"/>
      <rect class="accent" x="15" y="9.2" width="2" height="11.8" rx="1"/>
      <circle class="accent" cx="16" cy="22" r="2.4"/>
      <circle class="accent-soft" cx="23.7" cy="9.4" r="2.2"/>
    `
  },
  {
    id: "plant-fertilize",
    zh: "植物施肥",
    en: "Plant fertilize",
    primary: "#2f8e62",
    accent: "#ffb36b",
    shapes: `
      <path class="primary" d="M9.1 18h13.8l-1.1 5A4.2 4.2 0 0 1 17.7 26h-3.4a4.2 4.2 0 0 1-4.1-3L9.1 18Z"/>
      <path class="primary" d="M15.5 17.8c-1.2-4.4-4.3-6.6-8.3-6.5 1 4.1 4 6.3 8.3 6.5Z"/>
      <path class="primary" d="M16.7 17.2c.8-4.8 3.6-7.5 7.8-8c-.4 4.7-3.3 7.6-7.8 8Z"/>
      <circle class="accent" cx="23.8" cy="20.5" r="2"/>
      <circle class="accent-soft" cx="25.8" cy="15.6" r="1.4"/>
    `
  },
  {
    id: "notification-health",
    zh: "提醒健康",
    en: "Notification health",
    primary: "#3f74d8",
    accent: "#ff6d78",
    shapes: `
      <path class="primary" d="M10 20.4v-5.6a6 6 0 1 1 12 0v5.6l2.1 2.6H7.9l2.1-2.6Z"/>
      <path class="primary" d="M13.2 24h5.6a2.9 2.9 0 0 1-5.6 0Z"/>
      <path class="accent" d="M22.4 12.9s-3.2-1.9-3.2-4.1c0-1.2.8-2.1 1.9-2.1.6 0 1.1.3 1.3.8.2-.5.7-.8 1.3-.8 1.1 0 1.9.9 1.9 2.1 0 2.2-3.2 4.1-3.2 4.1Z"/>
    `
  },
  {
    id: "settings",
    zh: "设置",
    en: "Settings",
    primary: "#27313a",
    accent: "#7be4d4",
    shapes: `
      <rect class="primary" x="14.3" y="3.6" width="3.4" height="6.2" rx="1.7"/>
      <rect class="primary" x="14.3" y="22.2" width="3.4" height="6.2" rx="1.7"/>
      <rect class="primary" x="22.2" y="14.3" width="6.2" height="3.4" rx="1.7"/>
      <rect class="primary" x="3.6" y="14.3" width="6.2" height="3.4" rx="1.7"/>
      <rect class="primary" x="14.3" y="3.6" width="3.4" height="6.2" rx="1.7" transform="rotate(45 16 16)"/>
      <rect class="primary" x="14.3" y="22.2" width="3.4" height="6.2" rx="1.7" transform="rotate(45 16 16)"/>
      <rect class="primary" x="22.2" y="14.3" width="6.2" height="3.4" rx="1.7" transform="rotate(45 16 16)"/>
      <rect class="primary" x="3.6" y="14.3" width="6.2" height="3.4" rx="1.7" transform="rotate(45 16 16)"/>
      <circle class="primary" cx="16" cy="16" r="7.6"/>
      <circle class="accent-soft" cx="16" cy="16" r="4"/>
      <circle class="accent" cx="16" cy="16" r="2"/>
    `
  }
];

function directShapes(icon) {
  return icon.shapes
    .replaceAll('class="primary-thin-line"', `style="fill:none;stroke:${icon.primary};stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round"`)
    .replaceAll('class="accent-thin-line"', `style="fill:none;stroke:${icon.accent};stroke-width:2.1;stroke-linecap:round;stroke-linejoin:round"`)
    .replaceAll('class="primary-line"', `style="fill:none;stroke:${icon.primary};stroke-width:4.2;stroke-linecap:round;stroke-linejoin:round"`)
    .replaceAll('class="accent-line"', `style="fill:none;stroke:${icon.accent};stroke-width:3;stroke-linecap:round;stroke-linejoin:round"`)
    .replaceAll('class="primary-soft"', `style="fill:${icon.primary};opacity:.22"`)
    .replaceAll('class="accent-soft"', `style="fill:${icon.accent};opacity:.28"`)
    .replaceAll('class="primary"', `style="fill:${icon.primary}"`)
    .replaceAll('class="accent"', `style="fill:${icon.accent}"`);
}

function svgForIcon(icon, { inline = false, variable = false } = {}) {
  const title = `${icon.en} / ${icon.zh}`;
  const style = inline
    ? ""
    : variable
      ? ` style="--ohana-icon-primary: ${icon.primary}; --ohana-icon-accent: ${icon.accent};"`
      : "";
  const classBlock = inline || !variable ? "" : `\n  <style>${classes}\n  </style>`;
  const shapes = inline || variable ? icon.shapes : directShapes(icon);
  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" width="32" height="32" role="img" aria-label="${title}" class="ohana-duotone-icon"${style}>${classBlock}
  <title>${title}</title>
  <g>
${shapes.trimEnd()}
  </g>
</svg>
`;
}

function previewSvg() {
  const cell = 132;
  const margin = 34;
  const columns = 4;
  const rows = Math.ceil(icons.length / columns);
  const width = margin * 2 + cell * 4;
  const height = 42 + rows * 136 + 34;
  const cards = icons.map((icon, index) => {
    const col = index % columns;
    const row = Math.floor(index / columns);
    const x = margin + col * cell;
    const y = 42 + row * 136;
    return `
    <g transform="translate(${x} ${y})" style="--ohana-icon-primary: ${icon.primary}; --ohana-icon-accent: ${icon.accent};">
      <rect x="0" y="0" width="104" height="104" rx="28" fill="#fffaf0"/>
      <g transform="translate(20 16) scale(2)">${directShapes(icon)}</g>
      <text x="52" y="124" text-anchor="middle" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="12" font-weight="650" fill="#2e3438">${icon.zh}</text>
    </g>`;
  }).join("\n");

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${width} ${height}" width="${width}" height="${height}">
  <style>${classes}
  </style>
  <rect width="${width}" height="${height}" rx="36" fill="#eef3ef"/>
  <text x="${margin}" y="27" font-family="-apple-system, BlinkMacSystemFont, 'SF Pro Display', sans-serif" font-size="16" font-weight="750" fill="#1f2930">Ohana Duotone Solid Icons</text>
${cards}
</svg>
`;
}

function motionDemoStyles() {
  return `
    .motion-demo {
      margin: 0 0 24px;
      padding: 18px;
      border-radius: 28px;
      background: rgba(255, 250, 240, .86);
      border: 1px solid rgba(31, 41, 48, .08);
      display: grid;
      grid-template-columns: minmax(220px, 310px) minmax(260px, 1fr);
      gap: 18px;
      align-items: stretch;
    }
    .motion-stage {
      min-height: 310px;
      border-radius: 22px;
      background: #eaf3ef;
      display: grid;
      place-items: center;
      text-align: center;
    }
    .motion-icon-button {
      width: min(210px, 64vw);
      aspect-ratio: 1;
      padding: 0;
      border-radius: 32px;
      display: grid;
      place-items: center;
      background: #eef7f3;
      box-shadow:
        inset 0 0 0 1px rgba(31, 138, 138, .1),
        0 18px 36px rgba(25, 68, 64, .12);
      transition: transform 180ms ease, box-shadow 180ms ease, background-color 180ms ease;
      -webkit-tap-highlight-color: transparent;
    }
    .motion-icon-button:hover {
      transform: translateY(-2px);
      box-shadow:
        inset 0 0 0 1px rgba(31, 138, 138, .14),
        0 24px 46px rgba(25, 68, 64, .16);
    }
    .motion-icon-button:active { transform: scale(.97); }
    .motion-icon-button:focus-visible {
      outline: 3px solid rgba(255, 117, 95, .7);
      outline-offset: 5px;
    }
    .motion-feed-icon {
      width: 72%;
      height: 72%;
      display: block;
      overflow: visible;
    }
    .motion-bowl,
    .motion-food-shadow,
    .motion-grain,
    .motion-badge {
      transform-box: fill-box;
      transform-origin: center;
    }
    .motion-bowl {
      filter: drop-shadow(0 3px 2px rgba(31, 138, 138, .12));
    }
    .motion-food-shadow {
      opacity: 0;
      transform: translateY(2px) scale(.72);
      transition: opacity 260ms ease, transform 260ms ease;
    }
    .motion-grain {
      opacity: .08;
      transform: translateY(2.6px) scale(.68);
    }
    .motion-grain-a { --grain-delay: 40ms; --grain-out-delay: 0ms; }
    .motion-grain-b { --grain-delay: 120ms; --grain-out-delay: 70ms; }
    .motion-grain-c { --grain-delay: 200ms; --grain-out-delay: 35ms; }
    .motion-badge {
      opacity: 0;
      transform: scale(.6);
      transition: opacity 180ms ease, transform 180ms ease;
    }
    .motion-demo[data-feed-state="feeding"] .motion-icon-button { background: #edf6f2; }
    .motion-demo[data-feed-state="feeding"] .motion-bowl {
      animation: motion-bowl-ready 680ms cubic-bezier(.2, .9, .24, 1);
    }
    .motion-demo[data-feed-state="feeding"] .motion-food-shadow {
      animation: motion-food-shadow-in 620ms ease forwards;
    }
    .motion-demo[data-feed-state="feeding"] .motion-grain {
      animation: motion-grain-drop 720ms cubic-bezier(.18, .95, .24, 1) forwards;
      animation-delay: var(--grain-delay);
    }
    .motion-demo[data-feed-state="fed"] .motion-food-shadow {
      opacity: .22;
      transform: translateY(0) scale(1);
    }
    .motion-demo[data-feed-state="fed"] .motion-grain {
      opacity: 1;
      transform: translateY(0) scale(1);
    }
    .motion-demo[data-feed-state="fed"] .motion-badge {
      opacity: 1;
      transform: scale(1);
    }
    .motion-demo[data-feed-state="clearing"] .motion-food-shadow {
      animation: motion-food-shadow-out 420ms ease forwards;
    }
    .motion-demo[data-feed-state="clearing"] .motion-grain {
      animation: motion-grain-clear 480ms ease-in forwards;
      animation-delay: var(--grain-out-delay);
    }
    .motion-demo[data-feed-state="clearing"] .motion-badge {
      opacity: 0;
      transform: scale(.72);
    }
    @keyframes motion-grain-drop {
      0% { opacity: 0; transform: translateY(-11px) scale(.56); }
      58% { opacity: 1; transform: translateY(1.5px) scale(1.12); }
      100% { opacity: 1; transform: translateY(0) scale(1); }
    }
    @keyframes motion-grain-clear {
      0% { opacity: 1; transform: translateY(0) scale(1); }
      100% { opacity: .08; transform: translateY(2.8px) scale(.66); }
    }
    @keyframes motion-bowl-ready {
      0%, 100% { transform: scale(1); }
      44% { transform: scale(1.045); }
    }
    @keyframes motion-food-shadow-in {
      0% { opacity: 0; transform: translateY(2px) scale(.72); }
      100% { opacity: .22; transform: translateY(0) scale(1); }
    }
    @keyframes motion-food-shadow-out {
      0% { opacity: .22; transform: translateY(0) scale(1); }
      100% { opacity: 0; transform: translateY(2px) scale(.72); }
    }
    .motion-copy {
      padding: 4px 0;
      display: grid;
      gap: 14px;
      align-content: center;
    }
    .motion-copy h2 {
      margin: 0;
      font-size: 18px;
      line-height: 1.15;
      letter-spacing: 0;
    }
    .motion-state {
      min-height: 34px;
      display: inline-grid;
      place-items: center;
      justify-self: start;
      padding: 8px 13px;
      border-radius: 999px;
      color: var(--ohana-icon-primary);
      background: rgba(31, 138, 138, .1);
      font-size: 13px;
      font-weight: 800;
    }
    .motion-steps {
      margin: 0;
      padding: 0;
      list-style: none;
      display: grid;
      grid-template-columns: repeat(2, minmax(0, 1fr));
      gap: 10px;
    }
    .motion-step {
      min-height: 88px;
      padding: 12px;
      border-radius: 16px;
      border: 1px solid rgba(31, 41, 48, .08);
      background: rgba(255, 255, 255, .62);
      transition: border-color 180ms ease, background-color 180ms ease, transform 180ms ease;
    }
    .motion-step strong {
      display: block;
      font-size: 12px;
      line-height: 1.25;
    }
    .motion-step span {
      display: block;
      margin-top: 5px;
      color: var(--muted);
      font-size: 11px;
      line-height: 1.45;
    }
    .motion-demo[data-feed-state="empty"] .motion-step[data-step="empty"],
    .motion-demo[data-feed-state="feeding"] .motion-step[data-step="feeding"],
    .motion-demo[data-feed-state="fed"] .motion-step[data-step="fed"],
    .motion-demo[data-feed-state="clearing"] .motion-step[data-step="clearing"] {
      border-color: rgba(31, 138, 138, .32);
      background: rgba(31, 138, 138, .08);
      transform: translateY(-1px);
    }
`;
}

function motionDemoMarkup() {
  return `
    <section class="motion-demo" data-feed-state="empty" aria-label="喂食图标动画测试">
      <div class="motion-stage">
        <button class="motion-icon-button" type="button" aria-pressed="false" aria-label="播放喂食图标动画">
          <svg class="motion-feed-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" role="img" aria-labelledby="motionFeedTitle motionFeedDesc">
            <title id="motionFeedTitle">喂食图标动画</title>
            <desc id="motionFeedDesc">点击后，饭碗里的粮食圆点从透明变为实色，再次点击会淡出回到空碗。</desc>
            <ellipse class="motion-food-shadow primary-soft" cx="16" cy="13.3" rx="10.2" ry="4.8"/>
            <path class="motion-bowl primary" d="M5.6 13.7h20.8l-1.5 7.5A5.8 5.8 0 0 1 19.2 26h-6.4a5.8 5.8 0 0 1-5.7-4.8l-1.5-7.5Z"/>
            <rect class="motion-bowl primary" x="9.3" y="23.6" width="13.4" height="2.7" rx="1.35"/>
            <path class="accent" d="M16 21.7c-1.8-1-3-2.3-3-3.6 0-1 .7-1.7 1.5-1.7.6 0 1.1.3 1.5.9.4-.6.9-.9 1.5-.9.8 0 1.5.7 1.5 1.7 0 1.3-1.2 2.6-3 3.6Z"/>
            <circle class="motion-grain motion-grain-a accent" cx="11.3" cy="11.8" r="2.05"/>
            <circle class="motion-grain motion-grain-b accent" cx="15.8" cy="10.6" r="2.45"/>
            <circle class="motion-grain motion-grain-c accent" cx="20.2" cy="12" r="2"/>
            <g class="motion-badge" aria-hidden="true">
              <circle fill="#fff" cx="23.9" cy="23.7" r="4.15"/>
              <circle class="accent" cx="23.9" cy="23.7" r="3.25"/>
              <path d="M22.35 23.55l1.05 1.1 2.2-2.35" fill="none" stroke="#fff" stroke-width="1.35" stroke-linecap="round" stroke-linejoin="round"/>
            </g>
          </svg>
        </button>
      </div>
      <div class="motion-copy">
        <div>
          <h2>喂食动效测试</h2>
          <p>点击饭碗图标切换状态。它复用上方色板，方便同时看静态图标和动画效果。</p>
        </div>
        <div class="motion-state" data-feed-status-title aria-live="polite">空碗</div>
        <p data-feed-status-copy>粮食圆点保持低透明度，表示还没有完成今天的喂食。</p>
        <ul class="motion-steps" aria-label="喂食动画说明">
          <li class="motion-step" data-step="empty">
            <strong>空碗 / 未打卡</strong>
            <span>粮食圆点低透明度并略微缩小，保留待投喂的暗示。</span>
          </li>
          <li class="motion-step" data-step="feeding">
            <strong>投喂中 / 点击过渡</strong>
            <span>三个圆点依次落入碗里，从透明变成实色。</span>
          </li>
          <li class="motion-step" data-step="fed">
            <strong>已经喂食 / 已打卡</strong>
            <span>粮食保持实色，碗内阴影出现，右下角显示完成角标。</span>
          </li>
          <li class="motion-step" data-step="clearing">
            <strong>回到空碗 / 撤销打卡</strong>
            <span>粮食圆点淡出并缩回，完成角标消失。</span>
          </li>
        </ul>
      </div>
    </section>
`;
}

function motionDemoScript() {
  return `
    const motionDemo = document.querySelector(".motion-demo");
    const motionButton = document.querySelector(".motion-icon-button");
    const motionStatusTitle = document.querySelector("[data-feed-status-title]");
    const motionStatusCopy = document.querySelector("[data-feed-status-copy]");
    const reducedMotion = window.matchMedia("(prefers-reduced-motion: reduce)");
    const feedStates = {
      empty: {
        title: "空碗",
        copy: "粮食圆点保持低透明度，表示还没有完成今天的喂食。",
        pressed: "false",
        label: "播放喂食图标动画"
      },
      feeding: {
        title: "投喂中",
        copy: "粮食圆点依次从上方出现，落入饭碗并变成实色。",
        pressed: "true",
        label: "喂食动画播放中"
      },
      fed: {
        title: "已经喂食",
        copy: "粮食圆点保持实色，完成角标出现，表示今天已经喂食。",
        pressed: "true",
        label: "回到空碗状态"
      },
      clearing: {
        title: "回到空碗",
        copy: "粮食圆点淡出并缩回，完成角标消失。",
        pressed: "false",
        label: "清空动画播放中"
      }
    };
    let feedMotionState = "empty";
    let feedMotionTimer = null;
    function setFeedMotionState(nextState) {
      feedMotionState = nextState;
      motionDemo.dataset.feedState = nextState;
      motionStatusTitle.textContent = feedStates[nextState].title;
      motionStatusCopy.textContent = feedStates[nextState].copy;
      motionButton.setAttribute("aria-pressed", feedStates[nextState].pressed);
      motionButton.setAttribute("aria-label", feedStates[nextState].label);
    }
    function scheduleFeedMotion(nextState, delay) {
      clearTimeout(feedMotionTimer);
      feedMotionTimer = window.setTimeout(() => setFeedMotionState(nextState), reducedMotion.matches ? 1 : delay);
    }
    motionButton.addEventListener("click", () => {
      if (feedMotionState === "feeding" || feedMotionState === "clearing") return;
      if (feedMotionState === "empty") {
        setFeedMotionState("feeding");
        scheduleFeedMotion("fed", 920);
        return;
      }
      setFeedMotionState("clearing");
      scheduleFeedMotion("empty", 560);
    });
`;
}

function previewHtml() {
  const inlineIcons = icons.map((icon) => `
        <figure class="icon-card" aria-label="${icon.en}">
          <div class="icon-box">
            ${svgForIcon(icon, { inline: true })}
          </div>
          <figcaption>${icon.zh}<small>${icon.en}</small></figcaption>
        </figure>`).join("\n");

  return `<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Ohana Duotone Solid Icon Set</title>
  <style>
    :root {
      --ohana-icon-primary: #1f8a8a;
      --ohana-icon-accent: #ff755f;
      --page-bg: #eef3ef;
      --card-bg: #fffaf0;
      --ink: #1f2930;
      --muted: #65727a;
    }
${classes}
    * { box-sizing: border-box; }
    body {
      margin: 0;
      background: var(--page-bg);
      color: var(--ink);
      font-family: -apple-system, BlinkMacSystemFont, "SF Pro Display", "PingFang SC", sans-serif;
    }
    main { width: min(1080px, calc(100vw - 32px)); margin: 32px auto 48px; }
    header { display: flex; align-items: end; justify-content: space-between; gap: 24px; margin-bottom: 22px; }
    h1 { margin: 0; font-size: 26px; line-height: 1.1; letter-spacing: 0; }
    p { margin: 8px 0 0; color: var(--muted); font-size: 14px; line-height: 1.5; }
    .controls {
      display: flex;
      flex-wrap: wrap;
      gap: 10px;
      align-items: center;
      padding: 12px;
      background: rgba(255, 250, 240, .78);
      border: 1px solid rgba(31, 41, 48, .08);
      border-radius: 18px;
    }
    label { display: flex; align-items: center; gap: 8px; font-size: 12px; font-weight: 700; color: var(--muted); }
    input[type="color"] { width: 34px; height: 34px; border: 0; padding: 0; background: transparent; }
    button {
      border: 0;
      padding: 9px 12px;
      border-radius: 999px;
      background: #ffffff;
      color: var(--ink);
      font: inherit;
      font-size: 12px;
      font-weight: 750;
      box-shadow: inset 0 0 0 1px rgba(31, 41, 48, .08);
      cursor: pointer;
    }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(132px, 1fr)); gap: 16px; }
    .icon-card {
      margin: 0;
      min-height: 150px;
      padding: 18px 14px 14px;
      border-radius: 28px;
      background: var(--card-bg);
      display: grid;
      place-items: center;
      gap: 10px;
    }
    .icon-box { width: 72px; height: 72px; display: grid; place-items: center; }
    .icon-box svg { width: 72px; height: 72px; display: block; }
    figcaption { text-align: center; font-size: 13px; font-weight: 760; line-height: 1.25; }
    figcaption small { display: block; margin-top: 3px; font-size: 10px; color: var(--muted); font-weight: 650; }
${motionDemoStyles()}
    @media (max-width: 720px) {
      header { align-items: stretch; flex-direction: column; }
      .controls { align-self: start; }
      .motion-demo { grid-template-columns: 1fr; }
      .motion-steps { grid-template-columns: 1fr; }
    }
    @media (prefers-reduced-motion: reduce) {
      .motion-demo *,
      .motion-demo *::before,
      .motion-demo *::after {
        animation-duration: 1ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 1ms !important;
      }
    }
  </style>
</head>
<body>
  <main>
    <header>
      <div>
        <h1>Ohana 双色实心几何图标</h1>
        <p>透明 SVG 图标。用下方色板切换全套主色和强调色，图标文件内也保留同名 CSS 变量。</p>
      </div>
      <section class="controls" aria-label="Icon color controls">
        <label>主色 <input id="primary" type="color" value="#1f8a8a"></label>
        <label>强调 <input id="accent" type="color" value="#ff755f"></label>
        <button data-primary="#1f8a8a" data-accent="#ff755f">Teal Coral</button>
        <button data-primary="#3f74d8" data-accent="#c8ff3d">Blue Lime</button>
        <button data-primary="#2f8e62" data-accent="#7be4d4">Island Mint</button>
        <button data-primary="#5f6fd8" data-accent="#ffd36c">Lavender Sun</button>
        <button data-primary="#27313a" data-accent="#ff9a6a">Ink Apricot</button>
      </section>
    </header>
${motionDemoMarkup()}
    <section class="grid">
${inlineIcons}
    </section>
  </main>
  <script>
    const root = document.documentElement;
    const primary = document.querySelector("#primary");
    const accent = document.querySelector("#accent");
    function setColors(nextPrimary, nextAccent) {
      root.style.setProperty("--ohana-icon-primary", nextPrimary);
      root.style.setProperty("--ohana-icon-accent", nextAccent);
      primary.value = nextPrimary;
      accent.value = nextAccent;
    }
    primary.addEventListener("input", () => root.style.setProperty("--ohana-icon-primary", primary.value));
    accent.addEventListener("input", () => root.style.setProperty("--ohana-icon-accent", accent.value));
    document.querySelectorAll("button[data-primary]").forEach((button) => {
      button.addEventListener("click", () => setColors(button.dataset.primary, button.dataset.accent));
    });
${motionDemoScript()}
  </script>
</body>
</html>
`;
}

function readme() {
  const list = icons.map((icon) => `- \`${icon.id}\`: ${icon.zh} / ${icon.en}`).join("\n");
  return `# Ohana Duotone Solid Icon Set

这套图标延续选中的第三行方向：双色实心几何 glyph。每个图标都是透明背景 SVG，由一个主形体加少量强调色几何元素组成，适合 24pt、28pt、32pt 的应用内入口、快捷操作和卡片状态。

## 内容

${list}

## 调色

每个 SVG 都使用两个 CSS 变量：

\`\`\`css
--ohana-icon-primary: #1f8a8a;
--ohana-icon-accent: #ff755f;
\`\`\`

在网页或设计稿里使用 inline SVG 时，可以在父容器或 svg 根节点覆盖这两个变量。直接作为 iOS Asset 使用时，Xcode 会把 SVG 当作静态矢量资源；如果要在 SwiftUI 运行时动态换色，建议下一步把选定图标转换成 SwiftUI Shape 或模板化矢量组件。

## 文件

- \`icons/*.svg\`: 单个透明 SVG 图标，使用静态颜色，适合直接预览和导入设计工具/Xcode。
- \`icons-variable/*.svg\`: 使用 CSS 变量的版本，适合 inline SVG 调色。
- \`preview.svg\`: 默认配色总览图。
- \`preview.html\`: 可交互调色预览。
- \`generate-icons.mjs\`: 生成脚本，便于后续批量增删图标或调整几何。
`;
}

mkdirSync(iconsDir, { recursive: true });
mkdirSync(variableIconsDir, { recursive: true });

for (const icon of icons) {
  writeFileSync(join(iconsDir, `ohana-icon-${icon.id}.svg`), svgForIcon(icon));
  writeFileSync(join(variableIconsDir, `ohana-icon-${icon.id}.svg`), svgForIcon(icon, { variable: true }));
}

writeFileSync(join(here, "preview.svg"), previewSvg());
writeFileSync(join(here, "preview.html"), previewHtml());
writeFileSync(join(here, "README.md"), readme());
