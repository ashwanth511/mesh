
import { EthSuiHeroSection } from '../components/home/geeffect-hero';
import { Features } from '../components/home/features-section';
import { Features1 } from '../components/home/howitworks-section';
import { CTADemo } from '../components/home/cta-section';

export default function HomePage() {
  return (
    <div className="min-h-screen bg-background">
      <EthSuiHeroSection />
      <Features />
      <Features1 />
      <CTADemo />
    </div>
  );
}
