"use client";
import { cn } from "@/lib/utils";
import { motion, MotionValue } from "framer-motion";
import React from "react";

const transition = {
  duration: 0,
  ease: [0.42, 0, 1, 1] as [number, number, number, number],
};

import { useTransform } from "framer-motion";

export const EthToSuiHero = ({
  pathLength,
  className,
}: {
  pathLength: MotionValue<number>;
  className?: string;
}) => {
  // Calculate dot position along the path
  const dotX = useTransform(pathLength, (v: number) => 40 + 720 * v);
  const dotY = useTransform(pathLength, (v: number) => 60 - 60 * Math.sin(Math.PI * v));

  return (
    <div className={cn("relative w-full h-[500px] flex items-center justify-between", className)}>
      {/* ETH Icon */}
      <img src="/eth.svg" alt="ETH" className="w-20 h-20 z-10" />
      {/* Animated Path */}
      <svg
        width="80%"
        height="120"
        viewBox="0 0 800 120"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 w-[80%] h-[120px]"
      >
        <motion.path
          d="M40 60 Q400 0 760 60"
          stroke="#4FABFF"
          strokeWidth="6"
          fill="none"
          initial={{ pathLength: 0 }}
          style={{ pathLength }}
          transition={transition}
        />
        {/* Moving dot representing ETH traveling */}
        <motion.circle
          r="12"
          fill="#4FABFF"
          style={{
            translateX: dotX,
            translateY: dotY,
            opacity: pathLength,
          }}
        />
      </svg>
      {/* SUI Icon */}
      <img src="/sui.svg" alt="SUI" className="w-20 h-20 z-10" />
    </div>
  );
};
