/* RénoDirect — automatic launch animation; independent of account and routing. */
(() => {
  'use strict';
  const style = document.createElement('style');
  style.id = 'rd-launch-style';
  style.textContent = `
  #rd-launch{position:fixed;inset:0;z-index:2147483647;width:100%;height:100dvh;overflow:hidden;background:#181a17;color:#f4eee2;touch-action:none;overscroll-behavior:none;display:grid;place-items:center;animation:rd-launch-exit 3s ease both}
  #rd-launch .rd-launch-scene{position:relative;width:280px;height:330px;max-width:100%;transform:translateY(-10px)}
  #rd-launch .rd-launch-glow{position:absolute;inset:-60px;background:radial-gradient(ellipse,#d5b57812,transparent 68%);animation:rd-launch-glow 3s ease both;pointer-events:none}
  #rd-launch .rd-launch-ring{position:absolute;left:19px;top:28px;width:240px;height:240px;border:1px solid #d5b57826;border-radius:50%;animation:rd-launch-ring 3s ease both}
  #rd-launch .rd-launch-brand{position:absolute;top:105px;left:0;right:0;text-align:center}
  #rd-launch .rd-launch-roof{position:relative;width:146px;height:54px;margin:0 auto 14px;color:#d5b578}
  #rd-launch .rd-launch-roof span{position:absolute;width:85px;height:4px;top:42px;left:0;border-radius:4px;background:currentColor;transform-origin:left center;animation:rd-launch-roof-left 3s ease both}
  #rd-launch .rd-launch-roof span:nth-child(2){left:73px;top:0;animation-name:rd-launch-roof-right}
  #rd-launch .rd-launch-roof i{position:absolute;right:18px;top:14px;width:4px;height:19px;background:currentColor;animation:rd-launch-chimney 3s ease both}
  #rd-launch .rd-launch-name{font-family:Arial,Helvetica,sans-serif;font-size:37px;font-weight:500;letter-spacing:-1.8px;line-height:1.2;white-space:nowrap;animation:rd-launch-name 3s cubic-bezier(.22,1,.36,1) both}
  #rd-launch .rd-launch-trade{position:absolute;width:48px;height:48px;display:grid;place-items:center;border:1px solid #d5b57860;border-radius:50%;color:#d5b578;background:#20231d;animation:rd-launch-merge 3s cubic-bezier(.22,1,.36,1) both}
  #rd-launch .rd-launch-trade svg{width:23px;height:23px;fill:none;stroke:currentColor;stroke-width:1.5;stroke-linecap:round;stroke-linejoin:round}
  #rd-launch .rd-launch-hammer{left:22px;top:22px;--rd-dx:94px;--rd-dy:87px}
  #rd-launch .rd-launch-water{right:22px;top:22px;--rd-dx:-94px;--rd-dy:87px}
  #rd-launch .rd-launch-paint{left:22px;bottom:45px;--rd-dx:94px;--rd-dy:-128px}
  #rd-launch .rd-launch-power{right:22px;bottom:45px;--rd-dx:-94px;--rd-dy:-128px}
  @keyframes rd-launch-exit{0%,86%{opacity:1}100%{opacity:0}}
  @keyframes rd-launch-glow{0%{opacity:0;transform:scale(.75)}45%,75%{opacity:1;transform:scale(1)}100%{opacity:0;transform:scale(1.1)}}
  @keyframes rd-launch-ring{0%{opacity:0;transform:scale(.85) rotate(-20deg)}20%,40%{opacity:1;transform:scale(1) rotate(0)}72%,100%{opacity:0;transform:scale(.65) rotate(25deg)}}
  @keyframes rd-launch-merge{0%{opacity:0;transform:scale(.65)}18%,33%{opacity:1;transform:scale(1)}65%,100%{opacity:0;transform:translate(var(--rd-dx),var(--rd-dy)) scale(.15)}}
  @keyframes rd-launch-roof-left{0%,30%{transform:rotate(-30deg) scaleX(0)}60%,100%{transform:rotate(-30deg) scaleX(1)}}
  @keyframes rd-launch-roof-right{0%,42%{transform:rotate(30deg) scaleX(0)}67%,100%{transform:rotate(30deg) scaleX(1)}}
  @keyframes rd-launch-chimney{0%,53%{opacity:0}68%,100%{opacity:1}}
  @keyframes rd-launch-name{0%,43%{opacity:0;transform:translateY(9px);filter:blur(4px)}70%,100%{opacity:1;transform:translateY(0);filter:blur(0)}}
  @media(prefers-reduced-motion:reduce){#rd-launch,#rd-launch *{animation:none!important}#rd-launch .rd-launch-trade,#rd-launch .rd-launch-ring{display:none}#rd-launch .rd-launch-roof span{transform:rotate(-30deg)}#rd-launch .rd-launch-roof span:nth-child(2){transform:rotate(30deg)}}
  `;
  document.head.append(style);
  let timer = null, backgroundAt = 0, locked = [], previousFocus = null;
  let theme = null, previousTheme = null;
  function lockContent() {
    if (!document.getElementById('rd-launch')) return;
    document.querySelectorAll('main.app,#rd105').forEach(current => {
      if (locked.some(item => item.element === current)) return;
      locked.push({element:current,inert:current.inert});current.inert=true;
    });
  }
  function finish() {
    clearTimeout(timer);
    document.getElementById('rd-launch')?.remove();
    locked.forEach(item => {item.element.inert=item.inert;});locked=[];
    if (theme && previousTheme !== null) theme.setAttribute('content', previousTheme);
    theme = null;
    document.documentElement.dataset.rdLaunchState = 'done';
    if (previousFocus?.isConnected && previousFocus !== document.body) previousFocus.focus({ preventScroll: true });
    previousFocus = null;
  }
  function show() {
    if (document.getElementById('rd-launch')) return;
    previousFocus = document.activeElement;
    theme = document.querySelector('meta[name="theme-color"]');
    previousTheme = theme?.getAttribute('content') ?? null;
    theme?.setAttribute('content', '#181a17');
    const screen = document.createElement('div');
    screen.id = 'rd-launch';
    screen.setAttribute('role', 'status');
    screen.setAttribute('aria-label', 'RénoDirect');
    screen.innerHTML = `<div class="rd-launch-scene" aria-hidden="true">
      <div class="rd-launch-glow"></div><div class="rd-launch-ring"></div>
      <div class="rd-launch-trade rd-launch-hammer"><svg viewBox="0 0 24 24"><path d="m5 20 9-9M3 18l3 3 10-10-3-3Zm9-13 4-3 5 5-3 4-6-6Z"/></svg></div>
      <div class="rd-launch-trade rd-launch-water"><svg viewBox="0 0 24 24"><path d="M12 2C10 7 5 10 5 15a7 7 0 0 0 14 0c0-5-5-8-7-13ZM8 15a4 4 0 0 0 4 4"/></svg></div>
      <div class="rd-launch-trade rd-launch-paint"><svg viewBox="0 0 24 24"><rect x="3" y="3" width="14" height="6" rx="1.5"/><path d="M17 6h3v7h-9v3M9 16h4v6H9Z"/></svg></div>
      <div class="rd-launch-trade rd-launch-power"><svg viewBox="0 0 24 24"><path d="m14 2-9 12h7l-2 8 9-12h-7Z"/></svg></div>
      <div class="rd-launch-brand"><div class="rd-launch-roof"><span></span><span></span><i></i></div><div class="rd-launch-name">RénoDirect</div></div>
    </div>`;
    document.body.append(screen);
    document.documentElement.dataset.rdLaunchState = 'playing';
    lockContent();
    const reduced = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    timer = setTimeout(finish, reduced ? 700 : 3000);
  }
  document.addEventListener('DOMContentLoaded', lockContent, { once: true });
  document.addEventListener('keydown', event => {
    if (event.key === 'Tab' && document.getElementById('rd-launch')) event.preventDefault();
  }, true);
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) backgroundAt = Date.now();
    else { if (backgroundAt && Date.now() - backgroundAt >= 30000) { finish(); show(); } backgroundAt = 0; }
  });
  window.addEventListener('pageshow', event => { if (event.persisted) { finish(); show(); } });
  show();
})();
