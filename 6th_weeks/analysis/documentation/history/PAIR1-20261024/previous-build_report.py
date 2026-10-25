from pathlib import Path
import json,csv,hashlib,base64,html,sys,datetime,re
from urllib.parse import quote
root=Path(sys.argv[1]).resolve();run_id=sys.argv[2];run=root/'analysis/runs'/run_id
def load(p):return json.loads(p.read_text(encoding='utf-8-sig'))
def rows(p):
 with p.open(encoding='utf-8-sig',newline='') as f:return list(csv.DictReader(f))
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,s):p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(s.encode('utf-8'))
def jwrite(p,x):write(p,json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def e(x):return html.escape(str(x),quote=True)
def fmt(v,n=3):return f'{float(v):.{n}f}'
def pval(v):return f'{float(v):.3g}'
def mdtable(headers,body):return '| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+''.join('| '+' | '.join(str(x) for x in row)+' |\n' for row in body)
def table(headers,body,cls=''):
 return '<div class="table-wrap"><table class="'+cls+'"><thead><tr>'+''.join('<th>'+e(x)+'</th>' for x in headers)+'</tr></thead><tbody>'+''.join('<tr>'+''.join('<td>'+str(x)+'</td>' for x in row)+'</tr>' for row in body)+'</tbody></table></div>'
def link(rel,label):
 assert (root/rel).exists(),rel
 return f'<a href="{quote(rel,safe="/")}">{e(label)}</a>'
def plotpath(name):
 style=root/'analysis/renderings/STYLE1-20261024/manifest.json'
 if style.exists():
  m=load(style)
  if m['run_id']==run_id and name in m['overrides']:
   assert sha(run/'tables/observation_diagnostics.csv')==m['source_sha256']
   return root/m['overrides'][name]
 return run/'figures'/name
def fig(name,title,caption):
 p=plotpath(name)
 return f'<figure><figcaption><h3>{title}</h3><p>{caption}</p></figcaption><img src="data:image/png;base64,{base64.b64encode(p.read_bytes()).decode()}" alt="{e(title)}" loading="lazy" decoding="async"></figure>'
plan=load(root/'analysis/config/plan-v1.0.json');result=load(run/'report.json');cross=load(run/'python_crosscheck.json');compare=load(run/'publication_comparison_manifest.json');issues=load(root/'analysis/memory/issues.json')
summary=rows(run/'tables/device_summary.csv');pairs=rows(run/'tables/heart_rate_pairs.csv');sensitivity=rows(run/'tables/sensitivity_summary.csv');comparison=rows(run/'tables/publication_comparison.csv');rounding=rows(run/'tables/reported_rounding_diagnostic.csv')
assert len(summary)==4 and len(pairs)==88 and result['excluded_pairs']==0
assert cross['decision']=='pass' and compare['correlations_match']==4
S={z['device']:z for z in summary};L={z['device']:z for z in sensitivity}
device_names=list(S);short={'Apple Watch':'Apple','Fitbit Charge HR':'Fitbit','Samsung Gear S':'Samsung','Mio Alpha':'Mio'}
T=['기기','n','Pearson r','r의 95%CI','평균오차 bpm','MAE bpm','RMSE bpm']
mainrows=[[z['device'],z['n'],fmt(z['pearson_r']),f"{fmt(z['r_ci_low'])} ~ {fmt(z['r_ci_high'])}",fmt(z['bias'],2),fmt(z['mae'],2),fmt(z['rmse'],2)] for z in summary]
R=['기기','회귀식 (시계 = a + b×ECG)','기울기 95%CI','R²','ECG100에서 적합값']
regrows=[[z['device'],f"{fmt(z['intercept'],2)} + {fmt(z['slope'])} × ECG",f"{fmt(z['slope_ci_low'])} ~ {fmt(z['slope_ci_high'])}",fmt(z['r_squared']),fmt(z['predicted_at_ecg100'],2)] for z in summary]
E=['기기','평균오차','평균오차 95%CI','오차 SD','고정 LoA 하한','고정 LoA 상한','MAPE %']
errrows=[[z['device'],fmt(z['bias'],2),f"{fmt(z['bias_ci_low'],2)} ~ {fmt(z['bias_ci_high'],2)}",fmt(z['error_sd'],2),fmt(z['classical_loa_low'],2),fmt(z['classical_loa_high'],2),fmt(z['mape'],2)] for z in summary]
sensrows=[[z['device'],f"{fmt(z['loo_r_min'])} ~ {fmt(z['loo_r_max'])}",f"{fmt(z['loo_slope_min'])} ~ {fmt(z['loo_slope_max'])}",z['largest_r_change_id']] for z in sensitivity]
source_links='[논문](https://doi.org/10.1371/journal.pone.0154420) · [공개 XLSX](https://doi.org/10.1371/journal.pone.0154420.s001) · [수정 슬라이드](https://slides.pnucolab.com/9eGiQnmVQB7D)'
pre='자료 버전: `'+plan['data_version']+'` · 실행: `'+run_id+'` · 단위: bpm · 작성일: 2026-10-24\n\n'
stages={
'00-요청과실행기준.md':('요청과 실행 기준',f'''## 입력과 질문
{source_links}

같은 대상자의 시계 평균 심박수와 해당 시계 착용 trial의 ECG 평균이 함께 변하는 정도와, 두 값의 차이가 얼마나 큰지를 분석합니다.

## 실행 전 고정한 기준
- 대상자는 22명, 각 기기의 참가자별 평균 22쌍, 총 88쌍입니다. 88명을 뜻하지 않습니다.
- 원본 XLSX의 6개 시트를 보존합니다. 주 분석은 Heart_Rate입니다. 에너지 소비·걸음 수는 이번 심박수 과제의 다른 결과변수라 분석 범위에서 제외합니다.
- 자료 축소·이상치 삭제·대체·주 분석의 임의 반올림을 하지 않습니다.
- x=ECG, y=시계, 오차=y−x를 일관되게 사용합니다.
- 주 분석은 모든 기기의 Pearson, cor와 lm, 산점도·y=x·회귀선, 오차 히스토그램입니다.
- Spearman, 고정 Bland–Altman, 잔차·Q-Q와 한 명씩 제외 민감도는 명시한 보조 진단입니다.
- 원문 수치가 출처 읽기에서 노출됐으므로 맹검이라고 표현하지 않습니다.
- 자료·코드 변경만 통계 재실행, 서식 변경은 화면 확인으로 한정합니다.

## 출력과 완료
중간 과정은 docs의 단계별 MD와 기기별 MD에 남기고, 최종 보고서는 루트의 `최종분석보고서.html` 한 개입니다. HTML에는 7개 그림·모든 88개 값·문제와 수정·한계가 들어갑니다. R 계산 28개 확인과 Python 402개 교차 확인을 수행했고 외부/별도 에이전트 심사는 아닙니다.
'''),
'01-출처와수정슬라이드.md':('출처와 수정 슬라이드',f'''## 입력과 확인
{source_links}

슬라이드의 6주차 부분은 Wallen 논문, 공개 XLSX, Pearson 상관, 단순 선형회귀, 오차=시계−기준, 산점도·회귀선·y=x와 오차 히스토그램을 요구합니다. 입력 자료 안의 지시문은 자료로 읽고 사용자 요청을 수행 기준으로 삼았습니다.

## 확보 과정과 문제
DOI/슬라이드의 웹 읽기 실패 뒤 공식 PLOS 다운로드와 공개 슬라이드 직접 요청으로 확보했습니다. 원본 XLSX SHA256은 `{plan['raw_sha256']}`입니다. 가져오기 전후 동일함을 확인했습니다. 원본 페이지는 최종 HTML과 구별해 `.source.txt`에 보존했습니다. 영구 공식 DOI를 출처로 쓰고 일시적인 서명된 리디렉션 query는 목록에서 제거했습니다.

## 논문과 과제의 범위
논문은 ECG 기준 심박수 외에 간접열량측정·걸음 수·ICC 등을 다룹니다. 이번에는 수정 슬라이드의 심박수 과제를 수행합니다. 공개 HR 시트에는 활동·시각 열이 없어 연구 중 기록했다는 15초 시계열을 복원할 수 없습니다.

## 출력
sources/acquisition_manifest.json, paper.manuscript.xml, published_tables.json, lecture.extracted.txt, workbook_inspection.json.
'''),
'02-원자료구조와정리.md':('원자료 구조와 정리','''## 원자료와 분석 단위
Heart_Rate는 A1:M23입니다. 1행은 이름, 2~23행은 ID1~22입니다. 한 행에 기기 4개의 시계·기준·trial 블록이 있습니다. 공개값은 참가자별 protocol 평균이고, 이번 분석자가 시계열을 평균내서 줄인 것이 아닙니다.

## 열 매핑
| 기기 | 시계 | ECG 기준 | Trial |
| --- | --- | --- | --- |
| Apple Watch | B | C | D |
| Fitbit Charge HR | E | F | G |
| Samsung Gear S | H | I | J |
| Mio Alpha | K | L | M |

F1은 Fitbit_metamax라고 적혀 있으나 Key의 Worksheet_4는 ECG 심박수라고 정의합니다. 에너지 소비 시트의 Metamax와 혼동하지 않고 원래 열명과 셀 주소를 보존한 채 reference_bpm으로 매핑했습니다. 반복되는 Trial_number는 자동 이름 변경에 의존하지 않습니다. Integer로 적힌 Key와 달리 원자료는 소수이므로 소수를 보존합니다.

## 변환
22개 wide 행을 88개 long 쌍으로 펼칩니다. 평균·추출·이상치 삭제·보간을 하지 않습니다. error_bpm=device_bpm−reference_bpm, pair_mean_bpm=(device_bpm+reference_bpm)/2입니다. 각 값은 B2/C2 같은 원본 셀로 추적됩니다.

## 출력과 남은 범위
tables/heart_rate_pairs.csv에는 88쌍 전부와 ID·trial·원래 열명·셀 주소가 있습니다. 활동별 HR·15초 오차는 공개되지 않아 생성하지 않습니다. 다른 시트와 같은 행번호라는 이유로 활동 정보를 결합하지 않았습니다.
'''),
'03-품질검사와자료흐름.md':('품질 검사와 자료 흐름',f'''## 질문
올바른 사람·기기·trial의 시계와 ECG가 쌍을 이루는가? 정리 과정에서 값이 빠지거나 바뀌었는가?

## 확인 결과
- ID1~22가 중복 없이 존재합니다.
- 기기별 22쌍, 총 88쌍 모두 유한한 양수이고 trial은1/2입니다.
- ID×trial44개 그룹마다 두 기기가 있고 같은 trial의 ECG 값이 일치합니다.
- 결측쌍0, 제외0, 대체0, 무작위 축소0, 주 분석 이상치 삭제0입니다.
- 원본 XLSX 해시는 전후 동일합니다.
- R의 28개 수학·자료 검사, OpenPyXL/NumPy와 R 결과의 402개 비교를 통과했습니다.

## 교차 계산
Python은 원본 Excel을 별도로 읽어 352개 원시 값(ID·시계·기준·trial)을 대조하고 회귀를 최소제곱 행렬 연산으로 계산했습니다. Pearson·기울기·절편·평균오차·SD·MAE·RMSE·MPE·MAPE·고정 LoA를 절대차1e-9 이내로 대조했습니다. 같은 에이전트가 수행한 언어 간 검산이며 외부 독립 심사가 아닙니다.

## 출력
data_flow.csv, excluded_pairs.csv(머리글만 있고 제외행0), validation_checks.csv, python_crosscheck.json. R 실행 시간은 {result['elapsed_seconds']:.2f}초입니다. 토큰·요금 계측은 제공되지 않아 추정하지 않았습니다.
'''),
'04-산점도와상관.md':('산점도와 Pearson 상관',f'''## 입력과 질문
기기별 참가자22쌍을 사용합니다. ECG가 높은 사람에게서 시계 평균도 높은가를 묻습니다.

## 방법
r=Sxy/sqrt(Sxx×Syy). R cor와 cor.test(method="pearson")를 사용했습니다. 95%CI는 Fisher z 변환이고, 기기별22명에 대한 점별 구간입니다. 네 r=0 검정의 Holm p는 CSV에 따로 보존했습니다. 주 해석은 효과와 오차를 함께 읽는 것입니다.

## 결과
{mdtable(T,mainrows)}
## 그림과 해석
01_scatter_regression.png의 점 하나는 참가자 한 명의 해당 기기 평균입니다. 검은 점선 y=x와 색 회귀선·평균반응95%CI를 함께 표시했습니다. r가 높아도 y=x에서 떨어질 수 있습니다. Fitbit은 r={fmt(S['Fitbit Charge HR']['pearson_r'])}이지만 MAE={fmt(S['Fitbit Charge HR']['mae'],2)}bpm입니다.

## 원문과 다른 통계
Samsung 원문0.67은 별표 각주상 Spearman입니다. 보조 Spearman={fmt(S['Samsung Gear S']['spearman_rho'],6)}로 원문과 맞지만, 과제 주 분석 Pearson={fmt(S['Samsung Gear S']['pearson_r'],6)}을 교체하지 않았습니다. 공변 범위·소수 대상자·큰 오차가 r에 영향을 줍니다.
'''),
'05-단순선형회귀.md':('단순 선형회귀',f'''## 질문과 모형
시계 평균이 ECG와 어떤 직선 관계에 있는가? y=시계, x=동시 ECG이고 y=a+b×x+잔차입니다. R lm(device_bpm~reference_bpm)을 기기마다 별도로 적합했습니다.

## 최소 계산과 확인
b=Sxy/Sxx, a=y평균−b×x평균입니다. 절편이 있는 단순회귀의 R²=r²를 확인했습니다. 평균반응 CI와 개인의 예측구간·LoA는 다릅니다.

## 결과
{mdtable(R,regrows)}
## 해석과 한계
Fitbit의 기울기 {fmt(S['Fitbit Charge HR']['slope'])}는 관측 범위에서 ECG 변화보다 시계 평균의 변화가 작게 나타난다는 기술입니다. y=x의 절편0·기울기1과 비교하되 학습자료의 회귀 적합을 외부 예측 성능이나 인과효과로 표현하지 않습니다. ECG 자체도 측정값이므로 OLS가 오차 없는 참값의 보정식을 증명하는 것은 아닙니다.

## 출력
regression_coefficients.csv, regression_mean_response_ci.csv, models/per_device_ols.rds, 산점도·잔차·Q-Q 그림.
'''),
'06-측정오차와일치도.md':('측정 오차와 일치도',f'''## 오차 정의
e=시계−ECG. 음수는 과소추정입니다. 평균오차는 방향, MAE=평균|e|는 평균 크기, RMSE=sqrt(평균e²)는 큰 오차에 민감합니다. MPE=평균(100e/ECG), MAPE=평균(100|e|/ECG)이며 논문의 다른 백분율 정의와 자동으로 동일시하지 않습니다.

## 결과
{mdtable(E,errrows)}
## 해석
네 기기의 표본 평균오차는 모두 음수입니다. 평균오차가0에 가까워도 양·음 오차가 상쇄될 수 있어 MAE와 분포를 함께 봅니다. Apple의 평균오차 CI가0을 포함한다는 사실만으로 개별값의 일치가 입증되지 않습니다.

## 그림
02_error_histograms.png는 공통5bpm 구간·동일 축을 사용해22명 전부를 표시합니다. 03_bland_altman.png의 가로축은 두 방법 평균, 세로축은 차이입니다. 고정 LoA는 평균오차±1.96SD로 기술했습니다. 평균오차95%CI와 개별 차이의 LoA를 구분합니다.

## 한계
LoA는 임상 허용 기준이 아닙니다. 평균·분산이 크기에 따라 바뀌면 고정 LoA가 적절하지 않을 수 있습니다. 논문의 Mio LoA는 평균에 따라 달라지는 방정식이어서 이번 고정값을 원문 완전 재현으로 부르지 않습니다.
'''),
'07-진단과민감도.md':('진단과 제외 없는 민감도',f'''## 질문
직선의 잔차에 구조가 있는가? 한 사람이 r·기울기·오차 요약에 큰 영향을 주는가?

## 방법
잔차 대 적합값, 정규 Q-Q, Shapiro 진단, Cook 거리, 오차~두 측정 평균 기울기를 확인했습니다. 22명 중 한 명씩 별도로 제외한 보조 적합을 기기별22회 했습니다. 이는 주 분석 표본을 줄이는 절차나 holdout 예측 검증이 아닙니다. 원자료88쌍과 주 결과는 유지됩니다.

## 결과
{mdtable(['기기','한 명씩 제외 r 범위','기울기 범위','r 변화가 가장 큰 제외 ID'],sensrows)}
## 해석
막대 범위는 신뢰구간이 아니라 제외 시나리오의 최소~최대입니다. 가장 큰 변화 대상자를 결과를 좋게 만들기 위해 삭제하지 않습니다. 작은 표본·이상치·이분산·집계값 특성은 결론의 한계로 남깁니다.

## 출력
observation_diagnostics.csv, leave_one_participant_out.csv(88개 보조 적합), sensitivity_summary.csv, 04~06 그림. 주 표본 n은 여전히 기기별22명입니다.
'''),
'08-논문비교와최종해석.md':('논문 비교와 최종 해석',f'''## 비교 범위
논문 Table1의 심박수 N·평균·SD·각주에 따른 상관과 세 기기의 고정 LoA를 비교했습니다. ICC·에너지 소비·걸음 수 전체를 재현했다는 주장은 하지 않습니다. n0·r0.005·평균0.05는 통계 실행 전 계획에 고정했습니다. SD·고정LoA의0.05는 원문 표 추출 후 같은1자리 표기 정밀도에 적용한 비교 기준입니다. 모든 기준을 사전등록했다고 표현하지 않습니다.

## 결과
38개 비교 중33개가 허용오차 내입니다. 원문 방식 상관은 네 기기 모두 맞습니다. Samsung의 원문값은 Spearman이므로 Pearson과 다르다는 사실이 계산 오류는 아닙니다. Samsung 평균오차와 일부 고정LoA는 작은 차이가 남았습니다.

## 사후 설명 점검
출판된1자리 평균오차·SD를 LoA 식에 대입하면 세 기기의 고정LoA6개가 출판값0.05 이내가 됩니다. 이는 반올림 과정과 양립하는 점검이며 저자의 계산 순서를 입증하지는 않습니다. 주 결과를 원문에 맞춰 반올림하거나 원자료를 수정하지 않았습니다. Mio의 가변LoA와는 직접 비교하지 않습니다.

## 최종 답
공개 평균자료의88쌍을 모두 분석했고, 참가자별 평균 수준에서 양의 상관과 음의 평균오차를 확인했습니다. Apple의 MAE는{fmt(S['Apple Watch']['mae'],2)}bpm, Fitbit은{fmt(S['Fitbit Charge HR']['mae'],2)}bpm으로 상관이 높아도 일치가 좋다고 단정할 수 없습니다. 여기의 기기별 숫자는 표본 기술치이며 전체 기기·모든 상황의 우열 검정이 아닙니다.

## 남은 제한
소수의 젊고 건강한 참가자, 실험실 평균자료, 평균에 가려진 순간오차, 기기 간 같은 참가자 반복, 기준측정 오차, 회귀·LoA 가정, 현재 제품으로의 일반화 제한이 남습니다. 활동별·시계열 정확도와 임상적 교환 가능성은 이 자료로 확정할 수 없습니다.
''')}
issue_table=mdtable(['ID','종류','발견','조치','상태'],[[z['id'],z['type'],z['finding'],z['action'],z['status']] for z in issues])
stages['09-문제와수정내역.md']=('문제와 수정 내역','''## 기록 원칙
소스의 제한, 메타데이터 오기, 환경·가져오기 실패, 통계 해석 문제를 구분합니다. 실패한 점검은 성공한 통계 실행과 구별하며 없는 실패를 만들어내지 않습니다.

'''+issue_table+'''
## 현재 실행
R 통계 run은 R1-20261024 한 번 성공했습니다. 초기 웹 가져오기 실패, 잘못된 보조 경로 선택과 readxl 준비는 원자료 변경 전 단계의 문제입니다. 원자료 내용과 주 분석 정의를 바꾸는 후속 수정은 없어 통계 run을 중복 실행하지 않았습니다.
''')
mds={}
for name,(title,text) in stages.items():
 rel='docs/'+name;content='# '+title+'\n\n'+pre+text+'\n';write(root/rel,content);mds[rel]=content
for name,z in S.items():
 l=L[name];first=next(x for x in pairs if x['device']==name)
 content=f'''# {name}: 입력에서 결과까지

{pre}## 입력과 짝짓기
Heart_Rate 시트의{name}22쌍을 전부 사용했습니다. ID1 예: 시계 {first['device_bpm']}({first['device_cell']}), ECG {first['reference_bpm']}({first['reference_cell']}), trial{first['trial']}입니다. 오차는{fmt(first['error_bpm'],2)}bpm입니다. 이 예시는 설명용이며 통계는22명 전부로 계산했습니다.

## 상관
Pearson r={fmt(z['pearson_r'],6)}, 95%CI[{fmt(z['r_ci_low'])},{fmt(z['r_ci_high'])}], p={pval(z['pearson_p'])}. 보조 Spearman={fmt(z['spearman_rho'],6)}입니다.

## 회귀
시계={fmt(z['intercept'],6)}+{fmt(z['slope'],6)}×ECG, R²={fmt(z['r_squared'],6)}. 기울기 CI[{fmt(z['slope_ci_low'])},{fmt(z['slope_ci_high'])}]. 평균반응 CI는 개인 예측·일치한계와 다릅니다.

## 오차
평균={fmt(z['bias'],6)}, SD={fmt(z['error_sd'],6)}, MAE={fmt(z['mae'],6)}, RMSE={fmt(z['rmse'],6)}bpm. 고정LoA[{fmt(z['classical_loa_low'],3)},{fmt(z['classical_loa_high'],3)}]bpm. MPE={fmt(z['mpe'],3)}%, MAPE={fmt(z['mape'],3)}%.

## 진단과 민감도
최대 절대오차 ID{z['max_abs_error_id']}, 최대Cook거리 ID{z['max_cooks_id']}. 이 참가자를 주 분석에서 삭제하지 않았습니다. 한 명씩 제외하는 보조 r 범위는[{fmt(l['loo_r_min'])},{fmt(l['loo_r_max'])}]입니다. 범위는 신뢰구간이 아닙니다.

## 출력과 해석 범위
모든 값은 analysis/runs/{run_id}/tables에서 추적됩니다. 그림은 최종HTML에 내장됐습니다. 기기별22명의 평균값 관계를 기술하며 임상적 교환 가능성·현재 모델 성능·활동별 정확도를 입증하지 않습니다.
'''
 rel='docs/devices/'+short[name]+'.md';write(root/rel,content);mds[rel]=content

prompt='''# 6주차 실행 프롬프트: 범위·정의·검토 비용 보강

1. 작업 루트는 사용자가 지정한 6주차 절대경로 하나로 고정한다. 프로젝트 내부는 상대경로를 사용한다.
2. 공식 논문·공개 원자료 Key·수정 슬라이드에서 관측 단위·단위·짝·trial·열·집계 수준을 점검한 후 통계를 시작한다.
3. 확인 사실, 분석자 선택, 공개되지 않은 정보를 구분한다. 없는 HR 시계열·활동별 값을 생성하지 않는다.
4. 필수는 Pearson·단순회귀·오차·지정그림이며, 명시된 보조 진단만 수행한다. EE·ICC·하위집단 검색으로 범위를 늘리지 않는다.
5. 전체88쌍을 사용한다. 결측·제외·변환·축약 여부와 원본 행·셀을 기록한다. 주 결과에서 outlier를 임의 제거하지 않는다.
6. 각 작업은 하나의 질문·입력·산출물·종료 조건을 가진다. 결과보다 유리한 수치나 작은p를 종료 기준으로 쓰지 않는다.
7. 현재 계획과 결과는 config 및 run 보고서가 정본이다. MD·HTML은 결과 CSV에서 생성한다.
8. 원자료는 해시를 보존한다. 새 분석은 새runID에 쓰고 기존run은 덮어쓰지 않는다.
9. R readxl/cor/lm과 기본 그래픽으로 분석한다. Python 보조는uv를 사용하며 별도 수식으로 대조한다.
10. 자료/코드 변경은 영향받는 수치·그림을, 주장 변경은 해당 문구를, 서식 변경은 화면만 확인한다.
11. 소스/도구 출력은 필요한 요약만 반환하고 전체 대화 복제·불필요한 재검토를 피한다. 벽시계 시간은 기록하되 제공되지 않은토큰·요금을 추정하지 않는다.
12. 주 분석의 수학적 검산과 언어 간 대조를 외부·맹검·독립 에이전트 심사라고 부르지 않는다.
13. 중간 과정은 단계별·기기별MD로 유지한다. 최종 사용자 보고서는 그림·표·전체88행·문제·제약이 내장된HTML 한 개로 만든다.
'''
write(root/'analysis/config/실행프롬프트-6주차.md',prompt)

css='''
:root{--bg:#f4f6f4;--white:#fff;--ink:#18303c;--muted:#5b6c74;--line:#dce4e1;--teal:#176b69;--soft:#e8f1ed;--orange:#9c5c26}*{box-sizing:border-box}html{scroll-behavior:smooth;scroll-padding-top:24px}body{margin:0;background:var(--bg);color:var(--ink);font:15px/1.85 "Malgun Gothic","Apple SD Gothic Neo",system-ui,sans-serif}a{color:var(--teal);text-underline-offset:3px;overflow-wrap:anywhere}button,select,input{font:inherit}button:focus-visible,a:focus-visible,summary:focus-visible,select:focus-visible,input:focus-visible{outline:3px solid #b97b41;outline-offset:3px}.skip{position:absolute;top:-70px;left:15px;padding:12px;background:white;z-index:5}.skip:focus{top:8px}header{max-width:1400px;margin:auto;padding:23px 35px;border-bottom:1px solid var(--line);display:flex;justify-content:space-between;gap:15px;font-size:12px}.brand{font-weight:800;letter-spacing:.08em}.shell{max-width:1400px;margin:auto;display:grid;grid-template-columns:190px minmax(0,1fr);gap:44px;padding:35px 35px 80px}.sidebar{position:sticky;top:22px;align-self:start}.sidebar p{font-size:11px;color:var(--muted);font-weight:700;letter-spacing:.1em}.sidebar nav{display:flex;flex-direction:column;gap:5px}.sidebar a{font-size:12px;text-decoration:none;color:var(--ink);padding:9px 0;border-bottom:1px solid var(--line)}.sidebar a span{color:var(--teal);margin-right:9px;font-weight:800}.sidebar small{display:block;margin-top:22px;color:var(--muted);font-size:11px}.hero{padding:8px 0 38px}.eyebrow{color:var(--teal);font-size:11px;font-weight:800;letter-spacing:.12em}h1{font-size:clamp(30px,3.4vw,47px);line-height:1.3;letter-spacing:-.045em;word-break:keep-all;margin:12px 0 23px}h1 em{font-style:normal;color:var(--teal)}.intro{font-size:17px;color:#3e525c;max-width:820px}.facts{display:grid;grid-template-columns:repeat(4,minmax(0,1fr));gap:12px;margin:27px 0}.fact{background:white;border-top:3px solid var(--teal);padding:17px}.fact strong{display:block;font-size:29px;line-height:1.3;font-variant-numeric:tabular-nums}.fact small{font-size:11px;color:var(--muted)}.meta{color:var(--muted);font-size:12px}.section{border-top:1px solid var(--line);padding:36px 0}.section-head{display:flex;gap:15px;margin-bottom:22px}.section-no{font-size:30px;line-height:1.5;font-weight:800;color:#8ea5a0}.section h2{font-size:26px;line-height:1.4;letter-spacing:-.035em;margin:0 0 9px}.section-head p{margin:0;color:var(--muted)}h3{font-size:17px;line-height:1.55;letter-spacing:-.02em;margin:0 0 10px}p{margin:12px 0}.callout{background:var(--soft);border-left:4px solid var(--teal);padding:18px 22px;margin:20px 0}.callout.warn{background:#fbefe3;border-color:#b98248}.callout p{margin:5px 0}.table-wrap{overflow:auto;border:1px solid var(--line);background:white;border-radius:5px;margin:20px 0}table{border-collapse:collapse;width:100%;font-size:12px;text-align:left;line-height:1.75}th{background:#eaf0ec;font-size:11px;color:#3c555d;padding:12px 13px;white-space:nowrap}td{padding:13px;border-top:1px solid var(--line);vertical-align:top}td:first-child{font-weight:700}.table-wrap table{min-width:620px}.table-wrap.long{max-height:530px}.table-wrap.long th{position:sticky;top:0;z-index:1}.grid2{display:grid;grid-template-columns:1fr 1fr;gap:16px}.panel{background:white;border:1px solid var(--line);border-radius:5px;padding:22px}.panel ul{padding-left:20px}.mini{font-size:12px;color:var(--muted)}.formula{padding:15px;background:#eef1ee;font-family:Consolas,ui-monospace,monospace;font-size:13px;border-radius:4px;overflow-wrap:anywhere}.flow{display:flex;flex-wrap:wrap;align-items:center;gap:8px;margin:22px 0;font-size:12px}.flow span{padding:9px 12px;background:#e5efea;border:1px solid #c7d9d0;border-radius:4px}.flow i{font-style:normal;color:var(--teal)}figure{margin:23px 0;padding:20px;background:white;border:1px solid var(--line);border-radius:6px}figure img{display:block;width:100%;height:auto;margin-top:17px}figcaption p{font-size:12px;color:var(--muted);margin:0}.pill{font-size:10px;font-weight:800;padding:3px 8px;border-radius:4px;background:#e0eee8;color:#27685a}.pill.partial{background:#f9e8d6;color:#8f511e}.device-cards{display:grid;grid-template-columns:repeat(2,1fr);gap:13px}.device-card{border-top:3px solid var(--teal)}.device-card dl{display:grid;grid-template-columns:1fr 1fr;gap:10px;margin:14px 0 0}.device-card dt{font-size:10px;color:var(--muted)}.device-card dd{font-size:19px;font-weight:700;margin:0;font-variant-numeric:tabular-nums}.actions{display:flex;align-items:center;flex-wrap:wrap;gap:10px;margin:16px 0}.btn{background:white;border:1px solid #b8cdc4;color:var(--teal);padding:8px 13px;font-size:12px;border-radius:4px;cursor:pointer}.btn:hover{background:#e5eeea}select{padding:7px;background:white;border:1px solid #b8cdc4;border-radius:4px;font-size:12px}.issue{background:white;border:1px solid var(--line);border-radius:5px;margin:10px 0;padding:0 18px}.issue summary{cursor:pointer;padding:15px 0;font-weight:700;font-size:13px}.issue summary span{font-size:10px;color:var(--teal);margin-right:8px}.issue .issuebody{padding-bottom:15px;font-size:12px;color:#425a63}.issuebody p{margin:8px 0}.note-list{padding-left:20px}.note-list li{margin:10px 0}.demo{border:1px solid var(--line);background:white;padding:22px;border-radius:5px;margin:22px 0}.demo-controls{display:grid;grid-template-columns:1fr 1fr;gap:20px}.demo label{display:block;font-size:12px}.demo input{width:100%;accent-color:var(--teal)}.demo-output{font-size:14px;color:var(--teal);font-weight:700}.demo svg{display:block;width:100%;max-height:300px;margin-top:10px;background:#fafcf9}.method-map li{margin:10px 0}.downloads{display:grid;grid-template-columns:1fr 1fr;gap:8px}.downloads a{font-size:12px}.foot{font-size:11px;color:var(--muted);border-top:1px solid var(--line);padding-top:25px;margin-top:20px}code{font-size:12px;overflow-wrap:anywhere}.logpre{white-space:pre-wrap;overflow-wrap:anywhere;font:11px/1.8 Consolas,monospace;max-height:460px;overflow:auto;background:#f1f4ef;padding:14px}.raw-count{font-size:12px;color:var(--muted)}@media(max-width:1050px){.shell{grid-template-columns:150px minmax(0,1fr);gap:27px;padding-left:23px;padding-right:23px}header{padding-left:23px;padding-right:23px}.facts{gap:8px}.fact{padding:13px}.fact strong{font-size:25px}}@media(max-width:760px){header{display:block;padding:16px 18px}header .meta{display:block;margin-top:6px;font-size:10px}.shell{display:block;padding:20px 18px 50px}.sidebar{position:static;margin-bottom:22px}.sidebar nav{flex-direction:row;flex-wrap:wrap;gap:6px}.sidebar a{border:1px solid var(--line);padding:3px 7px;font-size:10px;border-radius:4px}.sidebar a span{margin-right:4px}.sidebar small{display:none}.hero{padding-bottom:24px}.intro{font-size:15px}.facts{grid-template-columns:1fr 1fr;gap:8px}.fact strong{font-size:24px}.fact small{font-size:10px}.section{padding:28px 0}.section h2{font-size:23px}.section-head{gap:10px}.grid2,.device-cards,.demo-controls,.downloads{grid-template-columns:1fr}.section-no{font-size:25px}figure{padding:12px}.callout{padding:16px}.table-wrap table{min-width:610px}.demo{padding:15px}}@media(prefers-reduced-motion:reduce){html{scroll-behavior:auto}}@media print{body{background:white;font-size:10pt}header{padding:0 0 10pt}.shell{display:block;padding:12pt 0}.sidebar,.actions,.demo-controls,.skip{display:none}.hero{padding:0 0 15pt}h1{font-size:25pt}.facts{grid-template-columns:repeat(4,1fr)}.fact{padding:10pt}.section{padding:18pt 0}.section h2{font-size:17pt}.section-head{margin-bottom:12pt}.table-wrap,.table-wrap.long{overflow:visible;max-height:none}table{font-size:8pt}.table-wrap table{min-width:0}figure,.panel,.issue,.callout{break-inside:avoid}details:not([open])>.issuebody{display:block}.logpre{max-height:none;overflow:visible}.downloads{display:none}.raw-hidden{display:table-row!important}.foot{font-size:8pt}}
'''
nav=[('summary','01','결과 요약'),('data','02','자료와 정리'),('association','03','상관·회귀'),('error','04','오차·일치도'),('diagnostics','05','진단·민감도'),('publication','06','논문 비교'),('problems','07','문제·수정·한계'),('records','08','전체 자료·기록')]
def heading(n,title,text):return f'<div class="section-head"><span class="section-no">{n}</span><div><h2>{title}</h2><p>{text}</p></div></div>'
body='<a href="#main" class="skip">본문 바로가기</a><header><span class="brand">WEEK 06 / HEART RATE MEASUREMENT</span><span class="meta">의생명과학프로그래밍 · Wallen et al. (2016) · 분석일 2026.10.24</span></header><div class="shell"><aside class="sidebar"><p>분석 읽기 순서</p><nav aria-label="보고서 목차">'+''.join(f'<a href="#{id}"><span>{n}</span>{t}</a>' for id,n,t in nav)+'</nav><small>최종 결과·그림·88쌍 전체 자료가 이 HTML 안에 들어 있습니다.<br>과정은 별도 MD로도 보존합니다.</small></aside><main id="main">'
body+='''<div class="hero"><p class="eyebrow">상관 · 단순 선형회귀 · 측정 오차</p><h1>심박수 시계는<br><em>ECG와 얼마나 함께 변하고,<br>얼마나 다르게 측정하는가</em></h1><p class="intro">공개된 참가자별 평균 심박수 자료를 전부 사용했습니다. 상관계수와 회귀선으로 두 측정의 관계를 보고, 같은 자료의 평균오차·절대오차·분포를 통해 일치 정도를 따로 확인했습니다.</p><div class="facts"><div class="fact"><strong>22명</strong><small>서로 다른 참가자</small></div><div class="fact"><strong>88쌍</strong><small>4기기 × 참가자별 22쌍</small></div><div class="fact"><strong>0쌍</strong><small>주 분석 제외·축소·대체</small></div><div class="fact"><strong>7개</strong><small>원본 R 분석 그림 내장</small></div></div><p class="meta">자료: <a href="https://doi.org/10.1371/journal.pone.0154420.s001">PLOS 공개 S1 XLSX</a> · 논문: <a href="https://doi.org/10.1371/journal.pone.0154420">Accuracy of Heart Rate Watches</a> · <a href="https://slides.pnucolab.com/9eGiQnmVQB7D">수정 슬라이드</a></p></div>'''
body+='<section class="section" id="summary">'+heading('01','상관이 높아도 오차는 작지 않을 수 있습니다','같은 사람의 해당 기기·trial ECG와 시계 값을 짝지었습니다. 기기별 n=22이며 88명을 분석한 것이 아닙니다.')
body+=table(T,mainrows)
body+=f'''<div class="callout"><p><strong>Fitbit의 예:</strong> Pearson r={fmt(S['Fitbit Charge HR']['pearson_r'])}으로 양의 상관이 있지만, 평균오차는 {fmt(S['Fitbit Charge HR']['bias'],2)}bpm이고 평균 절대오차는 {fmt(S['Fitbit Charge HR']['mae'],2)}bpm입니다. 두 값이 같이 커지는 정도와 같은 값을 내는 정도는 다릅니다.</p></div><div class="grid2"><div class="panel"><h3>이번 자료에서 관측한 것</h3><p>네 기기 모두 표본 평균오차가 음수였습니다. 평균값 기준 MAE는 Apple {fmt(S['Apple Watch']['mae'],2)}, Mio {fmt(S['Mio Alpha']['mae'],2)}, Samsung {fmt(S['Samsung Gear S']['mae'],2)}, Fitbit {fmt(S['Fitbit Charge HR']['mae'],2)}bpm입니다.</p><p class="mini">이는 이 표본의 기술적 비교입니다. 기기 간 독립표본 우열 검정을 수행한 결과가 아닙니다.</p></div><div class="panel"><h3>공개 자료가 답할 수 있는 범위</h3><p>참가자별 protocol 평균의 상관·회귀·오차를 분석했습니다. 15초 시계열·활동별 HR이 없어 순간오차, 운동 종류별 정확도, 시간 지연을 추정할 수 없습니다.</p><p class="mini">기본 분석값은 평균자료 88쌍 전부입니다. 이 분석자가 시계열을 평균내거나 일부 표본을 뽑아 축소하지 않았습니다.</p></div></div>'''
body+='</section><section class="section" id="data">'+heading('02','원자료에서 88쌍이 만들어지는 과정','계산 전에 자료 단위·열·짝·trial·단위·결측을 확인했습니다. 원본 내용은 수정하지 않았습니다.')
body+='''<div class="flow"><span>원본 XLSX 6개 시트 보존</span><i>→</i><span>Heart_Rate 22개 행</span><i>→</i><span>기기별 블록 4개</span><i>→</i><span>88쌍 long 자료</span><i>→</i><span>기기별 n=22 분석</span></div>'''
body+=table(['기기','시계 값','동시 ECG','Trial'],[['Apple Watch','B열','C열','D열'],['Fitbit Charge HR','E열','F열','G열'],['Samsung Gear S','H열','I열','J열'],['Mio Alpha','K열','L열','M열']])
body+='''<div class="callout warn"><strong>발견한 열 이름 문제</strong><p>Heart_Rate의 F1은 <code>Fitbit_metamax</code>라고 적혀 있습니다. 그러나 같은 파일 Key의 Worksheet_4는 이를 Fitbit 착용 중 ECG 심박수(bpm)로 정의합니다. 이 근거로 F열을 ECG 기준값에 매핑하고, 원래 열 이름·셀 주소를 분석 자료에 남겼습니다.</p></div>'''
body+=table(['검사','결과','의미'],[['ID·기기별 인원','ID1~22 · 기기별22쌍','중복 참가자·누락 없음'],['참가자×trial 짝','44그룹, 각2기기','동일trial의 기준 ECG 값 일치'],['유효값·결측','88쌍 유한한 양수 · 결측0','값 대체나 탈락 없음'],['원본 내용','SHA256 전후 동일','읽기 전후 XLSX 내용 보존'],['검산','R28개 · Python402개 통과','동일 에이전트의 수식·언어 간 대조']])
first=next(x for x in pairs if x['device']=='Apple Watch' and x['participant_id']=='1')
body+=f'''<article class="panel"><h3>한 행의 변환 예: 참가자1 · Apple</h3><p>B2={first['device_bpm']}bpm, C2={first['reference_bpm']}bpm, D2=trial{first['trial']} → 오차={fmt(first['error_bpm'],2)}bpm입니다. 같은 방법으로 88쌍 전부를 처리했습니다.</p><p class="mini">다른 시트의 활동별 VO₂ 행을 HR 활동 데이터로 대체하거나 임의 결합하지 않았습니다. EE·걸음 수는 결과변수가 달라 이번 심박수 과제 범위에서 분석하지 않았고 원본에는 보존됩니다.</p></article></section>'''

body+='<section class="section" id="association">'+heading('03','상관과 회귀선은 무엇을 설명하나','x는 동시 ECG 평균, y는 시계 평균입니다. 회귀선과 y=x를 함께 읽습니다.')
body+='<div class="formula">Pearson r = Sxy / √(Sxx × Syy)<br>시계 예측 평균 = 절편 a + 기울기 b × ECG<br>b = Sxy / Sxx, a = 시계 평균 − b × ECG 평균<br>절편이 있는 단순회귀에서는 R² = r²</div>'
body+=fig('01_scatter_regression.png','전체 자료 산점도·회귀선·동일값 기준선','각 패널은22명 전부입니다. 검은 점선은 y=x, 색 선은 OLS, 음영은 평균반응95%CI입니다. 음영을 개인 예측구간이나 일치한계로 읽지 않습니다. 최대 절대오차 ID를 표시했지만 삭제하지 않았습니다.')
body+=table(R,regrows)
body+='''<div class="callout"><p><strong>회귀와 일치:</strong> 기울기·절편은 관측 범위의 평균적 관계를 기술합니다. 회귀선이 자료에 잘 맞더라도 y=x에서 멀면 측정값은 다릅니다. R²는 측정 정확도의 백분율이나 외부 예측 성능이 아닙니다.</p></div><div class="demo"><h3>가상 예제로 확인: r=1이어도 오차가 생깁니다</h3><p class="mini">아래는 실제 참가자 자료와 분리된 원리 설명입니다. ECG가70·90·110·130인 가상4명에서 시계=k×ECG+c를 계산합니다. 양의k에서는 직선 상관이1이어도 편향이 생깁니다.</p><div class="demo-controls"><label>배율 k: <output id="scale-out">1.00</output><input id="demo-scale" type="range" min="0.6" max="1.4" step="0.01" value="1"></label><label>고정 오차 c: <output id="offset-out">10</output>bpm<input id="demo-offset" type="range" min="-20" max="20" step="1" value="10"></label></div><p class="demo-output" id="demo-output"></p><svg id="demo-svg" viewBox="0 0 500 280" role="img" aria-label="가상 네 점의 회귀선과 y=x"></svg><button class="btn" type="button" id="demo-reset">k=1, c=10 예제로 복원</button></div></section>'''

body+='<section class="section" id="error">'+heading('04','평균오차·오차 크기·분포를 함께 봅니다','오차는 시계−ECG입니다. 음수는 과소추정이고, 양수는 과대추정입니다.')
body+='<div class="formula">평균오차 = mean(e) · MAE = mean(|e|) · RMSE = √mean(e²)<br>고정 Bland–Altman LoA = mean(e) ± 1.96 × SD(e)<br>평균오차의95% t CI와 개별 차이의 LoA는 서로 다릅니다.</div>'
body+=fig('02_error_histograms.png','기기별 오차 히스토그램','모든 기기에서 같은5bpm 구간과 같은 축을 사용했습니다. 검은 점선0과 색 실선 평균오차를 비교합니다. 양·음 오차가 상쇄될 수 있어 평균오차만으로 정확도를 판정하지 않습니다.')
body+=fig('07_bias_and_mae.png','오차 방향과 크기','왼쪽은 평균오차와 점별95% t CI, 오른쪽은 MAE입니다. 신뢰구간이0을 포함한다는 사실은 개별 측정값의 일치나 임상적 교환 가능성을 증명하지 않습니다.')
body+=table(E,errrows)
body+=fig('03_bland_altman.png','차이 대 두 측정 평균','가로축은 (시계+ECG)/2, 세로축은 시계−ECG입니다. 색 실선은 평균오차, 붉은 점선은 고정LoA, 색 점선은 오차~평균 진단선입니다. 고정LoA는 기술적 보조 분석으로 원문의 회귀 가변LoA와 구별합니다.')
body+='<p class="mini">MAPE는 개인별 절대 상대오차의 평균입니다. 논문의 다른 백분율 요약과 정의를 대조하지 않고 직접 같다고 해석하지 않습니다. LoA는 연구의 분포 요약이며 이번 과제에서 정한 임상 허용 기준은 없습니다.</p></section>'

body+='<section class="section" id="diagnostics">'+heading('05','큰 오차는 보존하고 영향만 따로 확인했습니다','주 분석은88쌍을 유지합니다. 보조 진단에서 한 명을 제외할 때마다 결과가 얼마나 바뀌는지 확인했습니다.')
body+=fig('04_regression_residuals.png','회귀 잔차 대 적합값','직선 주위에 구조·분산 차이가 보이는지 읽습니다. 표기한 ID는 Cook 거리가 가장 큰 참가자이며 자동 제외 기준으로 사용하지 않았습니다.')
body+=fig('05_residual_qq.png','잔차 Q-Q 진단','정규분포에서의 이탈과 꼬리를 점검합니다. 작은 표본의 진단 p값 하나로 분석법을 바꾸거나 문제가 없다고 확정하지 않습니다.')
body+=table(['기기','한 명씩 제외 r 범위','기울기 범위','r 변화가 가장 큰 ID'],sensrows)
body+=fig('06_leave_one_out.png','한 명씩 제외하는 민감도','선은22개 제외 시나리오의 최소~최대이고 점은 전체22명 결과입니다. 이 범위는 신뢰구간이 아니며, 기기별21명 결과를 최종 주 분석으로 선택하지 않았습니다. 88개의 보조 적합은 holdout 예측 검증을 뜻하지 않습니다.')
body+='</section><section class="section" id="publication">'+heading('06','원문과의 차이를 통계 종류와 계산 과정으로 설명합니다','확인할 수 있는 심박수 Table1 일부를 비교했습니다. 논문 전체를 완전히 재현했다고 주장하지 않습니다.')
pubr=[]
for z in summary:
 c=next(x for x in comparison if x['device']==z['device'] and x['metric']=='paper_method_correlation')
 pubr.append([z['device'],fmt(z['pearson_r'],6),c['method'],fmt(c['published'],2),fmt(c['calculated'],6),'허용오차 내' if c['within_rounding']=='True' else '차이'])
body+=table(['기기','과제 Pearson','원문 종류','원문 값','같은 종류 계산','판정'],pubr)
body+='''<div class="callout"><strong>Samsung 0.743과0.67은 통계 종류가 다릅니다.</strong><p>원문 Table1의 별표는 Spearman을 뜻합니다. 원문 방식 상관4개는 반올림 허용오차0.005 안에서 맞습니다. 과제에서 요구한 Pearson은 모든 기기에 그대로 보고하고, 더 가까운 값을 얻으려고 분석법을 교체하지 않았습니다.</p></div>'''
nonmatch=[x for x in comparison if x['within_rounding']=='False']
body+=f'<p>N·평균·SD·원문 방식 상관·세 기기의 고정LoA 등 총38개 필드 중33개가 명시한 반올림 허용오차 안에 있습니다. n·r·평균 기준은 실행 전 계획에 고정했고, SD·LoA의0.05는 표 추출 후1자리 표기 정밀도에 적용했습니다. 개별 차이는 아래와 같으며 이 개수를 정확도의 점수로 읽지 않습니다.</p>'
body+=table(['기기','비교 항목','원문','직접 계산','차이'],[[x['device'],x['metric'],x['published'],fmt(x['calculated'],6),fmt(x['delta'],6)] for x in nonmatch])
body+='''<div class="grid2"><div class="panel"><h3>작은 차이: 반올림과 양립하는 설명</h3><p>인쇄된1자리 평균오차·SD를 LoA 식에 대입하면 세 기기의 고정LoA6개가 출판값0.05 이내로 나옵니다. 이는 사후 설명 점검이며, 저자의 원래 계산 순서를 입증하지는 않습니다. 직접 계산한 주 결과와 원본 값은 유지했습니다.</p></div><div class="panel"><h3>방법 차이: Mio의 가변 일치한계</h3><p>원문은 상한 −0.44×평균+52.69, 하한0.4×평균−61.2를 제시합니다. 평균 크기에 따라 달라지는 식을 이번 고정LoA와 같은 결과로 비교할 수 없습니다.</p></div></div><p class="mini">상관·요약치 재현은 확인됐지만 반올림·일치한계의 세부 차이는 남습니다. ICC·에너지 소비·걸음 수 재현과는 구분됩니다.</p></section>'''

body+='<section class="section" id="problems">'+heading('07','문제·수정·남은 한계를 한곳에 모았습니다','자료의 제한, 코드·환경 문제, 통계 해석 문제를 구분합니다. 펼치면 각 항목의 조치와 현재 상태를 볼 수 있습니다.')
body+='<div class="actions"><button class="btn" id="open-all" type="button">문제 설명 모두 펼치기</button><button class="btn" id="close-all" type="button">모두 접기</button></div>'
ko={
'D01':('원자료가 이미 참가자별 평균이다','공개 HR 시트에는 활동·시각 열이 없습니다. 15초 자료를 임의 생성하지 않고 평균값88쌍 전부를 사용했습니다. 집계 수준 아래의 순간오차는 남는 한계입니다.'),
'D02':('Fitbit 기준열 이름과 설명이 다르다','F1의 Fitbit_metamax 표기를 그대로 칼로리로 해석하면 단위·기준을 잘못 짝지을 수 있습니다. Key의 Worksheet_4와 논문방법 근거로 ECG bpm에 매핑하고 원본은 보존했습니다.'),
'D03':('Trial_number가 네 번 반복된다','자동 이름 변경을 믿지 않고 원래 헤더와 B–D/E–G/H–J/K–M 위치를 확인했습니다. 기기마다 동시trial 기준값을 사용했습니다.'),
'D04':('성별 코드가 Key와 시트에서 다르다','Demographics 표기는1/2, Key는0/1입니다. 이번 HR 분석에 성별을 사용하지 않았으며 임의 수정하지 않았습니다. 범위 밖 메타데이터 문제로 남깁니다.'),
'D05':('Key의 Integer 표기와 실제 소수값','심박수 평균에는 소수가 있습니다. 원자료의 소수와 전체 정밀도를 유지하고 통계를 위한 정수 변환·사전 반올림을 하지 않았습니다.'),
'S01':('88쌍은88명이 아니다','기기별22명 분석을 수행했습니다. 기기 간 같은 사람이 반복되므로 합친88행을 독립 사람으로 취급한 p값이나 독립표본 우열 검정을 만들지 않았습니다.'),
'S02':('상관이 높으면 일치도 높은가','고정 오차·배율 차이가 있어도 r는 높을 수 있습니다. y=x, 평균오차, MAE, RMSE, 히스토그램과LoA를 함께 해석했습니다.'),
'S03':('고정LoA와 회귀 가변LoA는 다르다','이번 고정LoA는 보조 기술치입니다. 원문의 Mio 회귀 가변 식을 완전히 재현했다고 표현하지 않습니다. 크기에 따른 분산 변화·비정규성과 평균 집계의 한계가 남습니다.'),
'S04':('큰 오차 참가자를 삭제할 것인가','소스에 근거한 제외 사유가 없어88쌍 전부 유지했습니다. 한 명씩 제외한 별도 민감도만 보존했고 더 높은 r를 주 결과로 선택하지 않았습니다.'),
'S05':('OLS가 보정 성능·참값을 증명하는가','OLS는 기준x를 주어진 값으로 두는 기술 모형입니다. ECG 측정오차, 작은 표본, 외부 자료 부재를 고려해야 합니다. 적합R²·LOO민감도를 실제 미래 예측 성능으로 주장하지 않습니다.'),
'E01':('readxl 패키지 준비','초기에는 readxl이 없어 프로젝트 전용R라이브러리에1.6.0을 설치했습니다. 환경 버전과 실제 실행을 기록했고 전역 패키지를 변경하지 않았습니다.'),
'E02':('DOI·슬라이드의 최초 웹 읽기 실패','공식 출판사 데이터 endpoint와 공개 슬라이드 직접 다운로드로 확보했습니다. 원본 byte·SHA256·영구 출처를 보존했습니다.'),
'E03':('OpenPyXL 확장 경고','읽기 도구가 저장 시 Excel 확장을 보존하지 못한다는 경고입니다. 읽기 전용으로만 사용하고 원본을 재저장하지 않았으며 내용 해시가 같음을 확인했습니다.'),
'E04':('보조 검사 경로를 잘못 선택했다','폴더 이름 끝부분 검색이 다른 프로그래밍 폴더를 선택해 읽기 실패했습니다. 명시한 절대경로로 교정했고 R 주 분석 전에 해결했습니다. 이 실패로 값이 수정되지는 않았습니다.'),
'C01':('Samsung 원문은 Spearman이다','원문 각주를 확인해0.67의 종류를 구분했습니다. 보조 Spearman0.670243을 비교하되 주Pearson0.742585는 유지했습니다.'),
'C02':('원문과 작은 요약치·LoA 차이','삼성 평균오차와 일부 고정LoA가 허용오차 밖입니다. 인쇄된 평균오차·SD를 사용한 반올림 호환 점검은 별도로 기록했습니다. 원값을 조정하지 않았고 원래 정밀도·계산 과정은 미확인입니다.'),
'C03':('Mio 일치한계가 평균의 함수다','논문에 기울기가 있는 상·하한 방정식이 있습니다. 상수LoA와의 직접 일치 판정은 하지 않습니다. 과제 범위의 기술 분석과 저자 전체 방법 재현은 다릅니다.')}
localized_issue_md='# 문제와 수정 내역\n\n'+pre+'## 발견·조치·남은 범위\n\n'+mdtable(['ID','문제','확인과 조치','기록 상태'],[[z['id'],ko[z['id']][0],ko[z['id']][1],z['status']] for z in issues])+'\n## 실행 이력\n\n통계 실행 R1-20261024는 성공했습니다. 초기 소스 읽기·경로 검사 실패와 readxl 준비는 통계 실행 전의 문제였고, 원자료나 결과를 바꾸지 않았습니다. 주 분석의 제외·축소·대체는0입니다.\n'
localized_issue_md+='\n## 화면·내보내기 확인 중 수정\n\n진단 그림의 기기 제목·축 숫자와 일부 참가자 표식이 잘리는 문제를 발견했습니다. STYLE1은 저장된 잔차 CSV를 그대로 다시 그려 표시만 수정한 것으로 통계 재적합은0회입니다. 원래 run의 그림·수치는 보존했습니다. 다운로드 CSV의 초기 동일성 검사는 LF/CRLF 줄바꿈 차이로 실패했으나, 줄바꿈을 정규화하면88행의 모든 텍스트가 일치했습니다. 데이터 값 변경은 없었습니다.\n'
write(root/'docs/09-문제와수정내역.md',localized_issue_md);mds['docs/09-문제와수정내역.md']=localized_issue_md
for z in issues:
 title,text=ko[z['id']]
 body+=f'<details class="issue"><summary><span>{z["id"]}</span>{title}</summary><div class="issuebody"><p>{text}</p><p class="mini">기록 상태: {e(z["status"])}</p></div></details>'
body+='''<div class="callout warn"><strong>최종 해석의 범위</strong><p>이 자료는 소수 참가자의 실험실 평균자료입니다. 평균이 순간오차를 가릴 수 있으며, 현재 판매 제품·질환자·일상생활·활동별 정확도로 일반화할 수 없습니다. 임상 허용 기준이나 인과효과·외부 예측 성능을 확정한 분석도 아닙니다.</p></div><p class="mini">검산은 동일 에이전트가 수행한 R 수식 점검과 Python 교차 계산입니다. 별도 사람·외부 표본·맹검 심사를 했다고 표시하지 않습니다.</p></section>'''

body+='<section class="section" id="records">'+heading('08','전체88쌍과 단계별 기록','자료를 임의로 줄이지 않았는지 원래 셀·ID·trial·오차로 확인할 수 있습니다. 아래 필터는 표시만 바꾸고 분석값을 바꾸지 않습니다.')
body+='<div class="actions"><label for="device-filter">자료 표시:</label><select id="device-filter"><option value="all">전체4기기</option>'+''.join('<option value="'+e(x)+'">'+e(x)+'</option>' for x in device_names)+'</select><span class="raw-count" id="raw-count">88 / 88쌍</span><button class="btn" id="download-csv" type="button">전체88쌍 CSV 저장</button></div>'
rawheaders=['ID','기기','Trial','ECG bpm','시계 bpm','오차 bpm','기준 셀','시계 셀']
body+='<div class="table-wrap long"><table id="raw-table"><thead><tr>'+''.join('<th>'+x+'</th>' for x in rawheaders)+'</tr></thead><tbody>'
for z in pairs:
 body+='<tr data-device="'+e(z['device'])+'">'+''.join('<td>'+e(x)+'</td>' for x in [z['participant_id'],z['device'],z['trial'],fmt(z['reference_bpm'],2),fmt(z['device_bpm'],2),fmt(z['error_bpm'],2),z['reference_cell'],z['device_cell']])+'</tr>'
body+='</tbody></table></div><h3>각 기기의 과정 MD</h3><div class="device-cards">'
for name,z in S.items():
 body+=f'<article class="panel device-card"><h3>{name}</h3><dl><div><dt>전체 Pearson</dt><dd>{fmt(z["pearson_r"])}</dd></div><div><dt>평균오차 bpm</dt><dd>{fmt(z["bias"],2)}</dd></div><div><dt>MAE bpm</dt><dd>{fmt(z["mae"],2)}</dd></div><div><dt>유지한 자료</dt><dd>22 / 22쌍</dd></div></dl><p class="mini">원래 셀→상관→회귀→오차→진단→한계가 기기별MD에 연결됩니다.</p>'+link('docs/devices/'+short[name]+'.md','기기별 MD 열기')+'</article>'
body+='</div><h3 style="margin-top:25px">중간 기록14개</h3><p class="mini">각 MD는 아래에서 파일 하나씩 저장할 수도 있습니다. 제목을 펼치면 이 HTML 안에서도 원문을 확인할 수 있어 별도 파일이 없어도 과정을 읽을 수 있습니다.</p>'
for rel,text in mds.items():
 data=base64.b64encode(text.encode()).decode();title=text.splitlines()[0].lstrip('# ')
 body+=f'<details class="issue md-record"><summary>{e(title)}</summary><div class="issuebody"><a download="{e(Path(rel).name)}" href="data:text/markdown;base64,{data}">이 MD 저장</a><pre class="logpre">{e(text)}</pre></div></details>'
body+='<div class="panel" style="margin-top:22px"><h3>재실행과 검증 범위</h3><p>Rscript로 <code>analysis/src/analyse_heart_rate.R</code>에 프로젝트 루트와 새runID를 전달합니다. 원자료·기존run은 덮어쓰지 않습니다. Python 보조 코드는uv로 실행합니다.</p><p class="mini">자료 정의→CSV→그림→MD→HTML을 같은 자료 버전에 연결했습니다. 새 자료·코드 변경과 서식 변경의 확인 범위를 구분합니다. CSV·모형·환경·출처·해시·실패/경고 기록은 analysis와sources에 보존됩니다.</p></div><div class="actions"><button type="button" class="btn" id="print-report">인쇄 / PDF 저장</button></div></section>'
body+=f'<footer class="foot"><p>작성·분석일2026-10-24 · run {run_id} · 자료 버전 <code>{e(plan["data_version"])}</code></p><p>원본 XLSX SHA256: <code>{e(plan["raw_sha256"])}</code></p><p>출처: Wallen et al. (2016), PLOS ONE11(5):e0154420. <a href="https://doi.org/10.1371/journal.pone.0154420">논문</a> · <a href="https://doi.org/10.1371/journal.pone.0154420.s001">S1 Dataset</a> · <a href="https://slides.pnucolab.com/9eGiQnmVQB7D">수정 슬라이드</a>. 공개 논문·데이터의 저작자와 출처를 표시하며 분석 그림은 본 과제에서 생성했습니다.</p><p>R 실행 {result["elapsed_seconds"]:.2f}초 · 수학·자료 확인28개 · Python 교차 확인402개. 이 개수는 서로 다른 검사항목 수이고 참가자 수·과학적 타당성 점수가 아닙니다. 모델 토큰·요금 기록은 제공되지 않았습니다.</p></footer></main></div>'
csv_text=(run/'tables/heart_rate_pairs.csv').read_text(encoding='utf-8-sig')
js='''
const issueDetails=()=>document.querySelectorAll('details.issue:not(.md-record)');
document.querySelector('#open-all').addEventListener('click',()=>issueDetails().forEach(x=>x.open=true));document.querySelector('#close-all').addEventListener('click',()=>issueDetails().forEach(x=>x.open=false));
const filter=document.querySelector('#device-filter');filter.addEventListener('change',()=>{let n=0;document.querySelectorAll('#raw-table tbody tr').forEach(row=>{const show=filter.value==='all'||row.dataset.device===filter.value;row.hidden=!show;if(show)n++});document.querySelector('#raw-count').textContent=n+' / 88쌍 (표시만 변경)'});
document.querySelector('#download-csv').addEventListener('click',()=>{const a=document.createElement('a');const url=URL.createObjectURL(new Blob(['\\ufeff'+CSV_TEXT],{type:'text/csv;charset=utf-8'}));a.href=url;a.download='heart_rate_all_88_pairs.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000)});
const svg=document.querySelector('#demo-svg');const scale=document.querySelector('#demo-scale');const offset=document.querySelector('#demo-offset');
function drawDemo(){const k=+scale.value,c=+offset.value,x=[70,90,110,130],y=x.map(v=>k*v+c),errors=y.map((v,i)=>v-x[i]);const bias=errors.reduce((a,b)=>a+b,0)/4,mae=errors.reduce((a,b)=>a+Math.abs(b),0)/4;document.querySelector('#scale-out').textContent=k.toFixed(2);document.querySelector('#offset-out').textContent=c.toFixed(0);document.querySelector('#demo-output').textContent='가상 r = 1.000 · 평균오차 '+bias.toFixed(2)+'bpm · MAE '+mae.toFixed(2)+'bpm';const X=v=>45+v/200*405,Y=v=>235-v/200*210;svg.innerHTML='<line x1="45" y1="235" x2="450" y2="235" stroke="#789"/><line x1="45" y1="235" x2="45" y2="20" stroke="#789"/><line x1="'+X(0)+'" y1="'+Y(0)+'" x2="'+X(190)+'" y2="'+Y(190)+'" stroke="#888" stroke-dasharray="6 5"/><line x1="'+X(60)+'" y1="'+Y(60*k+c)+'" x2="'+X(140)+'" y2="'+Y(140*k+c)+'" stroke="#176b69" stroke-width="2.5"/>'+x.map((v,i)=>'<circle cx="'+X(v)+'" cy="'+Y(y[i])+'" r="5" fill="#176b69"/>').join('')+'<text x="205" y="265" font-size="12" fill="#526770">가상 ECG (bpm)</text><text x="58" y="22" font-size="12" fill="#526770">가상 시계 (bpm)</text><text x="315" y="45" font-size="11" fill="#526770">회색 점선 y=x</text>';}
scale.addEventListener('input',drawDemo);offset.addEventListener('input',drawDemo);document.querySelector('#demo-reset').addEventListener('click',()=>{scale.value=1;offset.value=10;drawDemo()});drawDemo();
let printState=[];window.addEventListener('beforeprint',()=>{printState=[...document.querySelectorAll('details')].map(x=>[x,x.open]);printState.forEach(([x])=>x.open=true);document.querySelectorAll('#raw-table tbody tr').forEach(x=>x.classList.add('raw-hidden'))});window.addEventListener('afterprint',()=>{printState.forEach(([x,open])=>x.open=open);document.querySelectorAll('#raw-table tbody tr').forEach(x=>x.classList.remove('raw-hidden'))});document.querySelector('#print-report').addEventListener('click',()=>window.print());
'''
js='const CSV_TEXT='+json.dumps(csv_text,ensure_ascii=False)+';\n'+js
report='<!doctype html><html lang="ko"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta name="description" content="Wallen 공개 자료의 22명 88쌍으로 수행한 Pearson 상관·단순 회귀·측정 오차 분석의 과정과 결과"><title>6주차 최종 분석 보고서 — 심박수 시계의 상관·회귀·측정 오차</title><style>'+css+'</style></head><body>'+body+'<script>'+js+'</script></body></html>'
final=root/'최종분석보고서.html';write(final,report)
readme='''# 6주차: 상관·단순 선형회귀·측정 오차

[최종 분석 보고서 HTML](최종분석보고서.html)을 브라우저로 여세요. 필요한 그림7개, 전체88쌍, 결과와 해석, 문제·수정·한계, 중간MD14개를 파일 안에 내장했습니다. 최종 보고서 HTML은 한 개입니다.

- `data/raw`: 공개 XLSX 원본. 변경하지 않습니다.
- `docs`: 단계별10개·기기별4개 MD. 각 질문의 입력→방법→결과→검토→남은 한계를 보존합니다.
- `analysis/config`: 실행 전 고정한 계획·자료 정의·보강 프롬프트.
- `analysis/src`: R 통계와Python 보조·검산·문서 생성 코드.
- `analysis/runs/R1-20261024`: CSV, 모형, 그림, 수식검사, Python 교차검사, 원문 비교, 환경과경고.
- `analysis/memory`: 현재 상태와 발견 문제의 정본.
- `sources`: 원문·수정 슬라이드·표 추출·원본해시. 원본페이지는 최종HTML과 구별해source.txt에 보관합니다.

현재 참가자는22명·기기별22쌍이며 총88쌍입니다. 원자료의HR가 참가자별평균이므로15초·활동별 분석을 생성하지 않았습니다. 주 분석 제외·축소·대체는0입니다. 큰 오차를 유지하고 한 명씩제외하는 별도민감도만 수행했습니다.

## 재실행

R4.6.1, readxl1.6.0, jsonlite, digest를 사용합니다. 프로젝트의analysis/r-library를 먼저참조합니다. 아래는프로젝트루트에서 새runID로 실행하는예입니다.

```powershell
$taskRscript='C:\\Program Files\\R\\R-4.6.1\\bin\\Rscript.exe'
& $taskRscript 'analysis/src/analyse_heart_rate.R' '.' 'R-new-run'
uv run 'analysis/src/crosscheck_and_source.py' '.' 'R-new-run'
uv run 'analysis/src/compare_publication.py' '.' 'R-new-run'
uv run 'analysis/src/build_report.py' '.' 'R-new-run'
```

Python 보조는 numpy와 openpyxl이 있는 환경에서 uv로 실행합니다. 원자료는 불변이며 기존 run ID를 덮어쓰지 않습니다. 보고서는 지정한 run의 CSV에서 읽어 HTML 한 파일을 갱신하므로, 여러 run이 있으면 자료 버전을 확인하세요. 출처 원본과 분석 단계 변경의 검토 범위를 기록합니다.

자체수식검사와언어간대조를했으며외부심사는아닙니다. 원문삼성상관0.67은Spearman이고과제Pearson0.743과구별합니다. 원문의일부반올림·가변LoA는정확재현주장을제한합니다.
'''
write(root/'README.md',readme)
state=load(root/'analysis/memory/project.json');state.update(status='statistics, cross-check, source comparison and MD/HTML built; browser QA pending',current_run=run_id,docs_count=len(mds),html=final.name,updated_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),review_scope='same-agent R/Python mathematical cross-check; no external independent review');jwrite(root/'analysis/memory/project.json',state)
with (root/'analysis/memory/events.jsonl').open('a',encoding='utf-8') as f:f.write(json.dumps({'time_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'stage':'report-build','run_id':run_id,'md_files':len(mds),'html':final.name},ensure_ascii=False)+'\n')
jwrite(root/'analysis/report_manifest.json',{'html':final.name,'html_sha256':sha(final),'run_id':run_id,'data_version':plan['data_version'],'raw_sha256':plan['raw_sha256'],'images':[{'file':plotpath(p.name).relative_to(root).as_posix(),'sha256':sha(plotpath(p.name))} for p in sorted((run/'figures').glob('*.png'))],'markdown':[{'file':rel,'sha256':sha(root/rel)} for rel in mds],'n_pairs':88,'n_people':22,'primary_exclusions':0,'review_scope':'same-agent formula and cross-language comparison','paper_comparison':compare})
print(json.dumps({'html':str(final),'bytes':final.stat().st_size,'md_files':len(mds),'embedded_figures':7,'all_pairs':88,'issues':len(issues)},ensure_ascii=False))
