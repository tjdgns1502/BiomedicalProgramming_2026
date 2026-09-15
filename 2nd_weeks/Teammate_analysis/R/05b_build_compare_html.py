# -*- coding: utf-8 -*-
"""
05b_build_compare_html.py — data/table1_comparison.csv → Table1_비교.html
논문 Table 1 과 같은 배치로 재현값을 놓고, 논문값과의 차이를 색으로 표시한다.
  실행: uv run R/05b_build_compare_html.py
"""
import csv, math, pathlib
from collections import OrderedDict

proj = pathlib.Path(__file__).resolve().parent.parent
rows = list(csv.DictReader(open(proj / "data" / "table1_comparison.csv", encoding="utf-8")))

TOL_MATCH, TOL_MINOR = 0.1, 1.0
def num(x):
    try: return float(x)
    except: return math.nan

def flag(d, dsd):
    ds = [abs(v) for v in (d, dsd) if not math.isnan(v)]
    m = max(ds) if ds else 0
    return "match" if m <= TOL_MATCH else "minor" if m <= TOL_MINOR else "diff"

# ---- 행 구조 복원 -------------------------------------------------------------
sections = OrderedDict()
for r in rows:
    key = (r["row"], r["level"])
    sections.setdefault(r["section"], OrderedDict()).setdefault(key, {})[r["col"]] = r

def cell(r):
    t = r["type"]; rp, pp = num(r["repro"]), num(r["paper"])
    rs, ps = num(r["repro_sd"]), num(r["paper_sd"])
    d, dsd = rp - pp, (rs - ps if not math.isnan(rs) else math.nan)
    f = flag(d, dsd)
    if t == "n":
        main, ref, dtxt = f"N = {rp:,.0f}", f"논문 N = {pp:,.0f}", f"{d:+.0f}명"
    elif t == "cont":
        main, ref = f"{rp:.2f} ± {rs:.2f}", f"논문 {pp:.2f} ± {ps:.2f}"
        dtxt = f"Δ평균 {d:+.2f}" + (f", ΔSD {dsd:+.2f}" if abs(dsd) > TOL_MATCH else "")
    else:
        main, ref, dtxt = f"{rp:.2f}", f"논문 {pp:.2f}", f"Δ {d:+.2f}"
    return f'<td class="v {f}"><div class="main">{main}</div><div class="ref">{ref}</div><div class="d">{dtxt}</div></td>', f

def pcell(pr, pp):
    if pr == "" and pp == "": return '<td></td>'
    same = (pr == pp)
    return f'<td class="v p {"match" if same else "diff"}"><div class="main">{pr}</div><div class="ref">논문 {pp}</div></td>'

counts = {"match": 0, "minor": 0, "diff": 0}
body = []
for sec, keys in sections.items():
    first = True
    for (row, level), cols in keys.items():
        q = [cols[f"Q{i}"] for i in range(1, 5)]
        cells, flags = zip(*(cell(r) for r in q))
        for f in flags: counts[f] += 1
        t = q[0]["type"]
        if t == "n":
            body.append(f'<tr class="nrow"><td><b>N (사분위군 인원)</b></td>{"".join(cells)}<td></td></tr>'); continue
        if t == "cat":
            if first:
                body.append(f'<tr class="hdr"><td>{sec}</td><td></td><td></td><td></td><td></td>{pcell(q[0]["p_repro"], q[0]["p_paper"])}</tr>')
                first = False
            body.append(f'<tr><td class="lv">{level}</td>{"".join(cells)}<td></td></tr>')
        else:
            name = row if not row.startswith("  (참고)") else f'<span class="note">{row.strip()}</span>'
            body.append(f'<tr><td>{name}</td>{"".join(cells)}{pcell(q[0]["p_repro"], q[0]["p_paper"])}</tr>')

html = f"""<!DOCTYPE html>
<html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Table 1 재현 비교 — WWI와 뇌졸중</title>
<style>
 body{{margin:0;font-family:"Pretendard","Malgun Gothic","Noto Sans KR",system-ui,sans-serif;color:#1f2937;background:#fafafa;font-size:14px;line-height:1.5}}
 .wrap{{max-width:1180px;margin:0 auto;padding:28px 20px 60px}}
 h1{{font-size:1.4rem;margin:0 0 4px}} .sub{{color:#6b7280;font-size:.9rem;margin-bottom:16px}}
 .legend{{display:flex;gap:14px;flex-wrap:wrap;margin:12px 0 18px;font-size:.88rem}}
 .legend span{{display:inline-flex;align-items:center;gap:6px}} .sw{{width:16px;height:16px;border-radius:4px;border:1px solid #d1d5db;display:inline-block}}
 .tbl{{overflow-x:auto;background:#fff;border:1px solid #e5e7eb;border-radius:10px}}
 table{{border-collapse:collapse;width:100%;min-width:900px}}
 th,td{{padding:6px 10px;border-bottom:1px solid #f3f4f6;vertical-align:top;text-align:left}}
 thead th{{background:#f3f4f6;border-bottom:2px solid #d1d5db;position:sticky;top:0}}
 thead th.q{{text-align:left}} thead .cut{{font-weight:400;color:#6b7280;font-size:.85rem}}
 tr.hdr td{{font-weight:600;padding-top:10px}} td.lv{{padding-left:26px}}
 tr.nrow td{{background:#f9fafb}}
 td.v .main{{font-variant-numeric:tabular-nums;font-weight:600}} td.v .ref{{font-size:.78rem;color:#6b7280}} td.v .d{{font-size:.76rem;color:#9ca3af}}
 td.v.match{{background:#f0fdf4}} td.v.match .main{{color:#166534}}
 td.v.minor{{background:#fffbeb}} td.v.minor .main{{color:#92400e}} td.v.minor .d{{color:#b45309}}
 td.v.diff{{background:#fef2f2}}  td.v.diff .main{{color:#b91c1c}} td.v.diff .d{{color:#dc2626;font-weight:600}}
 td.p .main{{font-weight:500}}
 .note{{color:#6b7280;font-style:italic}}
 .box{{border:1px solid #e5e7eb;border-radius:10px;padding:12px 16px;margin:16px 0;background:#fff}}
 .box.warn{{background:#fff7ed;border-color:#fed7aa}} .box .ttl{{font-weight:700;margin-bottom:4px}}
 ul{{margin:6px 0;padding-left:22px}} li{{margin:3px 0}}
 code{{background:#f3f4f6;padding:1px 5px;border-radius:4px;font-family:Consolas,monospace;font-size:.9em}}
 .stat{{display:flex;gap:10px;flex-wrap:wrap;margin:10px 0}} .stat div{{border-radius:8px;padding:8px 14px;font-weight:600}}
 @media print{{.tbl{{overflow:visible}}}}
</style></head><body><div class="wrap">
<h1>Table 1 재현 비교 — 논문(Ye et al. 2023) vs NHANES 2011–2020 재분석</h1>
<div class="sub">각 셀: <b>위 = 재현값</b>(<code>survey</code> 패키지, 논문 방식인 설문 가중치 사용) · 아래 = 논문 원본 값 · Δ = 재현 − 논문. 연속변수는 mean ± SD, 범주변수는 가중 %. N = 23,389.</div>
<div class="legend">
 <span><i class="sw" style="background:#f0fdf4"></i>일치 (|Δ| ≤ 0.1, 반올림 수준)</span>
 <span><i class="sw" style="background:#fffbeb"></i>근소 차이 (0.1 &lt; |Δ| ≤ 1)</span>
 <span><i class="sw" style="background:#fef2f2"></i><b style="color:#b91c1c">차이 (|Δ| &gt; 1, 평균 또는 SD)</b></span>
</div>
<div class="stat">
 <div style="background:#f0fdf4;color:#166534">일치 {counts['match']}셀</div>
 <div style="background:#fffbeb;color:#92400e">근소 {counts['minor']}셀</div>
 <div style="background:#fef2f2;color:#b91c1c">차이 {counts['diff']}셀</div>
</div>
<div class="tbl"><table>
<thead><tr><th>Characteristics</th>
<th class="q">Q1 <span class="cut">(&lt;10.51)</span></th><th class="q">Q2 <span class="cut">(10.51–11.09)</span></th>
<th class="q">Q3 <span class="cut">(11.10–11.67)</span></th><th class="q">Q4 <span class="cut">(&gt;11.67)</span></th><th>P value</th></tr></thead>
<tbody>
{chr(10).join(body)}
</tbody></table></div>

<div class="box warn"><div class="ttl">빨간 셀의 원인 — 가설 검정(<code>R/06_diagnose_discrepancies.R</code>)으로 전부 확인됨. 남은 빨간 셀은 모두 의도된 것</div>
<ul>
 <li><b>음주량</b> — 재현 본행은 "거부=777, 모름=999"를 결측으로 바꿨고 논문은 바꾸지 않았습니다. 아래 <i>(참고)</i> 행처럼 코드값을 그대로 두고 논문 방식의 P(단순 가중회귀)를 쓰면 <b>3.24±18.67 / 4.29±39.96 / 2.99±20.49 / 3.33±29.64, P=0.187 로 소수 둘째 자리까지 완전히 일치</b>합니다. 이 값은 999 다섯 명의 흔적이지 음주 습관이 아닙니다.</li>
 <li><b>중성지방·LDL-C</b> — 공복 하위표본만 측정되어 54%가 결측인데, 논문은 이를 <b>전체 평균으로 대치</b>했습니다(검정 B: SD 축소 배율 √(관측비율)=0.67이 이론값과 일치). 본행은 관측값만 사용(올바른 관행), <i>(참고)</i> 행이 논문 방식 재현.</li>
 <li><b>PIR·HDL-C·총콜레스테롤</b> — 결측 5~10%도 같은 방식으로 평균 대치(검정 D). 본행은 근소 차이, <i>(참고)</i> 행에서 일치.</li>
</ul></div>
<div class="box"><div class="ttl">가중치 — 논문은 "설문(interview) 가중치"를 재조정 없이 그대로 썼다 (검정 A·I)</div>
<p style="margin:4px 0">처음 재현은 CDC 지침대로 <b>검진(MEC) 가중치</b>를 기간 비율(2/9.2, 3.2/9.2)로 재조정했고, 이때 Q4의 나이·체중·교육·뇌졸중이 0.3~1.1 어긋났습니다(합계 점수 16.8). 7가지 가중치 방식을 시험한 결과 MEC 원가중치(9.8)보다 <b>설문 가중치 <code>WTINT2YR</code>/<code>WTINTPRP</code> 원가중치</b>(6.6, 대치 후 1.0)가 압도적으로 좋았고, 결정적으로 음주량 행이 소수 둘째 자리까지 일치했습니다 — 이 행은 SD가 999 응답자 4~5명의 개별 가중치로 결정되므로 가중치 변수의 "지문" 역할을 합니다. 체중·허리둘레는 검진 자료라 원칙은 MEC 가중치이지만, 논문은 설문 가중치를 썼습니다. 두 방식의 차이는 Table 1 값 기준 최대 0.4로 결론에는 영향이 없습니다.</p>
<p style="margin:4px 0"><b>P값</b>: 논문의 연속변수 P는 층·군집을 무시한 단순 가중회귀 <code>lm(y ~ Q, weights = w)</code>의 F검정입니다(검정 F: 음주량 P 0.187 정확히 일치, 설계기반 <code>svyglm</code>은 0.496). 본행의 P는 설계기반(올바른 방법), <i>(참고)</i> 행의 P는 논문 방식입니다. 다른 행은 모두 P&lt;0.001이라 방식과 무관합니다.</p></div>
<div class="box"><div class="ttl">이미 논문과 맞춘 코딩 규칙 (논문에 명시되지 않아 역산한 것)</div>
<ul>
 <li>뇌졸중 "모름"(코드 9) 22명 → 포함, 뇌졸중 없음으로 처리 (N = 23,389 일치)</li>
 <li>당뇨 "경계성"(<code>DIQ010</code> = 3) → 당뇨 있음 (Q1 3.05 vs 3.01)</li>
 <li>사분위 절단을 [a, b) 구간으로 (<code>cut(right = FALSE)</code>) → 5,847 / 5,847 / 5,847 / 5,848 일치</li>
 <li>Table 1 은 설문 가중치(WTINT) 원가중치로 계산, P 는 단순 가중회귀 (Table 2·3 의 OR 은 비가중 <code>glm</code> 과 일치)</li>
 <li>결측 연속형 공변량(중성지방·LDL·PIR·HDL·TC)은 전체 평균 대치 — <i>(참고)</i> 행으로 재현</li>
</ul></div>
<p style="color:#6b7280;font-size:.85rem">생성: <code>R/05_compare_table1.R</code> → <code>data/table1_comparison.csv</code> → <code>R/05b_build_compare_html.py</code></p>
</div></body></html>"""

out = proj / "Table1_비교.html"
out.write_text(html, encoding="utf-8")
print(out, counts)
