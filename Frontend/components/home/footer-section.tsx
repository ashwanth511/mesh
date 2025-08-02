import { Hexagon, Github, Twitter } from "lucide-react"
import { Footer } from "@/components/ui/footer"

function HomeFooter() {
  return (
    <div className="w-full flex justify-center">
      <div className="w-full max-w-screen-xl px-4">
        <Footer
          logo={<Hexagon className="h-10 w-10 text-primary" />}
          brandName="Mesh"
          socialLinks={[
            {
              icon: <Twitter className="h-5 w-5" />,
              href: "https://x.com/Mesh_official", // Update with your real link
              label: "Twitter",
            },
            {
              icon: <Github className="h-5 w-5" />,
              href: "https://github.com/ashwanth511/mesh", // Update with your real link
              label: "GitHub",
            },
          ]}
          mainLinks={[
            { href: "/swap", label: "Swap" },
            { href: "https://perry.gitbook.io/mesh/", label: "How it works" },
            { href: "/features", label: "Features" },
            { href: "/docs", label: "Docs" },
          ]}
          legalLinks={[]}
          copyright={{
            text: "© 2025 Mesh",
            license: "All rights reserved. Powered by Mesh.",
          }}
        />
      </div>
    </div>
  )
}

export { HomeFooter }