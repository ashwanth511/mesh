'use client';

import Link from 'next/link';
import { Button } from '@/components/ui/button';
import Image from 'next/image';
import { ArrowRight, Book, Github } from 'lucide-react';
export function Navigation() {
  return (
    <nav className="border-b bg-background/95 backdrop-blur supports-[backdrop-filter]:bg-background/60 sticky top-0 z-50">
      <div className="mx-auto max-w-5xl px-6">
        <div className="flex items-center justify-between h-16">
          {/* Logo */}
          <Link href="/" className="flex items-center space-x-2">
            <Image src="/meshlogo.svg" alt="Mesh Logo" width={32} height={32} className="h-8 w-8" />
            <span className="font-bold text-xl">Mesh</span>
          </Link>

          {/* Navigation Links (removed Home and Swap) */}
          <div className="hidden md:flex items-center space-x-8">
            {/* No menu items */}
          
          </div>
        
          {/* CTA Button */}
          <div className="flex items-center space-x-4">
          <Link href="https://meshswap.gitbook.io/mesh/" target="_blank" rel="noopener noreferrer">
                     <Button size="sm" variant="outline">
                        Docs <Book className="w-4 h-4" /> <ArrowRight className="w-4 h-4" />
                     </Button>
                  </Link>
            <Link href="/swap">
              <Button size="sm">
                Start Swapping
              </Button>
            </Link>
            <Link href="https://github.com/ashwanth511/mesh" target="_blank" rel="noopener noreferrer">
              <Button size="sm" variant="outline">
                <Github className="w-4 h-4" />
                Star Our Repo
              </Button>
            </Link>
          </div>
        </div>
      </div>
    </nav>
  );
}
