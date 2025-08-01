import { Hexagon, Github, Twitter } from "lucide-react"
import { Footer } from "@/components/ui/footer"

function HomeFooter() {
  return (
    <div className="w-full flex justify-center">
      <div className="w-full max-w-screen-xl px-4">
        <Footer
          logo={<Hexagon className="h-10 w-10 text-primary" />}
          brandName="ETH ⇄ SUI Swap"
          socialLinks={[
            {
              icon: <Twitter className="h-5 w-5" />,
              href: "https://twitter.com/yourproject", // Update with your real link
              label: "Twitter",
            },
            {
              icon: <Github className="h-5 w-5" />,
              href: "https://github.com/yourproject", // Update with your real link
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
  )
}

export { HomeFooter }