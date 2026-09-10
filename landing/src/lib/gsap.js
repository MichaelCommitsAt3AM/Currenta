import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';

gsap.registerPlugin(ScrollTrigger);

// One place to tune global defaults.
gsap.defaults({ ease: 'power3.out', duration: 0.9 });
ScrollTrigger.config({ ignoreMobileResize: true });

export { gsap, ScrollTrigger };
