import type { NextConfig } from "next";

// Exportação estática: o mesmo build serve o browser e a app desktop (Tauri).
// Tudo o que precisa de servidor (Shopify, cotações, combustível) está nas
// Edge Functions do Supabase, por isso não há rotas de API aqui.
const config: NextConfig = {
  output: "export",
  trailingSlash: true,
  images: { unoptimized: true },
  reactStrictMode: true,
};

export default config;
