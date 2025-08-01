"use client"
import { useScroll, useTransform } from "framer-motion";
import React from "react";
import { EthSuiHeroEffect } from "../ui/geeffect";
import LightRays from '../ui/LightRays';
import { useRouter } from "next/navigation";

export function EthSuiHeroSection() {
  const ref = React.useRef<HTMLDivElement>(null);
  const { scrollYProgress } = useScroll({
    target: ref,
    offset: ["start start", "end start"],
  });

  const pathLengthFirst = useTransform(scrollYProgress, [0, 0.8], [0.2, 1.2]);
  const pathLengthSecond = useTransform(scrollYProgress, [0, 0.8], [0.15, 1.2]);
  const pathLengthThird = useTransform(scrollYProgress, [0, 0.8], [0.1, 1.2]);
  const pathLengthFourth = useTransform(scrollYProgress, [0, 0.8], [0.05, 1.2]);
  const pathLengthFifth = useTransform(scrollYProgress, [0, 0.8], [0, 1.2]);
  const router = useRouter();
  return (
    <div className="relative">
      {/* Fixed background light rays - positioned absolutely to cover the entire section */}
      <div className="fixed m-20 inset-0 z-0 opacity-70">
        <LightRays
          raysOrigin="top-center"
          raysColor="#ffffff"
          raysSpeed={1.5}
          lightSpread={0.8}
          rayLength={3}
          followMouse={true}
          mouseInfluence={0.1}
          noiseAmount={0.1}
          distortion={0.05}
          className="w-full h-full"
        />
      </div>
      
      {/* Hero content */}
      <div
        className="h-[500vh] bg-black/20 w-full dark:border dark:border-white/[0.1] rounded-md relative pt-40 overflow-clip z-10"
        ref={ref}
      >
        <EthSuiHeroEffect
          pathLengths={[
            pathLengthFirst,
            pathLengthSecond,
            pathLengthThird,
            pathLengthFourth,
            pathLengthFifth,
          ]}
     
          title="Effortless ETH ⇄ SUI Transfers"
          description="Swap assets instantly between Ethereum and Sui. Experience lightning-fast swaps, top-tier security, and a seamless cross-chain journey."
        />
      
      </div>
     
    </div>
  );
}