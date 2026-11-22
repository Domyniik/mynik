"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useSession } from "@/lib/session";
import { cn } from "@/lib/utils";
import { type Section, sections, settingsSection } from "./nav";

function NavLink({ section, index }: { section: Section; index?: number }) {
  const pathname = usePathname();
  const active = pathname.startsWith(section.href.replace(/\/$/, ""));
  const Icon = section.icon;
  return (
    <Link
      href={section.href}
      aria-current={active ? "page" : undefined}
      title={index != null && index < 9 ? `${section.title} (⌘${index + 1})` : section.title}
      className={cn(
        "flex min-h-[38px] items-center gap-2.5 rounded-lg px-2.5 font-medium no-underline transition-colors",
        active ? "bg-sidebar-active text-white" : "text-sidebar-foreground hover:bg-sidebar-active/60 hover:text-foreground",
      )}
    >
      <Icon size={18} strokeWidth={1.8} aria-hidden="true" />
      <span className="truncate">{section.title}</span>
    </Link>
  );
}

export function Sidebar() {
  const { status, email } = useSession();
  const name = email?.split("@")[0] ?? "Demonstração";
  return (
    <nav
      aria-label="Navegação principal"
      className="flex h-full w-[232px] shrink-0 flex-col gap-1 border-r border-border bg-sidebar px-3.5 py-5"
    >
      <div className="flex items-center gap-2.5 px-2.5 pb-4">
        <div className="flex size-[30px] items-center justify-center rounded-lg bg-primary font-bold text-white">M</div>
        <div className="text-[17px] font-bold tracking-tight">Mynik</div>
      </div>
      <div className="flex min-h-0 flex-1 flex-col gap-1 overflow-y-auto">
        {sections.map((section, index) => (
          <NavLink key={section.href} section={section} index={index} />
        ))}
      </div>
      <NavLink section={settingsSection} />
      <div className="mt-2 flex items-center gap-2.5 border-t border-border px-2.5 pt-3">
        <div className="flex size-7 items-center justify-center rounded-full bg-input text-xs font-semibold uppercase">
          {name[0]}
        </div>
        <div className="flex min-w-0 flex-col">
          <span className="truncate font-semibold capitalize">{name}</span>
          <span className="text-xs text-muted-foreground">
            {status === "demo" ? "Dados de exemplo" : "Sincronizado"}
          </span>
        </div>
      </div>
    </nav>
  );
}
