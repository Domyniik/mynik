import { classMeta, type ProductClass } from "@/lib/calc/store";

/** Selo da classificação com as cores do mockup (Vencedor, Promissor, Em teste, Perdedor). */
export function ClassBadge({ value }: { value: ProductClass }) {
  const meta = classMeta[value];
  return (
    <span className="inline-block rounded-md px-2 py-[3px] text-xs font-semibold" style={{ color: meta.fg, background: meta.bg }}>
      {meta.title}
    </span>
  );
}
