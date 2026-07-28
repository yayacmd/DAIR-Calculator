// dairModel.js — framework-agnostic logic for the DAIR Success Calculator.
// Pure functions + async model loaders. No React, no DOM. Safe for Capacitor/WKWebView.
//
// The two random forests were exported from the original randomForest objects.
// prob_success = (# trees voting class '1') / ntree. The SHAP explainer is an
// exact interventional TreeSHAP against a fixed low-risk reference patient.

export const COLORS = {
  ink:'#16202B', muted:'#5B6B7C', line:'#E3E8EE', surface:'#FAFBFC', card:'#FFFFFF',
  accent:'#1B4FA0', accentInk:'#0E2F63', accentWash:'#EEF3FB',
  green:'#1A7F4B', amber:'#B7791F', red:'#B3261E',
};

export const NUMERIC = new Set(['Age','BMI','days_to_DAIR','Last_CRP','Last_leucocytes','Dayssymptoms']);

export const LABELS = {
  late_infection:'Late Infection', Male:'Gender', Age:'Age', BMI:'BMI', Smoking:'Smoking',
  Alcohol:'Alcohol Use', Dementia:'Dementia', Hypertension:'Hypertension', IHD:'Dialysis',
  HF:'Heart Failure', oral_anticoagulant:'Anticoagulation', DM:'Diabetes', COPD:'COPD',
  CRF:'Chronic Kidney Disease', LC:'Liver Cirrhosis', Immunesuppresion:'Immunocompromised',
  malignancy:'Cancer', RA:'Rheumatoid Arthritis', Pacemaker_ICD:'Pacemaker/ICD',
  days_to_DAIR:'Days to DAIR', Indication_prosthesis:'Indication', index_revision:'Index Procedure',
  Cement:'Cemented Components', Joint:'Joint', Wound_leakage:'Wound Leakage', Necrosis:'Necrosis',
  Fistula:'Fistula', Last_CRP:'CRP Level', Last_leucocytes:'Leucocyte Count', Fever38:'Fever',
  Positive_bloodcultures:'Blood Cultures', Skin_infection:'Skin Infection',
  Mobilexchange:'Modular Component Exchange', Polymicrob:'Polymicrobial', STAU:'S. aureus',
  MRSA:'MRSA', Staphepi:'S. epidermidis', gramnegative:'Gram-negative', Escherichia_coli:'E. coli',
  Enterobacter_spp:'Enterobacter', Pseudomonas_aerugi0sa:'P. aeruginosa', Proteus_spp:'Proteus',
  Enterococcus_spp:'Enterococcus', Streptococci_spp:'Streptococcus', Candida_spp:'Candida',
  Dayssymptoms:'Days of Symptoms',
};

// The low-risk reference patient SHAP explains against.
export const BASELINE = {
  Age:'75', BMI:'26.5', Male:'1', Smoking:'0', Alcohol:'0',
  COPD:'0', Immunesuppresion:'0', Pacemaker_ICD:'0', oral_anticoagulant:'0', RA:'0', HF:'0',
  CRF:'0', LC:'0', malignancy:'0', Hypertension:'0', IHD:'0', Dementia:'0', DM:'0',
  Indication_prosthesis:'1', Joint:'1', index_revision:'0', Cement:'1', late_infection:'0',
  days_to_DAIR:'0', Dayssymptoms:'0',
  Wound_leakage:'0', Necrosis:'0', Fistula:'0', Fever38:'0', Skin_infection:'0',
  Last_CRP:'1.8', Last_leucocytes:'12.9', Positive_bloodcultures:'0',
  Mobilexchange:'0', Polymicrob:'0', STAU:'0', MRSA:'0', Staphepi:'0', gramnegative:'0',
  Escherichia_coli:'0', Enterobacter_spp:'0', Pseudomonas_aerugi0sa:'0', Proteus_spp:'0',
  Enterococcus_spp:'0', Streptococci_spp:'0', Candida_spp:'0',
};

export const ORGANISMS = ['STAU','MRSA','Staphepi','Pseudomonas_aerugi0sa','gramnegative',
  'Enterococcus_spp','Enterobacter_spp','Streptococci_spp','Polymicrob','Proteus_spp',
  'Escherichia_coli','Candida_spp'];

// required (no default value until the clinician sets it)
export const REQ_NUM = ['Age','BMI','Last_CRP','Last_leucocytes','days_to_DAIR','Dayssymptoms'];
export const REQ_SEG = ['Male','Joint','Indication_prosthesis','index_revision','Cement','late_infection','Culture'];
export const REQ_NAME = {Age:'Age', BMI:'BMI', Last_CRP:'CRP', Last_leucocytes:'Leucocytes',
  days_to_DAIR:'Days to DAIR', Dayssymptoms:'Days of symptoms', Male:'Gender', Joint:'Joint',
  Indication_prosthesis:'Indication', index_revision:'Index procedure', Cement:'Cemented',
  late_infection:'Late infection', Culture:'Cultures obtained?'};

export function initialState() {
  return {
    Age:'', BMI:'', Male:'', Smoking:'0', Alcohol:'0',
    COPD:'0', Immunesuppresion:'0', Pacemaker_ICD:'0', oral_anticoagulant:'0', RA:'0', HF:'0',
    CRF:'0', LC:'0', malignancy:'0', Hypertension:'0', IHD:'0', Dementia:'0', DM:'0',
    Indication_prosthesis:'', Joint:'', index_revision:'', Cement:'', late_infection:'',
    days_to_DAIR:'', Dayssymptoms:'',
    Wound_leakage:'0', Necrosis:'0', Fistula:'0', Fever38:'0', Skin_infection:'0',
    Last_CRP:'', Last_leucocytes:'', Positive_bloodcultures:'0',
    Mobilexchange:'0', Culture:'', CultureNeg:'0',
    Polymicrob:'0', STAU:'0', MRSA:'0', Staphepi:'0', gramnegative:'0', Escherichia_coli:'0',
    Enterobacter_spp:'0', Pseudomonas_aerugi0sa:'0', Proteus_spp:'0', Enterococcus_spp:'0',
    Streptococci_spp:'0', Candida_spp:'0',
  };
}

export function activeKey(state){ return state.Culture === '1' ? 'model_culture' : 'model_nculture'; }

export function missingRequired(state){
  const miss = [];
  for (const k of REQ_NUM){ const v = state[k]; if (v === '' || v == null || isNaN(parseFloat(v))) miss.push(REQ_NAME[k]); }
  for (const k of REQ_SEG){ if (!state[k]) miss.push(REQ_NAME[k]); }
  return miss;
}

// ---- binary model parser (matches the .bin layout) ----
export function parseModel(buf, ncat){
  const dv = new DataView(buf);
  const ntree = dv.getInt32(0, true), total = dv.getInt32(4, true);
  let o = 8;
  const split = new Float64Array(buf, o, total);       o += 8 * total;
  const treeStart = new Int32Array(buf, o, ntree + 1); o += 4 * (ntree + 1);
  const left  = new Int16Array(buf, o, total);         o += 2 * total;
  const right = new Int16Array(buf, o, total);         o += 2 * total;
  const varr  = new Uint8Array(buf, o, total);         o += total;
  const pred  = new Uint8Array(buf, o, total);         o += total;
  return { ntree, total, split, treeStart, left, right, varr, pred, ncat: Int16Array.from(ncat) };
}

export function encode(model, st){
  const names = model.names, n = names.length;
  const x = new Float64Array(n), codes = new Int16Array(n);
  for (let i = 0; i < n; i++){
    const nm = names[i], val = st[nm];
    if (NUMERIC.has(nm)){ x[i] = parseFloat(val) || 0; codes[i] = 0; }
    else { const c = model.levels[nm].indexOf(String(val)) + 1; codes[i] = c; x[i] = c; }
  }
  return { x, codes };
}

export function scoreModel(M, x, codes){
  const { ntree, treeStart, left, right, varr, pred, split, ncat } = M;
  let succ = 0;
  for (let t = 0; t < ntree; t++){
    const base = treeStart[t];
    let k = base;
    for (;;){
      const L = left[k];
      if (L === 0){ if (pred[k] === 2) succ++; break; }
      const v = varr[k];
      const goLeft = ncat[v - 1] === 1 ? x[v - 1] <= split[k] : codes[v - 1] === 1;
      k = base + (goLeft ? L : right[k]) - 1;
    }
  }
  return succ / ntree;
}

// ---- exact interventional TreeSHAP (single baseline) ----
export function binomTable(M){
  const C = [];
  for (let n = 0; n <= M; n++){ C[n] = new Float64Array(n + 1); C[n][0] = 1;
    for (let k = 1; k <= n; k++) C[n][k] = (C[n-1][k-1] || 0) + (C[n-1][k] || 0); }
  return C;
}
export function coeffTables(M){
  const C = binomTable(M); const g = s => 1 / (M * C[M-1][s]);
  const Sp = [], Sm = [];
  for (let a = 0; a <= M; a++){ Sp[a] = new Float64Array(M+1); Sm[a] = new Float64Array(M+1);
    for (let b = 0; b <= M - a; b++){ const f = M - a - b; let sp = 0, sm = 0;
      for (let t = 0; t <= f; t++){ const cc = C[f][t]; const i1 = a-1+t, i2 = a+t;
        if (i1 >= 0 && i1 < M) sp += cc * g(i1); if (i2 >= 0 && i2 < M) sm += cc * g(i2); }
      Sp[a][b] = sp; Sm[a][b] = sm; } }
  return { Sp, Sm };
}
export function shapValues(M, model, x, codes, xb, codesb, Sp, Sm){
  const { ntree, treeStart, left, right, varr, pred, split, ncat } = model;
  const phi = new Float64Array(M), req = new Int8Array(M);
  const inS = new Int32Array(M), outS = new Int32Array(M);
  let inN = 0, outN = 0, base = 0;
  function rec(k){
    const L = left[k];
    if (L === 0){ if (pred[k] === 2){ const sp = Sp[inN][outN], sm = Sm[inN][outN];
        if (sp || sm){ for (let q = 0; q < inN; q++) phi[inS[q]] += sp;
                       for (let q = 0; q < outN; q++) phi[outS[q]] -= sm; } }
      return; }
    const v = varr[k] - 1; let xl, bl;
    if (ncat[v] === 1){ xl = x[v] <= split[k]; bl = xb[v] <= split[k]; }
    else { xl = codes[v] === 1; bl = codesb[v] === 1; }
    const La = base + L - 1, Ra = base + right[k] - 1;
    for (let c = 0; c < 2; c++){
      const cl = c === 0; const xg = cl ? xl : !xl, bg = cl ? bl : !bl, nxt = cl ? La : Ra;
      if (!xg && !bg) continue;
      const need = (xg && bg) ? 0 : ((xg && !bg) ? 1 : 2);
      if (need === 0){ rec(nxt); continue; }
      const prev = req[v];
      if (prev === 0){ req[v] = need; if (need === 1) inS[inN++] = v; else outS[outN++] = v;
        rec(nxt); req[v] = 0; if (need === 1) inN--; else outN--; }
      else if (prev === need){ rec(nxt); }
    }
  }
  for (let t = 0; t < ntree; t++){ base = treeStart[t]; rec(base); }
  for (let i = 0; i < M; i++) phi[i] /= ntree;
  return phi;
}

// Attach metadata + precomputed SHAP tables + baseline encoding to a parsed model.
export function attachMeta(model, metaEntry){
  model.names = metaEntry.names;
  model.levels = metaEntry.levels;
  model.shap = coeffTables(model.names.length);
  model.baseEnc = encode(model, BASELINE);
  return model;
}

// Compute gauge % + SHAP effects for a completed state. Returns null if incomplete.
export function computeResult(state, model){
  if (!model) return null;
  const { x, codes } = encode(model, state);
  const base = scoreModel(model, x, codes);
  const fb = scoreModel(model, model.baseEnc.x, model.baseEnc.codes);
  const phi = shapValues(model.names.length, model, x, codes,
                         model.baseEnc.x, model.baseEnc.codes, model.shap.Sp, model.shap.Sm);
  const effects = [];
  for (let i = 0; i < model.names.length; i++)
    if (Math.abs(phi[i]) > 5e-5) effects.push({ name: model.names[i], value: phi[i] * 100 });
  effects.sort((a, b) => Math.abs(b.value) - Math.abs(a.value));
  return { pct: base * 100, fb: fb * 100, effects: effects.slice(0, 10) };
}

// ---- async loaders with a module-level cache (persist across mounts) ----
const _cache = new Map();   // key -> attached model
let _metaPromise = null;

export async function loadMeta(basePath = ''){
  if (!_metaPromise) _metaPromise = fetch(`${basePath}/models.json`).then(r => {
    if (!r.ok) throw new Error('models.json ' + r.status); return r.json();
  });
  return _metaPromise;
}
export async function loadModel(key, basePath = ''){
  if (_cache.has(key)) return _cache.get(key);
  const meta = await loadMeta(basePath);
  const buf = await fetch(`${basePath}/${key}.bin`).then(r => {
    if (!r.ok) throw new Error(key + '.bin ' + r.status); return r.arrayBuffer();
  });
  const model = attachMeta(parseModel(buf, meta.models[key].ncat), meta.models[key]);
  _cache.set(key, model);
  return model;
}
export function getCachedModel(key){ return _cache.get(key) || null; }
