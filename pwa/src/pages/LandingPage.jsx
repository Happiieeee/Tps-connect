import { useState, useEffect } from 'react';

export default function LandingPage() {
  const [deferredPrompt, setDeferredPrompt] = useState(null);
  const [isInstallable, setIsInstallable] = useState(false);

  // Redirect to working app immediately if opened as an installed PWA
  useEffect(() => {
    const isStandalone = 
      window.matchMedia('(display-mode: standalone)').matches || 
      window.navigator.standalone || 
      document.referrer.includes('android-app://');
      
    if (isStandalone) {
      window.location.href = '/portal';
    }
  }, []);

  // Capture PWA installation trigger
  useEffect(() => {
    const handleBeforeInstallPrompt = (e) => {
      // Prevent Chrome 67 and earlier from automatically showing the prompt
      e.preventDefault();
      // Stash the event so it can be triggered later.
      setDeferredPrompt(e);
      setIsInstallable(true);
    };

    window.addEventListener('beforeinstallprompt', handleBeforeInstallPrompt);

    return () => {
      window.removeEventListener('beforeinstallprompt', handleBeforeInstallPrompt);
    };
  }, []);

  const handleDownloadClick = async () => {
    if (deferredPrompt) {
      // Show the install prompt
      deferredPrompt.prompt();
      // Wait for the user to respond to the prompt
      const { outcome } = await deferredPrompt.userChoice;
      console.log(`User response to the install prompt: ${outcome}`);
      // We've used the prompt, and can't use it again
      setDeferredPrompt(null);
      setIsInstallable(false);
    } else {
      // Fallback: Scroll directly down to the step-by-step installation instructions
      const guideSection = document.getElementById('install-guide');
      if (guideSection) {
        guideSection.scrollIntoView({ behavior: 'smooth' });
      }
    }
  };

  return (
    <div style={{
      minHeight: '100vh',
      background: 'var(--bg)',
      color: 'var(--text-dark)',
      fontFamily: 'var(--font)',
      display: 'flex',
      flexDirection: 'column',
      overflowX: 'hidden'
    }}>
      {/* Sleek Premium Header */}
      <header style={{
        background: 'rgba(255, 255, 255, 0.8)',
        backdropFilter: 'blur(20px)',
        WebkitBackdropFilter: 'blur(20px)',
        borderBottom: '1px solid var(--accent-border)',
        position: 'sticky',
        top: 0,
        zIndex: 1000,
        padding: '16px 24px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'space-between'
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
          <div style={{
            width: '40px',
            height: '40px',
            background: 'var(--primary)',
            borderRadius: 'var(--radius-md)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            boxShadow: '0 4px 12px rgba(59,109,17,0.2)'
          }}>
            <span style={{ color: 'white', fontWeight: 800, fontSize: '14px' }}>TPS</span>
          </div>
          <div>
            <h1 style={{ fontSize: '16px', fontWeight: 700, color: 'var(--text-dark)' }}>TPS Connect</h1>
            <p style={{ fontSize: '10px', color: 'var(--text-light)', margin: 0 }}>Smart Preschool Portal</p>
          </div>
        </div>
        
        <button 
          onClick={handleDownloadClick}
          className="btn btn-primary btn-sm" 
          style={{ width: 'auto', padding: '8px 16px', borderRadius: 'var(--radius-full)' }}
        >
          Download App
        </button>
      </header>

      {/* Minimalism Hero / About App Section */}
      <section style={{
        maxWidth: '800px',
        margin: 'auto auto',
        padding: '60px 24px',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        textAlign: 'center',
        gap: '24px',
        flex: 1,
        justifyContent: 'center'
      }}>
        <div style={{
          background: 'var(--accent-light)',
          color: 'var(--primary)',
          padding: '6px 16px',
          borderRadius: 'var(--radius-full)',
          fontSize: '12px',
          fontWeight: 700,
          border: '1px solid var(--accent-border)',
          display: 'inline-block'
        }}>
          🏫 OFFICIAL TPS PRESCHOOL APP
        </div>

        <h2 style={{
          fontSize: 'clamp(28px, 4vw, 42px)',
          fontWeight: 800,
          lineHeight: 1.2,
          color: 'var(--text-dark)',
          margin: 0
        }}>
          About the TPS Connect App
        </h2>

        <p style={{
          fontSize: 'clamp(14px, 1.8vw, 16px)',
          color: 'var(--text-mid)',
          lineHeight: 1.6,
          margin: 0,
          maxWidth: '600px'
        }}>
          TPS Connect is our secure mobile preschool gateway. Designed for parents, teachers, and administrators, the app makes it easy to track daily attendance, review schedules, broadcast crucial school updates, and manage leave pipelines.
        </p>

        {/* Big Action Download Shortcut Button */}
        <div style={{ marginTop: '12px' }}>
          <button 
            id="pwa-download-shortcut"
            onClick={handleDownloadClick}
            className="btn btn-primary"
            style={{
              padding: '16px 36px',
              fontSize: '17px',
              fontWeight: 700,
              borderRadius: 'var(--radius-md)',
              boxShadow: '0 4px 16px rgba(59,109,17,0.3)',
              width: 'auto'
            }}
          >
            📥 Download / Install App
          </button>
          <span style={{ display: 'block', fontSize: '12px', color: 'var(--text-light)', marginTop: '8px' }}>
            {isInstallable ? 'Click to instantly download and install the app.' : 'Supported on iOS, Android, and desktop.'}
          </span>
        </div>
      </section>

      {/* Premium Download & Setup Instructions (iOS + Android) */}
      <section id="install-guide" style={{
        background: 'var(--surface)',
        borderTop: '1px solid var(--accent-border)',
        padding: '60px 24px'
      }}>
        <div style={{
          maxWidth: '900px',
          margin: '0 auto'
        }}>
          <h3 style={{ fontSize: '24px', fontWeight: 800, textAlign: 'center', marginBottom: '40px' }}>
            Mobile Installation Instructions
          </h3>

          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))',
            gap: '40px'
          }}>
            {/* iOS Safari Guide */}
            <div style={{
              background: 'var(--bg)',
              padding: '24px',
              borderRadius: 'var(--radius-lg)',
              border: '1px solid var(--accent-border)'
            }}>
              <h4 style={{ fontWeight: 800, color: 'var(--text-dark)', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                🍎 Apple iOS (Safari)
              </h4>
              <ol style={{ display: 'flex', flexDirection: 'column', gap: '14px', padding: 0, margin: 0, listStyle: 'none' }}>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>1</span>
                  <span>Open Safari and tap the **Share** button (icon with up arrow at the bottom).</span>
                </li>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>2</span>
                  <span>Scroll down and select **"Add to Home Screen"**.</span>
                </li>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>3</span>
                  <span>Tap **"Add"** in the top right. The app icon will appear on your home screen.</span>
                </li>
              </ol>
            </div>

            {/* Android Chrome Guide */}
            <div style={{
              background: 'var(--bg)',
              padding: '24px',
              borderRadius: 'var(--radius-lg)',
              border: '1px solid var(--accent-border)'
            }}>
              <h4 style={{ fontWeight: 800, color: 'var(--text-dark)', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                🤖 Android (Chrome)
              </h4>
              <ol style={{ display: 'flex', flexDirection: 'column', gap: '14px', padding: 0, margin: 0, listStyle: 'none' }}>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>1</span>
                  <span>Tap the **Download App** button above, or click the 3 dots in the top-right corner.</span>
                </li>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>2</span>
                  <span>Select **"Install App"** (or **"Add to Home Screen"**).</span>
                </li>
                <li style={{ display: 'flex', gap: '12px', alignItems: 'flex-start', fontSize: '14px' }}>
                  <span style={{ background: 'var(--primary)', color: 'white', borderRadius: '50%', width: '24px', height: '24px', display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0, fontSize: '11px', fontWeight: 700 }}>3</span>
                  <span>Confirm by tapping **"Install"**. The app will be saved to your dashboard.</span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer style={{
        background: 'var(--primary-dark)',
        color: 'white',
        padding: '30px 24px',
        textAlign: 'center',
        fontSize: '12px'
      }}>
        <p style={{ margin: 0, opacity: 0.8 }}>
          &copy; {new Date().getFullYear()} TPS Connect. Secure PWA Distribution Hub.
        </p>
      </footer>
    </div>
  );
}
