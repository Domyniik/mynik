import {
  Banknote, BedDouble, Bike, Book, BookOpen, Brain, Briefcase, BriefcaseMedical, Bus, Car, CircleCheck, CirclePlus,
  Dumbbell, Droplet, Ellipsis, Euro, Folder, Footprints, Gamepad2, Gift, GraduationCap, Hammer, Heart, House,
  Landmark, Laptop, Leaf, type LucideIcon, Music, Paintbrush, Plane, Repeat, Shield, ShoppingBag, ShoppingCart,
  Smartphone, Sparkles, Store, Tag, Target, TramFront, TrendingUp, Utensils, Camera, Bitcoin, PiggyBank, Fuel,
} from "lucide-react";
import { cn } from "./utils";

/**
 * Os ícones guardam-se como nomes de SF Symbols (os do iPhone); no desktop
 * mostram-se com o ícone lucide equivalente.
 */
const symbols: Record<string, LucideIcon> = {
  tag: Tag,
  cart: ShoppingCart,
  house: House,
  tram: TramFront,
  bus: Bus,
  car: Car,
  "cross.case": BriefcaseMedical,
  gamecontroller: Gamepad2,
  bag: ShoppingBag,
  repeat: Repeat,
  "ellipsis.circle": Ellipsis,
  briefcase: Briefcase,
  storefront: Store,
  "plus.circle": CirclePlus,
  folder: Folder,
  hammer: Hammer,
  laptopcomputer: Laptop,
  paintbrush: Paintbrush,
  book: Book,
  airplane: Plane,
  dumbbell: Dumbbell,
  graduationcap: GraduationCap,
  camera: Camera,
  "music.note": Music,
  heart: Heart,
  leaf: Leaf,
  target: Target,
  iphone: Smartphone,
  gift: Gift,
  banknote: Banknote,
  shield: Shield,
  bicycle: Bike,
  sparkles: Sparkles,
  "fork.knife": Utensils,
  "checkmark.circle": CircleCheck,
  "figure.run": Footprints,
  drop: Droplet,
  "bed.double": BedDouble,
  "brain.head.profile": Brain,
  "eurosign.circle": Euro,
  "chart.line.uptrend.xyaxis": TrendingUp,
  "building.columns": Landmark,
  "bitcoinsign.circle": Bitcoin,
  "chart.pie": PiggyBank,
  "book.closed": BookOpen,
  fuelpump: Fuel,
};

export const projectSymbols = ["folder", "hammer", "laptopcomputer", "paintbrush", "book", "house", "car", "airplane", "dumbbell", "graduationcap", "briefcase", "storefront", "camera", "music.note", "heart", "leaf"];
export const goalSymbols = ["target", "airplane", "car", "house", "laptopcomputer", "iphone", "gift", "graduationcap", "heart", "banknote", "shield", "camera", "bicycle", "sparkles", "storefront", "fork.knife"];
export const habitSymbols = ["checkmark.circle", "figure.run", "dumbbell", "book", "drop", "bed.double", "leaf", "brain.head.profile", "eurosign.circle", "laptopcomputer", "music.note", "fork.knife"];
export const categorySymbols = ["cart", "house", "tram", "car", "cross.case", "gamecontroller", "bag", "repeat", "fork.knife", "airplane", "gift", "heart", "book", "briefcase", "storefront", "banknote", "plus.circle", "ellipsis.circle", "tag"];

/** As 12 cores de `CategoryColor` no iPhone. */
export const colors: Record<string, { hex: string; name: string }> = {
  red: { hex: "#f87171", name: "Vermelho" },
  orange: { hex: "#fb923c", name: "Laranja" },
  yellow: { hex: "#facc15", name: "Amarelo" },
  green: { hex: "#4ade80", name: "Verde" },
  mint: { hex: "#34d399", name: "Menta" },
  teal: { hex: "#2dd4bf", name: "Azul-petróleo" },
  blue: { hex: "#60a5fa", name: "Azul" },
  indigo: { hex: "#818cf8", name: "Índigo" },
  purple: { hex: "#c084fc", name: "Roxo" },
  pink: { hex: "#f472b6", name: "Rosa" },
  brown: { hex: "#c08457", name: "Castanho" },
  gray: { hex: "#9ca3af", name: "Cinzento" },
};

export const colorHex = (name: string | null | undefined) => colors[name ?? ""]?.hex ?? colors.gray.hex;

export function symbolIcon(name: string | null | undefined): LucideIcon {
  return symbols[name ?? ""] ?? Tag;
}

/** Ícone de um SF Symbol num quadrado com a cor (como o `IconBadge` do iPhone). */
export function SymbolIcon({ name, color, size = 32, className }: { name?: string | null; color?: string | null; size?: number; className?: string }) {
  const Icon = symbolIcon(name);
  const hex = colorHex(color);
  return (
    <span
      aria-hidden="true"
      className={cn("inline-flex shrink-0 items-center justify-center rounded-lg", className)}
      style={{ width: size, height: size, background: `${hex}22`, color: hex }}
    >
      <Icon size={Math.round(size * 0.55)} strokeWidth={1.9} />
    </span>
  );
}
