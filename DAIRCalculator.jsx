'use client';
// DAIRCalculator.jsx — DAIR Success Calculator as a self-contained React component.
// Next.js static export + Capacitor friendly: client-only, theme-inheriting.
//
// THEME: inherits the host app's design tokens (shadcn/Tailwind style) with a
// fallback to the original ICM palette, so it stays consistent (incl. dark mode)
// inside the app and still looks right standalone. DOM styling uses
// var(--token, fallback); SVG colors are resolved to concrete values at runtime
// (WKWebView won't resolve var() inside SVG attributes) and re-read on theme change.
//
//   import DAIRCalculator from '@/components/DAIRCalculator';
//   <DAIRCalculator basePath="" />        // model files live in /public

import { useState, useEffect, useMemo, useCallback, useRef } from 'react';
import {
  initialState, missingRequired, activeKey, computeResult,
  loadModel, getCachedModel, LABELS, ORGANISMS, COLORS,
} from './dairModel';

// ICM fallbacks used until the theme probe reads the app tokens (and if absent)
const DEFAULT_COLORS = { ink: COLORS.ink, success: COLORS.green, warn: COLORS.amber, danger: COLORS.red, line: COLORS.line };

/* ---------------- gauge geometry (concrete colors, not CSS vars) ---------------- */
function polar(cx, cy, r, deg){ const a = (deg - 180) * Math.PI / 180; return [cx + r*Math.cos(a), cy + r*Math.sin(a)]; }
function arcPath(cx, cy, r, a0, a1){
  const [x0,y0] = polar(cx,cy,r,a0), [x1,y1] = polar(cx,cy,r,a1);
  const large = (a1 - a0) > 180 ? 1 : 0;
  return `M ${x0} ${y0} A ${r} ${r} 0 ${large} 1 ${x1} ${y1}`;
}
function Gauge({ pct, colors }){
  const cx=120, cy=130, r=96, sw=20;
  const p = Math.max(0, Math.min(100, pct));
  const zones = [[0,33,colors.danger],[33,67,colors.warn],[67,100,colors.success]];
  const [nx,ny] = polar(cx, cy, r-2, p/100*180);
  return (
    <svg viewBox="0 0 240 150" width="240" height="150" className="dc-gauge" aria-label={`success ${Math.round(p)} percent`}>
      <path d={arcPath(cx,cy,r,0,180)} stroke={colors.line} strokeWidth={sw} fill="none" strokeLinecap="round"/>
      {zones.map(([z0,z1,c],i)=>(
        <path key={i} d={arcPath(cx,cy,r,z0/100*180,z1/100*180)} stroke={c} strokeWidth={sw} fill="none"/>
      ))}
      <line x1={cx} y1={cy} x2={nx} y2={ny} stroke={colors.ink} strokeWidth={3}/>
      <circle cx={cx} cy={cy} r={6} fill={colors.ink}/>
      <text className="dc-gnum" x={cx} y={cy-18} fill={colors.ink}>{Math.round(p)}%</text>
    </svg>
  );
}

/* normalize any CSS color (incl. lab()/color()) to an SVG-safe hex/rgb string */
let _normCtx = null;
function normColor(c, fallback){
  try {
    _normCtx = _normCtx || document.createElement('canvas').getContext('2d');
    _normCtx.fillStyle = '#000';
    _normCtx.fillStyle = c;           // canvas serializes to #rrggbb / rgba(...)
    return _normCtx.fillStyle;
  } catch { return fallback; }
}
/* resolve the mapped --dc-* tokens to concrete colors via a probe element */
function readThemeColors(probe){
  probe.style.color            = 'var(--dc-ink)';
  probe.style.backgroundColor  = 'var(--dc-success)';
  probe.style.borderTopColor   = 'var(--dc-warn)';
  probe.style.borderRightColor = 'var(--dc-danger)';
  probe.style.borderBottomColor= 'var(--dc-line)';
  const cs = getComputedStyle(probe);
  return {
    ink:     normColor(cs.color,             DEFAULT_COLORS.ink),
    success: normColor(cs.backgroundColor,   DEFAULT_COLORS.success),
    warn:    normColor(cs.borderTopColor,    DEFAULT_COLORS.warn),
    danger:  normColor(cs.borderRightColor,  DEFAULT_COLORS.danger),
    line:    normColor(cs.borderBottomColor, DEFAULT_COLORS.line),
  };
}

/* ------------------------------ main component ------------------------------ */
export default function DAIRCalculator({
  basePath = '',
  showArticles = true,
  showHeader = true,
  pdfHref,
  themeKey,
}){
  const [state, setState] = useState(initialState);
  const [loaded, setLoaded] = useState({});
  const [err, setErr] = useState('');
  const [articles, setArticles] = useState(null);
  const [colors, setColors] = useState(DEFAULT_COLORS);

  const probeRef = useRef(null);
  const pdf = pdfHref ?? `${basePath}/Hip-and-Knee_ICM.pdf`;

  /* resolve theme colors for the SVG + track dark-mode / theme changes */
  useEffect(() => {
    const probe = probeRef.current;
    if (!probe || typeof window === 'undefined') return;
    const update = () => { try { setColors(readThemeColors(probe)); } catch {} };
    update();
    const mo = new MutationObserver(update);
    mo.observe(document.documentElement, { attributes: true, attributeFilter: ['class', 'style', 'data-theme'] });
    if (document.body) mo.observe(document.body, { attributes: true, attributeFilter: ['class', 'style', 'data-theme'] });
    const mq = window.matchMedia('(prefers-color-scheme: dark)');
    mq.addEventListener?.('change', update);
    return () => { mo.disconnect(); mq.removeEventListener?.('change', update); };
  }, [themeKey]);

  /* preload no-culture model; load culture model on demand */
  useEffect(() => {
    let alive = true;
    loadModel('model_nculture', basePath)
      .then(() => alive && setLoaded(l => ({ ...l, model_nculture: true })))
      .catch(e => alive && setErr(String(e.message || e)));
    return () => { alive = false; };
  }, [basePath]);

  useEffect(() => {
    if (state.Culture === '1' && !loaded.model_culture){
      let alive = true;
      loadModel('model_culture', basePath)
        .then(() => alive && setLoaded(l => ({ ...l, model_culture: true })))
        .catch(e => alive && setErr(String(e.message || e)));
      return () => { alive = false; };
    }
  }, [state.Culture, loaded.model_culture, basePath]);

  /* gating + result */
  const missing = useMemo(() => missingRequired(state), [state]);
  const key = activeKey(state);
  const ready = !!loaded[key];
  const result = useMemo(() => {
    if (missing.length || !ready) return null;
    return computeResult(state, getCachedModel(key));
  }, [state, missing.length, ready, key]);

  /* handlers */
  const setField = useCallback((name, val) => setState(s => ({ ...s, [name]: val })), []);
  const toggle   = useCallback((name) => setState(s => ({ ...s, [name]: s[name] === '1' ? '0' : '1' })), []);
  const onNum = useCallback((id, val) => {
    if (id === 'Dayssymptoms'){ const n = parseFloat(val); if (n > 90) val = '90'; }
    setState(s => ({ ...s, [id]: val }));
  }, []);
  const onCultureNeg = useCallback(() => setState(s => {
    const on = s.CultureNeg !== '1';
    const ns = { ...s, CultureNeg: on ? '1' : '0' };
    if (on) ORGANISMS.forEach(o => { if (o !== 'gramnegative') ns[o] = '0'; });
    return ns;
  }), []);

  /* recent PubMed articles (optional, graceful) */
  useEffect(() => {
    if (!showArticles) return;
    let alive = true;
    const term = 'debridement+antibiotic+implant+retention';
    (async () => {
      try {
        const es = await fetch(`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi?db=pubmed&term=${term}&sort=date&retmax=5&retmode=json`).then(r=>r.json());
        const ids = es?.esearchresult?.idlist || [];
        if (!ids.length) throw new Error('none');
        const sum = await fetch(`https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi?db=pubmed&id=${ids.join(',')}&retmode=json`).then(r=>r.json());
        if (!alive) return;
        setArticles(ids.map(id => {
          const a = sum.result?.[id]; if (!a) return null;
          const auth = a.authors?.[0] ? a.authors[0].name + ' et al.' : '';
          return { id, title: a.title || '(untitled)', meta: [auth, a.fulljournalname || a.source, a.pubdate].filter(Boolean).join(' · ') };
        }).filter(Boolean));
      } catch { if (alive) setArticles([]); }
    })();
    return () => { alive = false; };
  }, [showArticles]);

  /* derived UI hints */
  const daysDairZero = state.days_to_DAIR !== '' && parseFloat(state.days_to_DAIR) === 0;
  const symptomsZero = state.Dayssymptoms !== '' && parseFloat(state.Dayssymptoms) === 0;
  const symptoms90   = state.Dayssymptoms !== '' && parseFloat(state.Dayssymptoms) >= 90;
  const cultureNegOn = state.CultureNeg === '1';

  /* render helpers (functions returning JSX -> keep input focus) */
  const seg = (name, options) => (
    <div className="dc-seg">
      {options.map(([label, val]) => (
        <button key={val} type="button" aria-pressed={state[name] === val}
          onClick={() => setField(name, val)}>{label}</button>
      ))}
    </div>
  );
  const tog = (name, label, disabled = false) => (
    <button type="button" className="dc-tog" aria-pressed={state[name] === '1'}
      disabled={disabled} onClick={() => toggle(name)}>{label}</button>
  );
  const num = (id, label, min, max, step) => (
    <div>
      <label className="dc-fld" htmlFor={`dc-${id}`}>{label}</label>
      <input id={`dc-${id}`} type="number" inputMode="decimal" min={min} max={max} step={step}
        placeholder="Required" value={state[id]} onChange={e => onNum(id, e.target.value)} />
    </div>
  );

  const phMsg = missing.length ? 'Enter patient details to calculate'
              : (!ready ? 'Loading model…' : '');

  return (
    <div className="dair-calc">
      <style dangerouslySetInnerHTML={{ __html: CSS }} />
      <span ref={probeRef} aria-hidden="true" style={{ position:'absolute', width:0, height:0, opacity:0, pointerEvents:'none' }} />

      {showHeader && (
        <header className="dc-appbar">
          <div className="dc-titles">
            <span className="dc-name">DAIR Success Calculator</span>
            <span className="dc-tag">Probability of success after debridement &amp; implant retention</span>
          </div>
        </header>
      )}

      <div className="dc-disclaimer">
        Educational decision support, not a substitute for clinical judgment. Reproduces the published
        model (Shohat et&nbsp;al., <i>Bone Joint J</i> 2020); verify against institutional guidance before use in care.
      </div>

      {err && <div className="dc-error">Couldn’t load the model files ({err}). Confirm the <code>.bin</code> files and <code>models.json</code> are served from <code>{basePath || '/'}</code>.</div>}

      <div className="dc-wrap">
        {/* ---------------- inputs ---------------- */}
        <div className="dc-panels">
          <details className="dc-acc" open>
            <summary>Patient Demographics <span className="dc-chev">▶</span></summary>
            <div className="dc-body">
              <div className="dc-grid2">
                {num('Age', 'Patient Age (years)', 0, 100, 1)}
                <div>
                  <label className="dc-fld">Patient Gender</label>
                  {seg('Male', [['Male','1'],['Female','0']])}
                </div>
                {num('BMI', 'Body Mass Index (kg/m²)', 10, 100, 0.1)}
                <div>
                  <div className="dc-sectiontitle">Social Factors</div>
                  <div className="dc-toggles">
                    {tog('Smoking', 'Current Smoker')}
                    {tog('Alcohol', 'Current Alcohol Use')}
                  </div>
                </div>
              </div>
            </div>
          </details>

          <details className="dc-acc">
            <summary>Patient Comorbidities <span className="dc-chev">▶</span></summary>
            <div className="dc-body">
              <div className="dc-toggles dc-two">
                {tog('COPD','Chronic Obstructive Pulmonary Disease')}
                {tog('LC','Liver Cirrhosis')}
                {tog('Immunesuppresion','Immunocompromised')}
                {tog('malignancy','Cancer')}
                {tog('Pacemaker_ICD','Pacemaker or ICD Implanted')}
                {tog('Hypertension','Hypertension')}
                {tog('oral_anticoagulant','Taking Oral Anticoagulant')}
                {tog('IHD','Hemodialysis')}
                {tog('RA','Rheumatoid Arthritis')}
                {tog('Dementia','Dementia')}
                {tog('HF','Congestive Heart Failure')}
                {tog('DM','Diabetes Mellitus')}
                {tog('CRF','Chronic Kidney Disease')}
              </div>
            </div>
          </details>

          <details className="dc-acc">
            <summary>Procedure <span className="dc-chev">▶</span></summary>
            <div className="dc-body">
              <div className="dc-grid3">
                <div>
                  <label className="dc-fld">Indication for Arthroplasty</label>
                  {seg('Indication_prosthesis', [['Osteoarthritis','1'],['Other','2']])}
                </div>
                <div>
                  <label className="dc-fld">Joint</label>
                  {seg('Joint', [['Hip','1'],['Knee','2']])}
                </div>
                <div>
                  <label className="dc-fld">Index Procedure</label>
                  {seg('index_revision', [['Primary','0'],['Revision','1']])}
                </div>
                <div>
                  <label className="dc-fld">Cemented Components</label>
                  {seg('Cement', [['Yes','1'],['No','0']])}
                </div>
                <div>
                  <label className="dc-fld">Late Infection</label>
                  {seg('late_infection', [['Yes','1'],['No','0']])}
                </div>
                <div />
                <div>
                  {num('days_to_DAIR', 'Days from Index Procedure to DAIR', 0, 200, 1)}
                  {daysDairZero && <div className="dc-warn dc-confirm">0 days entered — confirm same-day DAIR is intended.</div>}
                </div>
                <div>
                  {num('Dayssymptoms', 'Days of Symptoms', 0, 90, 1)}
                  {symptoms90 && <div className="dc-warn">DAIR is not recommended beyond 90 days from onset of symptoms</div>}
                  {symptomsZero && <div className="dc-warn dc-confirm">0 days entered — confirm intended.</div>}
                </div>
              </div>
            </div>
          </details>

          <details className="dc-acc">
            <summary>Complications <span className="dc-chev">▶</span></summary>
            <div className="dc-body">
              <div className="dc-toggles dc-three">
                {tog('Wound_leakage','Wound Leakage')}
                {tog('Fistula','Fistula Present')}
                {tog('Skin_infection','Overlying Skin Infection')}
                {tog('Necrosis','Necrosis')}
                {tog('Fever38','Fever')}
              </div>
            </div>
          </details>

          <details className="dc-acc">
            <summary>Laboratory &amp; Culture Results <span className="dc-chev">▶</span></summary>
            <div className="dc-body">
              <div className="dc-grid3">
                {num('Last_CRP', 'Last C-Reactive Protein (mg/L)', 0, 100, 0.1)}
                {num('Last_leucocytes', 'Last Leucocyte Count (1,000/mL)', 0, 100, 0.1)}
                <div>
                  <label className="dc-fld">Positive Blood Cultures</label>
                  <div className="dc-toggles dc-one">{tog('Positive_bloodcultures','Positive Blood Cultures')}</div>
                </div>
              </div>

              <div className="dc-culture-q">
                <b>Were Cultures Obtained?</b>
                {seg('Culture', [['Yes','1'],['No','0']])}
              </div>

              {state.Culture === '1' && (
                <div className="dc-organisms">
                  <h4>Organism (select all that apply)</h4>
                  <div className="dc-toggles dc-one">
                    <button type="button" className="dc-tog" aria-pressed={cultureNegOn} onClick={onCultureNeg}>Culture Negative</button>
                  </div>
                  <div className="dc-toggles dc-three" style={{ marginTop: 8 }}>
                    {tog('STAU','Methicillin-sensitive S. aureus', cultureNegOn)}
                    {tog('gramnegative','Gram-negative')}
                    {tog('Polymicrob','Polymicrobial', cultureNegOn)}
                    {tog('MRSA','Methicillin-resistant S. aureus', cultureNegOn)}
                    {tog('Enterococcus_spp','Enterococcus', cultureNegOn)}
                    {tog('Proteus_spp','Proteus', cultureNegOn)}
                    {tog('Staphepi','Staphylococcus epidermidis', cultureNegOn)}
                    {tog('Enterobacter_spp','Enterobacter', cultureNegOn)}
                    {tog('Escherichia_coli','E. coli', cultureNegOn)}
                    {tog('Pseudomonas_aerugi0sa','Pseudomonas aeruginosa', cultureNegOn)}
                    {tog('Streptococci_spp','Streptococcus', cultureNegOn)}
                    {tog('Candida_spp','Candida', cultureNegOn)}
                  </div>
                </div>
              )}
            </div>
          </details>

          <details className="dc-acc dc-info">
            <summary>Information &amp; Links <span className="dc-chev">▶</span></summary>
            <div className="dc-body dc-info">
              <p>Based on the validated model in: Shohat N, Goswami K, Tan&nbsp;TL, Yayac&nbsp;M, Soriano&nbsp;A,
                 Sousa&nbsp;R, Wouthuyzen-Bakker&nbsp;M, Parvizi&nbsp;J.{' '}
                 <a href="https://doi.org/10.1302/0301-620X.102B7.BJJ-2019-1628.R1" target="_blank" rel="noopener">
                 <i>Who Will Fail Following Irrigation and Debridement for Periprosthetic Joint Infection?</i></a>{' '}
                 Bone Joint J. 2020 (Hip Society Proceedings), on behalf of ESGIAI &amp; NINJA.</p>
              <p><a href={pdf} target="_blank" rel="noopener">2nd International Consensus Meeting — Hip &amp; Knee Section on DAIR (PDF)</a></p>
              {showArticles && (
                <div className="dc-articles">
                  <p style={{ margin: '10px 0 2px' }}><b>Recently Published Articles on DAIR</b></p>
                  {articles === null && <div className="dc-loading">Loading recent PubMed articles…</div>}
                  {articles !== null && articles.length === 0 && (
                    <div className="dc-loading">Couldn’t reach PubMed — <a href="https://pubmed.ncbi.nlm.nih.gov/?term=debridement+antibiotic+implant+retention&sort=date" target="_blank" rel="noopener">browse recent articles</a>.</div>
                  )}
                  {articles?.map(a => (
                    <div className="dc-art" key={a.id}>
                      <a href={`https://pubmed.ncbi.nlm.nih.gov/${a.id}`} target="_blank" rel="noopener">{a.title}</a>
                      <div className="dc-meta">{a.meta}</div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </details>
        </div>

        {/* ---------------- results ---------------- */}
        <aside className={`dc-results${result ? '' : ' dc-incomplete'}`}>
          <h2>Probability of Treatment Success</h2>

          {!result && (
            <div className="dc-ph">
              <div className="dc-ph-icon">
                <svg width="34" height="34" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinecap="round" strokeLinejoin="round">
                  <rect x="5" y="3" width="14" height="18" rx="2"/><path d="M9 8h6M9 12h6M9 16h4"/>
                </svg>
              </div>
              <p className="dc-ph-msg">{phMsg}</p>
              {!!missing.length && <p className="dc-ph-missing">Still needed: {missing.join(' · ')}</p>}
            </div>
          )}

          {result && (
            <>
              <div className="dc-gaugewrap"><Gauge pct={result.pct} colors={colors} /></div>

              <div className="dc-me-toggle">
                <div className="dc-me-row">
                  <span>Modular Component Exchange</span>
                  <label className="dc-switch">
                    <input type="checkbox" checked={state.Mobilexchange === '1'}
                      onChange={e => setField('Mobilexchange', e.target.checked ? '1' : '0')} />
                    <span className="dc-slider"><span className="dc-yn dc-y">Yes</span><span className="dc-yn dc-n">No</span></span>
                  </label>
                </div>
              </div>

              <div className="dc-chartbox">
                <h3>Why this estimate? <span className="dc-shap-tag">SHAP</span></h3>
                <div className="dc-refstrip">
                  <span>Reference<br/><b>{Math.round(result.fb)}%</b></span>
                  <span className="dc-arrow" />
                  <span style={{ textAlign: 'right' }}>This patient<br/><b>{Math.round(result.pct)}%</b></span>
                </div>
                {result.effects.map(({ name, value }) => {
                  const max = Math.max(...result.effects.map(e => Math.abs(e.value)));
                  const half = Math.min(50, Math.abs(value) / max * 50);
                  const pos = value >= 0;
                  const col = pos ? colors.success : colors.danger;
                  const style = pos ? { left: '50%', width: `${half}%` } : { left: `${50 - half}%`, width: `${half}%` };
                  return (
                    <div className="dc-sh-row" key={name}>
                      <div className="dc-sh-lab">{LABELS[name] || name}</div>
                      <div className="dc-sh-track"><div className="dc-sh-axis" /><div className="dc-sh-fill" style={{ ...style, background: col }} /></div>
                      <div className="dc-sh-val" style={{ color: col, textAlign: pos ? 'left' : 'right' }}>{pos ? '+' : '−'}{Math.abs(value).toFixed(1)}</div>
                    </div>
                  );
                })}
                <div className="dc-shap-legend">
                  <span><i style={{ background: colors.success }} />raises success</span>
                  <span><i style={{ background: colors.danger }} />lowers success</span>
                </div>
                <p className="dc-note">Exact Shapley contributions of each factor, relative to a low-risk
                  reference patient. Bars sum to the gap between the reference and this patient.</p>
              </div>
            </>
          )}
        </aside>
      </div>
    </div>
  );
}

/* ------------------------------ scoped styles ------------------------------ */
/* Maps host-app tokens (shadcn/Tailwind) -> component vars, with ICM fallbacks. */
const CSS = `
.dair-calc{
  --dc-bg:var(--background,#FAFBFC);
  --dc-card:var(--card,#FFFFFF);
  --dc-ink:var(--foreground,#16202B);
  --dc-muted:var(--muted-foreground,#5B6B7C);
  --dc-line:var(--border,#E3E8EE);
  --dc-primary:var(--primary,#1B4FA0);
  --dc-primary-fg:var(--primary-foreground,#FFFFFF);
  --dc-wash:var(--muted,#EEF3FB);
  --dc-success:var(--chart-2,#1A7F4B);
  --dc-warn:var(--chart-4,#B7791F);
  --dc-danger:var(--destructive,#B3261E);
  --dc-ring:var(--ring,#1B4FA0);
  --dc-radius:var(--radius,.625rem);
  --dc-radius-sm:calc(var(--radius,.625rem) * .62);
  --dc-sans:var(--font-sans,'IBM Plex Sans',system-ui,-apple-system,sans-serif);
  --dc-serif:var(--font-serif,'Source Serif 4',Georgia,serif);
  --dc-mono:var(--font-mono,var(--font-geist-mono,'IBM Plex Mono',ui-monospace,monospace));
  --dc-shadow:0 1px 2px rgba(0,0,0,.05);
  font-family:var(--dc-sans);color:var(--dc-ink);line-height:1.55;-webkit-text-size-adjust:100%;
}
.dair-calc *{box-sizing:border-box;}
.dc-appbar{display:flex;align-items:center;justify-content:space-between;gap:1rem;padding:.4rem 0 .3rem;}
.dc-titles{display:flex;flex-direction:column;line-height:1.2;}
.dc-name{font-weight:600;font-size:1.05rem;letter-spacing:-.01em;color:var(--dc-ink);}
.dc-tag{font-size:.74rem;color:var(--dc-muted);}
.dc-disclaimer{margin:.5rem 0 1rem;padding:.6rem .85rem;font-size:.78rem;color:var(--dc-ink);background:var(--dc-card);
  border:1px solid var(--dc-line);border-inline-start:3px solid var(--dc-warn);border-radius:var(--dc-radius-sm);}
.dc-error{margin:0 0 1rem;padding:.6rem .85rem;font-size:.8rem;color:var(--dc-danger);background:var(--dc-card);border:1px solid var(--dc-danger);border-radius:var(--dc-radius-sm);}
.dc-error code{font-family:var(--dc-mono);}
.dc-wrap{display:grid;grid-template-columns:1fr 360px;gap:20px;align-items:start;}
@media (max-width:900px){.dc-wrap{grid-template-columns:1fr;}.dc-results{position:static!important;order:0;}}
.dc-results{position:sticky;top:16px;background:var(--dc-card);border:1px solid var(--dc-line);border-radius:var(--dc-radius);
  padding:16px 16px 20px;order:2;box-shadow:var(--dc-shadow);}
.dc-results h2{font-size:.7rem;font-weight:600;letter-spacing:.12em;text-transform:uppercase;color:var(--dc-muted);text-align:center;margin:0 0 8px;}
.dc-gaugewrap{display:flex;justify-content:center;}
.dc-gnum{font-size:38px;font-weight:700;text-anchor:middle;font-family:var(--dc-sans);}
.dc-ph{text-align:center;padding:20px 8px 8px;}
.dc-ph-icon{color:var(--dc-muted);opacity:.6;line-height:1;}
.dc-ph-msg{font-family:var(--dc-serif);font-size:16px;color:var(--dc-ink);margin:10px 0 6px;}
.dc-ph-missing{font-size:11.5px;color:var(--dc-muted);line-height:1.55;margin:0;}
.dc-me-toggle{margin-top:14px;padding-top:14px;border-top:1px solid var(--dc-line);}
.dc-me-row{display:flex;align-items:center;justify-content:space-between;gap:12px;}
.dc-me-row span{font-size:.86rem;color:var(--dc-ink);}
.dc-chartbox{margin-top:16px;padding-top:14px;border-top:1px solid var(--dc-line);}
.dc-chartbox h3{font-size:.7rem;text-transform:uppercase;letter-spacing:.12em;color:var(--dc-muted);margin:0 0 8px;font-weight:600;display:flex;align-items:center;gap:8px;}
.dc-chartbox h3::after{content:'';flex:1;height:1px;background:var(--dc-line);}
.dc-shap-tag{font-size:9px;letter-spacing:.08em;background:var(--dc-primary);color:var(--dc-primary-fg);padding:1px 6px;border-radius:6px;font-weight:600;}
.dc-note{font-size:10.5px;color:var(--dc-muted);font-style:italic;margin:8px 2px 0;}
.dc-refstrip{display:flex;align-items:center;justify-content:space-between;gap:8px;font-size:11px;color:var(--dc-muted);margin:2px 0 10px;}
.dc-refstrip b{color:var(--dc-ink);font-size:15px;font-weight:600;}
.dc-arrow{flex:1;height:2px;background:linear-gradient(90deg,var(--dc-line),var(--dc-muted));}
.dc-shap-legend{display:flex;gap:14px;font-size:10px;color:var(--dc-muted);margin-top:8px;}
.dc-shap-legend i{display:inline-block;width:9px;height:9px;border-radius:2px;margin-right:4px;vertical-align:middle;}
.dc-sh-row{display:grid;grid-template-columns:86px 1fr 44px;align-items:center;gap:6px;margin:4px 0;}
.dc-sh-lab{font-size:10.5px;color:var(--dc-ink);text-align:right;line-height:1.12;}
.dc-sh-track{position:relative;height:15px;background:var(--dc-wash);border-radius:4px;}
.dc-sh-axis{position:absolute;left:50%;top:0;bottom:0;width:1px;background:var(--dc-line);}
.dc-sh-fill{position:absolute;top:2px;bottom:2px;border-radius:3px;transition:width .18s ease,left .18s ease;}
.dc-sh-val{font-size:10px;font-variant-numeric:tabular-nums;font-family:var(--dc-mono);}
.dc-panels{display:flex;flex-direction:column;gap:12px;order:1;}
.dc-acc{border:1px solid var(--dc-line);border-radius:var(--dc-radius);overflow:hidden;background:var(--dc-card);box-shadow:var(--dc-shadow);}
.dc-acc>summary{list-style:none;cursor:pointer;padding:.8rem 1rem;background:var(--dc-card);color:var(--dc-ink);font-weight:600;font-size:.92rem;display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid transparent;}
.dc-acc>summary::-webkit-details-marker{display:none;}
.dc-acc>summary:hover{background:var(--dc-wash);}
.dc-acc[open]>summary{border-bottom-color:var(--dc-line);}
.dc-chev{transition:transform .2s;color:var(--dc-muted);font-size:.7rem;}
.dc-acc[open]>summary .dc-chev{transform:rotate(90deg);}
.dc-body{padding:1rem;}
.dc-grid2{display:grid;grid-template-columns:1fr 1fr;gap:14px;}
.dc-grid3{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;}
@media (max-width:560px){.dc-grid2,.dc-grid3{grid-template-columns:1fr;}}
.dc-fld{display:block;font-size:.72rem;color:var(--dc-muted);margin:0 0 5px;font-weight:600;}
.dair-calc input[type=number]{width:100%;padding:9px 10px;border:1px solid var(--dc-line);border-radius:var(--dc-radius-sm);font:inherit;font-size:15px;background:var(--dc-card);color:var(--dc-ink);}
.dair-calc input[type=number]:focus{outline:0;border-color:var(--dc-primary);box-shadow:0 0 0 3px var(--dc-wash);}
.dc-seg{display:inline-flex;flex-wrap:wrap;gap:6px;}
.dc-seg button{border:1px solid var(--dc-line);background:var(--dc-card);color:var(--dc-ink);padding:8px 12px;border-radius:var(--dc-radius-sm);font:inherit;font-size:13px;cursor:pointer;font-weight:500;min-width:60px;}
.dc-seg button:hover{background:var(--dc-wash);border-color:var(--dc-primary);}
.dc-seg button[aria-pressed=true]{background:var(--dc-primary);color:var(--dc-primary-fg);border-color:var(--dc-primary);}
.dc-seg button[aria-pressed=true]:hover{opacity:.9;}
.dc-toggles{display:grid;grid-template-columns:1fr 1fr;gap:8px;}
.dc-toggles.dc-one{grid-template-columns:1fr;}
.dc-toggles.dc-three{grid-template-columns:repeat(3,1fr);}
@media (max-width:560px){.dc-toggles,.dc-toggles.dc-three{grid-template-columns:1fr;}}
.dc-tog{border:1px solid var(--dc-line);background:var(--dc-card);color:var(--dc-ink);padding:9px 11px;border-radius:var(--dc-radius-sm);font:inherit;font-size:12.5px;cursor:pointer;text-align:left;font-weight:500;}
.dc-tog:hover{background:var(--dc-wash);border-color:var(--dc-primary);}
.dc-tog[aria-pressed=true]{background:var(--dc-primary);color:var(--dc-primary-fg);border-color:var(--dc-primary);}
.dc-tog[aria-pressed=true]:hover{opacity:.9;}
.dc-tog:disabled{opacity:.45;cursor:not-allowed;}
.dc-switch{position:relative;width:60px;height:28px;flex:0 0 auto;}
.dc-switch input{opacity:0;width:0;height:0;}
.dc-slider{position:absolute;inset:0;background:var(--dc-muted);border-radius:28px;transition:.2s;cursor:pointer;}
.dc-slider:before{content:"";position:absolute;height:22px;width:22px;left:3px;top:3px;background:var(--dc-card);border-radius:50%;transition:.2s;box-shadow:0 1px 2px rgba(0,0,0,.25);}
.dc-switch input:checked + .dc-slider{background:var(--dc-primary);}
.dc-switch input:checked + .dc-slider:before{transform:translateX(32px);}
.dc-yn{position:absolute;top:6px;font-size:10px;font-weight:600;color:var(--dc-primary-fg);}
.dc-yn.dc-y{left:9px;opacity:0;}.dc-yn.dc-n{right:9px;opacity:1;}
.dc-switch input:checked + .dc-slider .dc-y{opacity:1;}.dc-switch input:checked + .dc-slider .dc-n{opacity:0;}
.dc-sectiontitle{font-size:.78rem;font-weight:600;margin:4px 0 8px;color:var(--dc-ink);}
.dc-culture-q{display:flex;align-items:center;justify-content:space-between;gap:12px;background:var(--dc-wash);border:1px solid var(--dc-line);border-radius:var(--dc-radius-sm);padding:12px 14px;margin-top:6px;}
.dc-culture-q b{font-size:.9rem;color:var(--dc-ink);}
.dc-organisms{margin-top:12px;border:1px dashed var(--dc-line);border-radius:var(--dc-radius-sm);padding:12px;background:var(--dc-bg);}
.dc-organisms h4{margin:0 0 8px;font-size:.7rem;color:var(--dc-muted);text-transform:uppercase;letter-spacing:.1em;font-weight:600;}
.dc-warn{color:var(--dc-danger);font-weight:600;font-size:12.5px;margin-top:6px;}
.dc-warn.dc-confirm{color:var(--dc-warn);}
.dc-info p{font-size:.9rem;color:var(--dc-ink);}
.dc-info a{color:var(--dc-primary);text-decoration:none;}
.dc-info a:hover{text-decoration:underline;}
.dc-art{font-size:.82rem;border-top:1px solid var(--dc-line);padding:9px 0;}
.dc-art a{font-weight:600;color:var(--dc-ink);text-decoration:none;}
.dc-art a:hover{text-decoration:underline;}
.dc-meta{color:var(--dc-muted);font-size:.7rem;}
.dc-loading{font-size:12px;color:var(--dc-muted);padding:6px 0;}
.dc-loading a{color:var(--dc-primary);}
`;
