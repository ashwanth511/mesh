import { MoveRight } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";

function CTA() {
  return (
    <section className="py-16 md:py-32">
      <div className="mx-auto max-w-5xl px-6">
        <div className="flex flex-col text-center bg-muted rounded-md p-6 lg:p-14 gap-8 items-center">
          <div>
            <Badge>Start swapping</Badge>
          </div>
          <div className="flex flex-col gap-2 max-w-2xl">
            <h3 className="text-3xl md:text-5xl tracking-tighter font-semibold">
              Ready to swap ETH ⇄ SUI instantly?
            </h3>
            <p className="text-lg leading-relaxed tracking-tight text-muted-foreground">
              Experience seamless, gasless swaps between Ethereum and Sui. Powered by 1inch Fusion+ for zero fees, top security, and instant swapping. Start your cross-chain journey now!
            </p>
          </div>
          <div className="flex flex-row gap-4">
            <Button className="gap-2" asChild variant="outline">
              <a href="/how-it-works">
                Learn More <MoveRight className="w-4 h-4" />
              </a>
            </Button>
            <Button className="gap-2" asChild>
              <a href="/swap">
                Start Swapping <MoveRight className="w-4 h-4" />
              </a>
            </Button>
          </div>
        </div>
      </div>
    </section>
  );
}

export { CTA };
