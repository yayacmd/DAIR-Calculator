'use client';
// Example Next.js page (app router): app/tools/dair/page.jsx
import DAIRCalculator from '@/components/DAIRCalculator';

export default function DairPage() {
  // basePath="" because the model files sit in /public and are served at the root.
  // Pass showArticles={false} for a strictly offline build.
  return (
    <main style={{ maxWidth: 1180, margin: '0 auto', padding: '16px' }}>
      <DAIRCalculator />
    </main>
  );
}
