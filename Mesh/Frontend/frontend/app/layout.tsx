import type { Metadata } from "next";
import { Geist, Geist_Mono } from "next/font/google";
import "./globals.css";
import "./fonts.css";
import '@rainbow-me/rainbowkit/styles.css';
import '@suiet/wallet-kit/style.css';


import { Providers } from "@/lib/providers";
import { Navigation } from "@/components/navigation";
import { Footer } from "@/components/ui/footer";
import { Github, Twitter } from "lucide-react";
import Image from "next/image";

const geistSans = Geist({
  variable: "--font-geist-sans",
  subsets: ["latin"],
});

const geistMono = Geist_Mono({
  variable: "--font-geist-mono",
  subsets: ["latin"],
});

export const metadata: Metadata = {
  title: "ETH-SUI Swap",
  description: "Swap tokens between Ethereum and Sui networks",
  icons: {
    icon: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="en" className="dark">
      <body
        className={`${geistSans.variable} ${geistMono.variable} antialiased`} style={{ fontFamily: "var(--font-space-grotesk), var(--font-geist-sans), sans-serif" }}
      >
        <Providers>
          <Navigation />
          {children}
          <div className="w-full flex justify-center">
            <div className="w-full max-w-screen-xl px-4">
              <Footer
                logo={<Image src="/meshlogo.svg" alt="Mesh Logo" width={40} height={40} className="h-10 w-10" />}
                brandName="ETH ⇄ SUI Swap"
                socialLinks={[
                  {
                    icon: <Twitter className="h-5 w-5" />,
                    href: "https://x.com/Mesh_offical",
                    label: "Twitter",
                  },
                  {
                    icon: <Github className="h-5 w-5" />,
                    href: "https://github.com/ashwanth511/mesh",
                    label: "GitHub",
                  },
                ]}
                mainLinks={[
                  { href: "/swap", label: "Swap" },
                  { href: "/how-it-works", label: "How it works" },
                  { href: "/features", label: "Features" },
                  { href: "/docs", label: "Docs" },
                ]}
                legalLinks={[]}
                copyright={{
                  text: "© 2025 ETH ⇄ SUI Swap",
                  license: "All rights reserved. Powered by 1inch Fusion+.",
                }}
              />
            </div>
          </div>
        </Providers>
      </body>
    </html>
  );
}
