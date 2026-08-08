(() => {
  const measurementId = 'G-L973RM6X8J';
  const storageKey = 'ts_analytics_consent_v1';
  const css = `
    .ts-consent{position:fixed;z-index:9999;left:20px;right:20px;bottom:20px;max-width:760px;margin:auto;padding:20px;border-radius:20px;background:rgba(18,20,27,.97);color:#fff;border:1px solid rgba(255,255,255,.15);box-shadow:0 22px 70px rgba(0,0,0,.34);font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}
    .ts-consent[hidden],.ts-privacy-choices[hidden]{display:none}
    .ts-consent strong{display:block;font-size:17px;margin-bottom:5px}.ts-consent p{margin:0;color:#c7cbd4}.ts-consent a{color:#9ec0ff;text-decoration:underline}
    .ts-consent-actions{display:flex;gap:9px;flex-wrap:wrap;margin-top:16px}.ts-consent button,.ts-privacy-choices{border:0;border-radius:12px;padding:11px 15px;font-weight:750;cursor:pointer}
    .ts-accept{background:#2d5bff;color:#fff}.ts-decline{background:#30343d;color:#fff}.ts-privacy-choices{position:fixed;z-index:9998;left:14px;bottom:14px;background:#20242d;color:#fff;box-shadow:0 8px 30px rgba(0,0,0,.22);font-size:12px}
    @media(max-width:560px){.ts-consent{left:10px;right:10px;bottom:10px;padding:17px}.ts-consent-actions button{flex:1}}
  `;
  const style = document.createElement('style');
  style.textContent = css;
  document.head.appendChild(style);

  const banner = document.createElement('section');
  banner.className = 'ts-consent';
  banner.setAttribute('role', 'dialog');
  banner.setAttribute('aria-label', 'Analytics preferences');
  banner.innerHTML = `<strong>Help us improve this website?</strong><p>With your permission, we use Google Analytics to understand visits and improve the site. Analytics stays off unless you accept. See our <a href="/privacy/">Privacy Policy</a>.</p><div class="ts-consent-actions"><button class="ts-accept" type="button">Accept analytics</button><button class="ts-decline" type="button">Decline</button></div>`;

  const choices = document.createElement('button');
  choices.type = 'button';
  choices.className = 'ts-privacy-choices';
  choices.textContent = 'Privacy choices';
  choices.hidden = true;

  const readChoice = () => {
    try { return localStorage.getItem(storageKey); } catch (_) { return null; }
  };
  const saveChoice = value => {
    try { localStorage.setItem(storageKey, value); } catch (_) {}
  };
  const loadAnalytics = () => {
    if (window.__tsAnalyticsLoaded) {
      window.gtag('consent', 'update', { analytics_storage: 'granted' });
      return;
    }
    window.__tsAnalyticsLoaded = true;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function(){ window.dataLayer.push(arguments); };
    window.gtag('consent', 'default', {
      analytics_storage: 'granted',
      ad_storage: 'denied',
      ad_user_data: 'denied',
      ad_personalization: 'denied'
    });
    window.gtag('js', new Date());
    window.gtag('config', measurementId, { allow_google_signals: false });
    const script = document.createElement('script');
    script.async = true;
    script.src = 'https://www.googletagmanager.com/gtag/js?id=' + encodeURIComponent(measurementId);
    document.head.appendChild(script);
  };
  const disableAnalytics = () => {
    if (window.gtag) window.gtag('consent', 'update', { analytics_storage: 'denied' });
    document.cookie.split(';').forEach(cookie => {
      const name = cookie.split('=')[0].trim();
      if (name === '_ga' || name.startsWith('_ga_')) {
        document.cookie = name + '=; Max-Age=0; path=/; SameSite=Lax';
      }
    });
  };
  const applyChoice = value => {
    banner.hidden = true;
    choices.hidden = false;
    if (value === 'accepted') loadAnalytics();
    if (value === 'declined') disableAnalytics();
  };
  banner.querySelector('.ts-accept').addEventListener('click', () => {
    saveChoice('accepted');
    applyChoice('accepted');
  });
  banner.querySelector('.ts-decline').addEventListener('click', () => {
    saveChoice('declined');
    applyChoice('declined');
  });
  choices.addEventListener('click', () => {
    choices.hidden = true;
    banner.hidden = false;
    banner.querySelector('.ts-decline').focus();
  });
  document.body.append(banner, choices);

  const saved = readChoice();
  if (saved) applyChoice(saved);
})();
