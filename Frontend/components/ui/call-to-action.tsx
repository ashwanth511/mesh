"use client"
import { useRouter } from "next/navigation";
import { MoveRight } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import Link from "next/link";
import { Hexagon, Github, Twitter } from "lucide-react"
function CTA() {
  const router = useRouter();
  return (
    <section className="py-16 md:py-32">
      <div className="mx-auto max-w-5xl px-6">
        <div className="flex flex-col text-center bg-muted rounded-md p-6 lg:p-14 gap-8 items-center">
          <div>
            <Badge>Start swapping</Badge>
          </div>
          <div className="flex flex-col gap-2 max-w-2xl">
            <h3 className="text-3xl md:text-5xl tracking-tighter font-semibold">
              Ready to swap?  
            </h3>
            <p className="text-lg leading-relaxed tracking-tight text-muted-foreground">
              Experience seamless, gasless swaps between Ethereum and Sui. Powered by Mesh for zero fees, top security, and instant swapping. Start your cross-chain journey now!
            </p>
          </div>
          <div className="flex flex-row gap-4">
            <Link href="https://perry.gitbook.io/mesh/" target="_blank" rel="noopener noreferrer">
              <Button size="sm" variant="outline">
              Learn More <MoveRight className="w-4 h-4" /> 
              </Button>
            </Link>
          
         
            <Link href="https://github.com/ashwanth511/mesh" target="_blank" rel="noopener noreferrer">
              <Button size="sm" variant="outline">
                <Github className="w-4 h-4" />
                Star Our Repo <MoveRight className="w-4 h-4" /> 
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </section>
  );
}

export { CTA };
