import {
  Briefcase, Car, Flame, IdCard, ListChecks, type LucideIcon, NotebookText, Settings, Sparkles, Store, Sun, Target,
  TrendingUp, Wallet,
} from "lucide-react";

export interface Section {
  href: string;
  title: string;
  icon: LucideIcon;
  /** Ação do ⌘N nesta secção (o formulário abre com `?novo=1`). */
  newLabel?: string;
}

/**
 * Secções na ordem do mockup: as 9 primeiras abrem com ⌘1–⌘9.
 * São as mesmas 13 do iPhone (`AppSection`).
 */
export const sections: Section[] = [
  { href: "/hoje/", title: "Hoje", icon: Sun, newLabel: "Novo gasto" },
  { href: "/financas/", title: "Finanças", icon: Wallet, newLabel: "Novo movimento" },
  { href: "/loja/", title: "Loja", icon: Store },
  { href: "/projetos/", title: "Projetos", icon: ListChecks, newLabel: "Nova tarefa" },
  { href: "/notas/", title: "Notas", icon: NotebookText, newLabel: "Nova página" },
  { href: "/carro/", title: "Carro", icon: Car, newLabel: "Novo abastecimento" },
  { href: "/documentos/", title: "Documentos", icon: IdCard, newLabel: "Novo documento" },
  { href: "/carreira/", title: "Carreira", icon: Briefcase, newLabel: "Nova candidatura" },
  { href: "/patrimonio/", title: "Património", icon: TrendingUp, newLabel: "Novo investimento" },
  { href: "/metas/", title: "Metas", icon: Target, newLabel: "Nova meta" },
  { href: "/habitos/", title: "Hábitos", icon: Flame, newLabel: "Novo hábito" },
  { href: "/perguntar/", title: "Pergunte ao Mynik", icon: Sparkles },
];

export const settingsSection: Section = { href: "/definicoes/", title: "Definições", icon: Settings };

export const allSections = [...sections, settingsSection];

export function sectionFor(pathname: string) {
  return allSections.find((s) => pathname.startsWith(s.href.replace(/\/$/, "")));
}
