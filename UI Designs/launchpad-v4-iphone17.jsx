import React, { useState, useRef } from 'react';

// ============================================
// LAUNCHPAD HYBRID v4 - iPhone 17 Pro Mockup
// ============================================
// - SMOOTH real-time fader (drag updates live)
// - Redesigned Transport: Wide STOP on top, PLAY/REC below
// - Subtle button colors that GLOW when active
// ============================================

export default function LaunchpadV4Phone() {
  return (
    <div style={{
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f0f23 100%)',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      padding: '20px',
      fontFamily: 'system-ui, sans-serif'
    }}>
      {/* iPhone 17 Pro Frame */}
      <div style={{
        position: 'relative',
        width: '320px',
        height: '693px',
        background: '#1c1c1e',
        borderRadius: '50px',
        padding: '12px',
        boxShadow: `
          0 0 0 1px #2a2a2e,
          0 0 0 4px #0a0a0a,
          0 25px 80px rgba(0,0,0,0.6),
          inset 0 0 1px 1px rgba(255,255,255,0.05)
        `
      }}>
        {/* Dynamic Island */}
        <div style={{
          position: 'absolute',
          top: '18px',
          left: '50%',
          transform: 'translateX(-50%)',
          width: '120px',
          height: '34px',
          background: '#000',
          borderRadius: '20px',
          zIndex: 100
        }} />

        {/* Screen */}
        <div style={{
          width: '100%',
          height: '100%',
          background: '#000',
          borderRadius: '42px',
          overflow: 'hidden',
          position: 'relative'
        }}>
          <LaunchpadHybridV4 />
        </div>

        {/* Side buttons */}
        <div style={{
          position: 'absolute',
          left: '-3px',
          top: '140px',
          width: '3px',
          height: '30px',
          background: '#2a2a2e',
          borderRadius: '2px 0 0 2px'
        }} />
        <div style={{
          position: 'absolute',
          left: '-3px',
          top: '180px',
          width: '3px',
          height: '55px',
          background: '#2a2a2e',
          borderRadius: '2px 0 0 2px'
        }} />
        <div style={{
          position: 'absolute',
          right: '-3px',
          top: '160px',
          width: '3px',
          height: '80px',
          background: '#2a2a2e',
          borderRadius: '0 2px 2px 0'
        }} />
      </div>

      {/* Label */}
      <div style={{
        position: 'absolute',
        bottom: '30px',
        color: '#444',
        fontSize: '12px',
        letterSpacing: '2px',
        fontWeight: 500
      }}>
        iPHONE 17 PRO — 6.3" DISPLAY
      </div>
    </div>
  );
}

function LaunchpadHybridV4() {
  const [mixerValue, setMixerValue] = useState(70);
  const [isArmed, setIsArmed] = useState(false);
  const [isLooping, setIsLooping] = useState(true);
  const [isPlaying, setIsPlaying] = useState(false);
  const [isStopped, setIsStopped] = useState(true);
  const [isRecording, setIsRecording] = useState(false);
  const [activeTab, setActiveTab] = useState('mixer');
  const [isDragging, setIsDragging] = useState(false);
  const faderRef = useRef(null);

  // Handle fader drag - works for both mouse and touch
  const handleFaderInteraction = (clientY) => {
    if (faderRef.current) {
      const rect = faderRef.current.getBoundingClientRect();
      const y = clientY - rect.top;
      const percentage = 100 - Math.round((y / rect.height) * 100);
      setMixerValue(Math.max(0, Math.min(100, percentage)));
    }
  };

  const handleMouseDown = (e) => {
    setIsDragging(true);
    handleFaderInteraction(e.clientY);
  };

  const handleMouseMove = (e) => {
    if (isDragging) {
      handleFaderInteraction(e.clientY);
    }
  };

  const handleMouseUp = () => {
    setIsDragging(false);
  };

  const handleTouchStart = (e) => {
    setIsDragging(true);
    handleFaderInteraction(e.touches[0].clientY);
  };

  const handleTouchMove = (e) => {
    if (isDragging) {
      handleFaderInteraction(e.touches[0].clientY);
    }
  };

  const handleTouchEnd = () => {
    setIsDragging(false);
  };

  // Transport handlers
  const handlePlay = () => {
    setIsPlaying(true);
    setIsStopped(false);
  };

  const handleStop = () => {
    setIsPlaying(false);
    setIsRecording(false);
    setIsStopped(true);
  };

  const handleRecord = () => {
    setIsRecording(!isRecording);
    if (!isRecording) {
      setIsPlaying(true);
      setIsStopped(false);
    }
  };

  return (
    <div 
      style={{
        height: '100%',
        background: '#0c0c0c',
        fontFamily: "'Helvetica Neue', sans-serif",
        color: '#ffffff',
        display: 'flex',
        flexDirection: 'column',
        overflow: 'hidden',
        userSelect: 'none'
      }}
      onMouseMove={handleMouseMove}
      onMouseUp={handleMouseUp}
      onMouseLeave={handleMouseUp}
      onTouchMove={handleTouchMove}
      onTouchEnd={handleTouchEnd}
    >
      {/* Texture overlay */}
      <div style={{
        position: 'absolute',
        top: 0, left: 0, right: 0, bottom: 0,
        backgroundImage: 'radial-gradient(circle at 50% 0%, rgba(60,60,60,0.06) 0%, transparent 40%)',
        pointerEvents: 'none'
      }} />

      {/* Header - Compact */}
      <div style={{
        padding: '52px 14px 8px 14px',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center',
        flexShrink: 0
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <div style={{
            width: '6px', height: '6px',
            borderRadius: '50%',
            background: '#00ff88',
            boxShadow: '0 0 8px #00ff88'
          }} />
          <span style={{
            fontSize: '8px',
            letterSpacing: '2px',
            color: '#555',
            fontWeight: 700
          }}>CONNECTED</span>
        </div>
        <button style={{
          background: 'rgba(255,107,53,0.12)',
          border: '1px solid rgba(255,107,53,0.25)',
          borderRadius: '5px',
          padding: '5px 10px',
          color: '#ff6b35',
          fontSize: '9px',
          fontWeight: 700,
          letterSpacing: '1.5px',
          cursor: 'pointer'
        }}>DEVICES</button>
      </div>

      {/* Tabs - Compact */}
      <div style={{
        margin: '0 10px 6px 10px',
        display: 'flex',
        gap: '2px',
        background: '#131313',
        borderRadius: '6px',
        padding: '2px',
        flexShrink: 0
      }}>
        {['mixer', 'macros'].map((tab) => (
          <button
            key={tab}
            onClick={() => setActiveTab(tab)}
            style={{
              flex: 1,
              padding: '8px',
              background: activeTab === tab ? 'linear-gradient(180deg, #282828, #1e1e1e)' : 'transparent',
              border: 'none',
              borderRadius: '5px',
              color: activeTab === tab ? '#fff' : '#444',
              fontSize: '9px',
              letterSpacing: '2px',
              fontWeight: 700,
              cursor: 'pointer',
              textTransform: 'uppercase'
            }}>{tab}</button>
        ))}
      </div>

      {/* Main Content Area */}
      <div style={{
        margin: '0 10px',
        background: 'linear-gradient(180deg, #161616, #101010)',
        borderRadius: '10px',
        padding: '10px',
        display: 'flex',
        flexDirection: 'column',
        border: '1px solid #222',
        flexShrink: 0,
        height: '200px'
      }}>
        {activeTab === 'mixer' ? (
          <div style={{ display: 'flex', gap: '10px', height: '100%' }}>
            {/* SSL-Style Vertical Fader with SMOOTH DRAG */}
            <div style={{
              width: '58px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              background: '#0a0a0a',
              borderRadius: '6px',
              padding: '8px 6px',
              border: '1px solid #1a1a1a'
            }}>
              {/* Value Display - Updates in real-time */}
              <div style={{
                fontSize: '18px',
                fontWeight: 400,
                fontFamily: 'monospace',
                color: '#00ff88',
                textShadow: '0 0 10px rgba(0,255,136,0.4)',
                marginBottom: '6px'
              }}>{mixerValue}</div>
              
              {/* VU Meter - Vertical */}
              <div style={{
                flex: 1,
                width: '100%',
                display: 'flex',
                gap: '2px',
                marginBottom: '6px'
              }}>
                {/* Left channel */}
                <div style={{
                  flex: 1,
                  display: 'flex',
                  flexDirection: 'column-reverse',
                  gap: '1px'
                }}>
                  {Array.from({ length: 12 }).map((_, i) => {
                    const isActive = (i / 12) * 100 <= mixerValue;
                    const isRed = i >= 10;
                    const isYellow = i >= 8 && i < 10;
                    const color = isRed ? '#ff3b30' : isYellow ? '#ffcc00' : '#00ff88';
                    return (
                      <div key={i} style={{
                        flex: 1,
                        background: isActive ? color : '#1a1a1a',
                        borderRadius: '1px',
                        boxShadow: isActive ? `0 0 4px ${color}40` : 'none'
                      }} />
                    );
                  })}
                </div>
                {/* Right channel */}
                <div style={{
                  flex: 1,
                  display: 'flex',
                  flexDirection: 'column-reverse',
                  gap: '1px'
                }}>
                  {Array.from({ length: 12 }).map((_, i) => {
                    const variance = (i % 3) - 1;
                    const isActive = (i / 12) * 100 <= mixerValue + variance;
                    const isRed = i >= 10;
                    const isYellow = i >= 8 && i < 10;
                    const color = isRed ? '#ff3b30' : isYellow ? '#ffcc00' : '#00ff88';
                    return (
                      <div key={i} style={{
                        flex: 1,
                        background: isActive ? color : '#1a1a1a',
                        borderRadius: '1px'
                      }} />
                    );
                  })}
                </div>
              </div>

              {/* Vertical Slider Track - SMOOTH DRAGGING */}
              <div 
                ref={faderRef}
                style={{
                  flex: 1.2,
                  width: '32px',
                  background: '#050505',
                  borderRadius: '3px',
                  position: 'relative',
                  boxShadow: 'inset 0 2px 4px rgba(0,0,0,0.6)',
                  cursor: 'pointer',
                  touchAction: 'none'
                }}
                onMouseDown={handleMouseDown}
                onTouchStart={handleTouchStart}
              >
                {/* Center line */}
                <div style={{
                  position: 'absolute',
                  left: '50%',
                  top: '3px',
                  bottom: '3px',
                  width: '2px',
                  background: '#222',
                  transform: 'translateX(-50%)',
                  pointerEvents: 'none'
                }} />

                {/* Fader knob */}
                <div style={{
                  position: 'absolute',
                  left: '50%',
                  top: `${100 - mixerValue}%`,
                  transform: 'translate(-50%, -50%)',
                  width: '28px',
                  height: '22px',
                  background: isDragging 
                    ? 'linear-gradient(180deg, #5a5a5a 0%, #3a3a3a 50%, #4a4a4a 100%)'
                    : 'linear-gradient(180deg, #4a4a4a 0%, #2a2a2a 50%, #3a3a3a 100%)',
                  borderRadius: '2px',
                  boxShadow: isDragging
                    ? '0 2px 8px rgba(0,0,0,0.6), 0 0 12px rgba(0,255,136,0.2), inset 0 1px 0 rgba(255,255,255,0.2)'
                    : '0 2px 6px rgba(0,0,0,0.5), inset 0 1px 0 rgba(255,255,255,0.15)',
                  border: '1px solid #555',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  pointerEvents: 'none',
                  transition: 'background 0.1s ease, box-shadow 0.1s ease'
                }}>
                  <div style={{ display: 'flex', flexDirection: 'column', gap: '2px' }}>
                    {[0,1,2].map(i => (
                      <div key={i} style={{
                        width: '16px',
                        height: '1px',
                        background: 'rgba(255,255,255,0.12)'
                      }} />
                    ))}
                  </div>
                </div>
              </div>

              <div style={{
                fontSize: '6px',
                letterSpacing: '1px',
                color: '#444',
                marginTop: '6px',
                fontWeight: 600
              }}>MASTER</div>
            </div>

            {/* Right side - Quick access */}
            <div style={{
              flex: 1,
              display: 'flex',
              flexDirection: 'column',
              gap: '6px',
              overflow: 'hidden'
            }}>
              <div style={{
                fontSize: '7px',
                letterSpacing: '1.5px',
                color: '#444',
                fontWeight: 600
              }}>QUICK ACCESS</div>
              
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(3, 1fr)',
                gridTemplateRows: 'repeat(2, 1fr)',
                gap: '5px',
                flex: 1
              }}>
                {[
                  { icon: '↩', color: '#ff6b35' },
                  { icon: '↪', color: '#ff6b35' },
                  { icon: '⊕', color: '#00d4ff' },
                  { icon: '⚑', color: '#ffcc00' },
                  { icon: '◆', color: '#ff3b30' },
                  { icon: '≡', color: '#9b59b6' }
                ].map((item, i) => (
                  <button key={i} style={{
                    background: 'linear-gradient(145deg, #252525, #1a1a1a)',
                    border: 'none',
                    borderRadius: '5px',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    cursor: 'pointer',
                    boxShadow: '0 2px 6px rgba(0,0,0,0.4), inset 0 1px 0 rgba(255,255,255,0.04)',
                    position: 'relative'
                  }}>
                    <div style={{
                      position: 'absolute',
                      top: '3px',
                      right: '3px',
                      width: '4px',
                      height: '4px',
                      borderRadius: '50%',
                      background: item.color,
                      opacity: 0.5,
                      boxShadow: `0 0 3px ${item.color}40`
                    }} />
                    <span style={{ fontSize: '16px', color: '#666' }}>{item.icon}</span>
                  </button>
                ))}
              </div>
            </div>
          </div>
        ) : (
          /* Full Macros Grid */
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(4, 1fr)',
            gridTemplateRows: 'repeat(3, 1fr)',
            gap: '5px',
            flex: 1
          }}>
            {[
              { icon: '↩', color: '#ff6b35' },
              { icon: '↪', color: '#ff6b35' },
              { icon: '+', color: '#00d4ff' },
              { icon: '⚑', color: '#ffcc00' },
              { icon: '◆', color: '#ff3b30' },
              { icon: '●', color: '#00ff88' },
              { icon: '■', color: '#9b59b6' },
              { icon: '▲', color: '#3498db' },
              { icon: '◀', color: '#e74c3c' },
              { icon: '▶', color: '#2ecc71' },
              { icon: '⬟', color: '#f39c12' },
              { icon: '✦', color: '#1abc9c' }
            ].map((item, i) => (
              <button key={i} style={{
                background: 'linear-gradient(145deg, #252525, #1a1a1a)',
                border: 'none',
                borderRadius: '4px',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                cursor: 'pointer',
                boxShadow: '0 2px 5px rgba(0,0,0,0.4), inset 0 -2px 3px rgba(0,0,0,0.3), inset 0 2px 3px rgba(255,255,255,0.03)',
                position: 'relative'
              }}>
                <div style={{
                  position: 'absolute',
                  top: '3px',
                  right: '3px',
                  width: '4px',
                  height: '4px',
                  borderRadius: '50%',
                  background: item.color,
                  opacity: 0.5
                }} />
                <span style={{ fontSize: '16px', color: '#666' }}>{item.icon}</span>
              </button>
            ))}
          </div>
        )}
      </div>

      {/* ARM / LOOP */}
      <div style={{
        display: 'flex',
        gap: '8px',
        margin: '10px 10px 8px 10px',
        flexShrink: 0
      }}>
        {[
          { label: 'ARM', active: isArmed, color: '#ff3b30', toggle: () => setIsArmed(!isArmed) },
          { label: 'LOOP', active: isLooping, color: '#ff9500', toggle: () => setIsLooping(!isLooping) }
        ].map((btn) => (
          <button
            key={btn.label}
            onClick={btn.toggle}
            style={{
              flex: 1,
              height: '52px',
              background: btn.active 
                ? `linear-gradient(145deg, ${btn.color}, ${btn.color}cc)`
                : 'linear-gradient(145deg, #252525, #1a1a1a)',
              border: 'none',
              borderRadius: '8px',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              cursor: 'pointer',
              boxShadow: btn.active 
                ? `0 0 24px ${btn.color}50, 0 4px 10px rgba(0,0,0,0.4), inset 0 -3px 6px rgba(0,0,0,0.3)`
                : '0 4px 10px rgba(0,0,0,0.4), inset 0 -3px 6px rgba(0,0,0,0.3), inset 0 2px 4px rgba(255,255,255,0.03)',
              position: 'relative',
              transition: 'all 0.1s ease'
            }}>
            <div style={{
              position: 'absolute',
              top: '6px',
              right: '6px',
              width: '6px',
              height: '6px',
              borderRadius: '50%',
              background: btn.active ? '#fff' : btn.color,
              opacity: btn.active ? 1 : 0.4,
              boxShadow: btn.active ? `0 0 8px ${btn.color}` : 'none'
            }} />
            <span style={{ 
              fontSize: '12px', 
              letterSpacing: '3px', 
              fontWeight: 700,
              color: btn.active ? '#fff' : '#555'
            }}>{btn.label}</span>
          </button>
        ))}
      </div>

      {/* TRANSPORT - REDESIGNED: Wide STOP on top, PLAY/RECORD below */}
      <div style={{
        flex: 1,
        margin: '0 10px 12px 10px',
        background: 'linear-gradient(180deg, #141414, #0a0a0a)',
        borderRadius: '14px',
        padding: '10px',
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        border: '1px solid #222',
        minHeight: '150px'
      }}>
        {/* STOP - Wide button on top */}
        <button 
          onClick={handleStop}
          style={{
            width: '100%',
            height: '56px',
            background: isStopped
              ? 'linear-gradient(145deg, #ffcc00, #e6b800)'
              : 'linear-gradient(145deg, #2a2a2a, #1e1e1e)',
            border: isStopped ? 'none' : '1px solid rgba(255, 204, 0, 0.15)',
            borderRadius: '10px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            gap: '10px',
            cursor: 'pointer',
            boxShadow: isStopped 
              ? '0 0 30px rgba(255,204,0,0.4), 0 4px 12px rgba(0,0,0,0.4), inset 0 -3px 8px rgba(0,0,0,0.2), inset 0 2px 4px rgba(255,255,255,0.2)'
              : '0 4px 12px rgba(0,0,0,0.4), inset 0 -3px 8px rgba(0,0,0,0.3), inset 0 2px 4px rgba(255,255,255,0.02)',
            transition: 'all 0.12s ease'
          }}>
          <span style={{ 
            fontSize: '22px', 
            color: isStopped ? '#000' : 'rgba(255,204,0,0.4)'
          }}>■</span>
          <span style={{ 
            fontSize: '14px', 
            fontWeight: 700, 
            letterSpacing: '4px',
            color: isStopped ? '#000' : 'rgba(255,204,0,0.4)'
          }}>STOP</span>
        </button>

        {/* PLAY and RECORD - Side by side below */}
        <div style={{
          display: 'flex',
          gap: '8px',
          flex: 1
        }}>
          {/* PLAY */}
          <button 
            onClick={handlePlay}
            style={{
              flex: 1,
              background: isPlaying
                ? 'linear-gradient(145deg, #00ff88, #00dd77)'
                : 'linear-gradient(145deg, #2a2a2a, #1e1e1e)',
              border: isPlaying ? 'none' : '1px solid rgba(0, 255, 136, 0.15)',
              borderRadius: '10px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              cursor: 'pointer',
              boxShadow: isPlaying 
                ? '0 0 35px rgba(0,255,136,0.5), 0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.2), inset 0 2px 4px rgba(255,255,255,0.2)'
                : '0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.3), inset 0 2px 4px rgba(255,255,255,0.02)',
              transition: 'all 0.12s ease'
            }}>
            <span style={{ 
              fontSize: '36px', 
              color: isPlaying ? '#000' : 'rgba(0,255,136,0.35)',
              marginLeft: '4px'
            }}>▶</span>
            <span style={{ 
              fontSize: '11px', 
              fontWeight: 700, 
              letterSpacing: '3px',
              color: isPlaying ? '#000' : 'rgba(0,255,136,0.35)'
            }}>PLAY</span>
          </button>

          {/* RECORD */}
          <button 
            onClick={handleRecord}
            style={{
              flex: 1,
              background: isRecording
                ? 'linear-gradient(145deg, #ff3b30, #dd3328)'
                : 'linear-gradient(145deg, #2a2a2a, #1e1e1e)',
              border: isRecording ? 'none' : '1px solid rgba(255, 59, 48, 0.15)',
              borderRadius: '10px',
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
              justifyContent: 'center',
              gap: '6px',
              cursor: 'pointer',
              boxShadow: isRecording 
                ? '0 0 35px rgba(255,59,48,0.5), 0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.2), inset 0 2px 4px rgba(255,255,255,0.2)'
                : '0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.3), inset 0 2px 4px rgba(255,255,255,0.02)',
              transition: 'all 0.12s ease',
              animation: isRecording ? 'pulse 1.5s ease-in-out infinite' : 'none'
            }}>
            <span style={{ 
              fontSize: '32px', 
              color: isRecording ? '#fff' : 'rgba(255,59,48,0.35)'
            }}>●</span>
            <span style={{ 
              fontSize: '11px', 
              fontWeight: 700, 
              letterSpacing: '3px',
              color: isRecording ? '#fff' : 'rgba(255,59,48,0.35)'
            }}>REC</span>
          </button>
        </div>
      </div>

      {/* Home indicator */}
      <div style={{
        height: '18px',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        flexShrink: 0
      }}>
        <div style={{
          width: '100px',
          height: '4px',
          background: '#333',
          borderRadius: '2px'
        }} />
      </div>

      {/* Pulse animation for recording */}
      <style>{`
        @keyframes pulse {
          0%, 100% { box-shadow: 0 0 35px rgba(255,59,48,0.5), 0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.2), inset 0 2px 4px rgba(255,255,255,0.2); }
          50% { box-shadow: 0 0 50px rgba(255,59,48,0.7), 0 6px 16px rgba(0,0,0,0.4), inset 0 -4px 10px rgba(0,0,0,0.2), inset 0 2px 4px rgba(255,255,255,0.2); }
        }
      `}</style>
    </div>
  );
}
