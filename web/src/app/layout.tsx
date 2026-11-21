import type { Metadata, Viewport } from "next";
import { Inter } from "next/font/google";
import { AppShell } from "@/components/shell/app-shell";
import { SessionProvider } from "@/lib/session";
import "./globals.css";

const inter = Inter({ subsets: ["latin"], display: "swap" });

export const metadata: Metadata = {
  title: "Mynik",
  description: "A tua vida num só sítio: finanças, loja, projetos, notas, carro, documentos e carreira.",
};

export const viewport: Viewport = { themeColor: "#0e0f11", colorScheme: "dark" };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="pt-PT" className={`dark ${inter.className}`}>
      <body>
        <SessionProvider>
          <AppShell>{children}</AppShell>
        </SessionProvider>
      </body>
    </html>
  );
}
