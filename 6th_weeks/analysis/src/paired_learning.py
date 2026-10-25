"""Restore the concept/paper learning contract without changing statistical artifacts."""
from pathlib import Path
import re, html, json, hashlib

def plain(value):
    value=re.sub(r'<br\s*/?>','\n',value)
    value=re.sub(r'</(?:p|div|h3|h4|tr|figure|li)>','\n',value)
    return html.unescape(re.sub('<[^>]+>','',value)).strip()

def md_html(text):
    """Small deterministic renderer for authored prose; tables use the report renderer."""
    def inline(s):
        s=html.escape(s)
        s=re.sub(r'`([^`]+)`',r'<code>\1</code>',s)
        s=re.sub(r'\*\*([^*]+)\*\*',r'<strong>\1</strong>',s)
        return s
    out=[]
    for block in text.strip().split('\n\n'):
        if block.startswith('### '):out.append('<h4>'+inline(block[4:])+'</h4>')
        elif block.startswith('## '):out.append('<h3>'+inline(block[3:])+'</h3>')
        else:out.append('<p>'+inline(block).replace('\n','<br>')+'</p>')
    return ''.join(out)

def restore_pairs(root,body,mds,c):
    table,fmt,mdtable=c['table'],c['fmt'],c['mdtable']
    S,summary,run_id=c['S'],c['summary'],c['run_id']
    # Reuse actual result markup, including embedded figures, rather than recalculating.
    def extract(id):
        m=re.search(r'<section class="section" id="'+id+r'">(.*?)</section>',body,re.S)
        assert m,id
        inner=m.group(1)
        split=inner.index('</p></div></div>')+len('</p></div></div>')
        return inner[split:]
    data=extract('data');association=extract('association');error=extract('error')
    diagnostics=extract('diagnostics');publication=extract('publication');problems=extract('problems')
    figure=re.search(r'<figure>.*?</figure>',association,re.S).group()
    demo=re.search(r'<div class="demo">.*?</svg><button.*?</button></div>',association,re.S).group()
    regression=re.search(r'<div class="table-wrap">.*?</table></div>',association,re.S).group()
    error=re.sub(r'^<div class="formula">.*?</div>','',error,flags=re.S)

    stages=[
      dict(id='data',code='HR01',title='자료·변수·관측 단위',issues=['D01','D02','D03','D04','D05','S01'],deps=[],
        input='공개 XLSX의 Heart_Rate·Key·논문 Methods',output='전체 88쌍 long 자료, 원본 셀·ID·trial 매핑',
        source='S1 Dataset: Heart_Rate A1:M23, Key Worksheet_4; paper Methods / Experimental protocol',figures=[],
        concept='''## 입력 → 질문

입력은 측정값과 코드북입니다. 계산 전에 “한 행은 누구의 어떤 시점·조건을 나타내며, 두 열은 같은 대상을 측정했는가?”를 묻습니다. 연속형 변수는 값의 크기와 차이에 의미가 있고, ID·기기명·trial은 관측을 구분하는 표지입니다.

## 방법과 이유: 단위·짝·독립성

측정 단위(예: bpm), 관측 단위(사람·사람×기기·사람×시점), 집계 수준(순간값·개인 평균)을 별도로 적습니다. 같은 사람의 두 측정은 짝을 이루고, 한 사람에게서 나온 여러 행은 서로 독립이라고 자동으로 가정할 수 없습니다.

wide→long 변환은 가로로 있던 기기별 열을 세로로 옮기는 구조 변경입니다. 값과 짝을 유지하면 그 자체가 표본 축소나 평균내기는 아닙니다. 반면 평균으로 집계하면 원래의 시간 변동 정보가 사라집니다.

## 최소 공식과 작은 계산 — 가상 예제

가상으로 3명에게 기기 2개를 측정하면 자료는 3×2=6행입니다. 기기마다 분석할 사람은 3명이고, 전체 행 수 6을 독립된 사람 수로 바꿀 수는 없습니다. 원래 값 80.4를 정수 80으로 바꾸는 일은 단순한 자료 배치 변경과도 다릅니다.

## 가정·대안이 답하는 질문

짝이 맞지 않으면 오차·상관 모두 다른 질문에 답합니다. 여러 시점의 변화를 묻는다면 시계열이나 반복측정 모형이 필요하고, 사람별 평균의 관계만 묻는다면 평균 자료가 직접 입력입니다. 결측은 누락 이유와 분모를 확인한 뒤 처리합니다.

## 출력 → 남은 질문

출력은 변수 사전, 한 행의 정의, 짝 매핑, 포함·제외·변환 내역입니다. 원래의 시간·활동 자료가 공개되지 않았다면 그 수준의 분석은 미확인으로 남깁니다.''',
        paper='''## 입력 → 이번 질문

논문은 건강한 참가자의 소비자용 시계를 ECG 기준과 비교합니다. 이번 입력은 S1의 Heart_Rate와 Key입니다. “공개된 참가자별 평균 심박수에서 시계와 해당 trial ECG의 관계·차이가 어떠한가?”로 과제 범위를 고정했습니다.

## 논문 원문·공개 자료에서 확인한 사실

공개 HR 시트는 22명의 protocol 평균입니다. 기기별 시계·ECG·trial 블록이 네 개이고, 15초 HR 시계열이나 활동별 HR 열은 없습니다. 논문의 세밀한 측정 절차와 공개 파일의 집계 수준을 구분했습니다.

## 이번 구현의 선택과 이유

원래 열 위치를 고정해 기기별 동시 ECG와 짝지었습니다. F1의 Fitbit_metamax는 Key Worksheet_4에서 ECG bpm으로 정의되어 그 근거로 매핑했습니다. ID·원래 헤더·행·셀·trial을 남겼으며 소수 정밀도를 유지했습니다. 22×4=88쌍을 모두 사용했고 제외·대체·추가 축약은 0입니다.

## 출력·검토 결과

아래 열 매핑과 실제 참가자 1의 변환은 공개 파일에 근거한 적용 예입니다. 가상 예제가 아닙니다. 원본 SHA256과 R·Python 대조는 자료·계산의 무결성 확인 범위이며 통계적 타당성 전체의 증명은 아닙니다.

## 남은 의문과 다음 단계

D01–D05·S01을 연결했습니다. 공개되지 않은 시간·활동 HR과 성별 코드 모순은 임의로 보완하지 않았습니다. 다음에는 이 관측 단위에서 산점도와 상관을 읽습니다.''',paper_html=data,
        result_md=mdtable(['기기','시계','동시 ECG','trial'],[['Apple Watch','B','C','D'],['Fitbit Charge HR','E','F','G'],['Samsung Gear S','H','I','J'],['Mio Alpha','K','L','M']])+'\n실제 결과: 22명, 기기별 22쌍, 총 88쌍; 주 분석 제외·대체·추가 축약 0. 원본 Heart_Rate 행 2–23.\n',files=['tables/heart_rate_pairs.csv']),

      dict(id='association',code='HR02',title='산점도·Pearson 상관',issues=['S01','S02','C01'],deps=['HR01'],
        input='기기별 동일 참가자의 ECG·시계 평균 22쌍',output='산점도, Pearson r·95%CI; 원문 대조용 Spearman 별도',
        source='paper Statistical analysis and Table 1 footnote; S1 Heart_Rate',figures=['01_scatter_regression.png'],
        concept='''## 입력 → 질문

입력은 같은 관측 대상에서 얻은 연속형 x·y의 짝입니다. 산점도의 점 하나는 한 관측쌍이며, x·y축의 단위와 동일값 기준선 y=x를 먼저 확인합니다. 산점도는 관계의 방향·직선성·곡선·변동·큰 영향점을 보여 줍니다. Pearson r의 질문은 “두 값이 얼마나 강하게 직선 관계로 함께 변하는가?”입니다.

## 방법과 이유: 산점도와 표준화

`Sxx=Σ(x−x̄)²`, `Syy=Σ(y−ȳ)²`, `Sxy=Σ(x−x̄)(y−ȳ)`로 두면 `r=Sxy/√(Sxx·Syy)`입니다. r은 −1~1의 단위 없는 수이며, 부호는 방향, 절댓값은 직선 관계의 정도입니다. 한 변수가 상수이면 분모가 0이므로 r은 정의되지 않습니다.

## 최소 공식과 작은 계산 — 가상 예제

가상 x=(60,80,100), y=(70,90,110)이면 편차가 각각 (−20,0,20)입니다. Sxx=Syy=Sxy=800이므로 r=1입니다. 그러나 각 측정차 y−x는 모두 +10입니다. 아래 조작 예제도 가상 자료이며, 상관과 일치가 서로 다른 질문임을 보여 줍니다.

## 가정·불확실성·대안

표본 r 계산 자체와 모집단에 대한 CI·검정의 조건을 구분합니다. 일반적인 Pearson 검정·Fisher z CI는 독립적인 쌍과 적절한 분포 조건을 전제로 해석합니다. r은 효과 크기, CI는 추정의 불확실성, p값은 귀무가설(모상관=0)과 검정 모형 아래에서 관측값 이상으로 극단적인 결과가 나올 확률에 관한 값입니다. 작은 p가 큰 관계나 좋은 일치를 뜻하지 않습니다. 극단값·범위 제한·비선형성에 민감하고, 작은 표본에서 불확실성이 큽니다. r이 0이라고 비선형 관계가 없다는 뜻은 아닙니다.

Spearman은 순위의 단조 관계를 묻습니다. Pearson과 추정 대상이 달라 원문 숫자에 더 가깝다는 이유로 교체하지 않습니다. 원인·예측 성능·측정 일치는 상관만으로 결론 내리지 않습니다.

## 출력 → 남은 질문

산점도와 r·분모·CI를 함께 보고합니다. 직선 관계가 있어도 실제 값 차이는 얼마나 큰지, 기울기·절편은 어떠한지는 별도 단계에서 확인합니다.''',
        paper='''## 입력 → 이번 질문

기기마다 x=동시 trial ECG의 참가자 평균, y=해당 시계의 참가자 평균으로 두고 22쌍을 사용했습니다. 네 기기를 합친 88행에서 독립표본 상관 검정을 수행하지 않았습니다.

## 논문 원문에서 사용한 분석

원문은 Pearson 또는 Spearman 상관을 사용합니다. Table 1 각주상 Samsung의 0.67은 Spearman입니다. 이 구분 없이 과제 Pearson과 직접 비교하면 불일치 원인을 잘못 설명하게 됩니다.

## 이번 구현의 선택과 이유

수정된 과제가 요구하는 Pearson을 네 기기 모두에 계산하고, Fisher z 방식 95%CI와 산점도를 보고했습니다. Spearman은 원문과 같은 종류의 수치를 대조하는 보조 값입니다. 산점도의 회귀선·동일값 선은 다음 회귀·오차 단계에서도 함께 읽습니다.

## 출력·검토 결과

아래는 실제 22명에서 계산한 값입니다. 모두 양의 상관이지만 상관 크기만으로 시계가 ECG와 같은 값을 낸다고 판단하지 않습니다. Samsung의 과제 Pearson은 약 0.743, 원문과 비교한 보조 Spearman은 약 0.670입니다.

## 남은 의문과 다음 단계

S01·S02·C01에 연결됩니다. 평균 집계가 개인 내 변동을 가릴 수 있고 표본 범위가 제한됩니다. 직선 관계를 원래 bpm 단위에서 기술하는 OLS는 다음 단계, 실제 차이의 크기는 오차 단계에서 다룹니다.''',
        paper_html=figure+table(['기기','n','Pearson r','95%CI','원문 대조용 Spearman'],[[z['device'],z['n'],fmt(z['pearson_r']),f"{fmt(z['r_ci_low'])} ~ {fmt(z['r_ci_high'])}",fmt(z['spearman_rho'])] for z in summary]),
        result_md=mdtable(['기기','n','Pearson r','95%CI'],[[z['device'],z['n'],fmt(z['pearson_r'],6),f"{fmt(z['r_ci_low'],6)} ~ {fmt(z['r_ci_high'],6)}"] for z in summary]),files=['tables/device_summary.csv']),

      dict(id='regression',code='HR03',title='단순 선형회귀',issues=['S02','S05'],deps=['HR01'],
        input='기기별 ECG x·시계 y의 22쌍',output='시계~ECG 절편·기울기·CI·R²·잔차',
        source='course extension: device~ECG OLS; distinguish paper Statistical analysis / Bland–Altman regression',figures=['01_scatter_regression.png'],
        concept='''## 입력 → 질문

입력은 연속형 x·y의 짝입니다. 단순회귀는 “x가 주어질 때 y의 평균이 어떻게 변하는가?”를 원래 측정 단위로 기술합니다. 상관이 단위 없는 관계의 정도라면 기울기는 x 1단위 증가에 따른 평균 y 변화입니다.

## 방법과 이유: 최소제곱

`yᵢ=a+b·xᵢ+εᵢ`, `ŷᵢ=a+b·xᵢ`, `잔차 uᵢ=yᵢ−ŷᵢ`입니다. OLS는 잔차 제곱합을 작게 하며 `b=Sxy/Sxx`, `a=ȳ−b·x̄`입니다. 잔차는 회귀선에서 벗어난 정도이고, 측정오차 y−x와 구별합니다.

## 최소 공식과 작은 계산 — 가상 예제

가상 x=(1,2,3), y=(2,2,5)에서 x̄=2, ȳ=3, Sxx=2, Sxy=3입니다. 따라서 b=1.5, a=0이고 적합값은 (1.5,3,4.5), 잔차는 (0.5,−1,0.5)입니다. 잔차 제곱합 1.5, y의 총제곱합 6이므로 R²=1−1.5/6=0.75입니다. 이것은 측정값 75%가 정확하다는 뜻이 아닙니다.

## 가정·CI·대안이 답하는 질문

일반적인 계수 CI는 선형 평균 관계, 독립 오차, 등분산과 작은 표본에서의 정규 오차 조건을 점검하며 해석합니다. OLS 계수의 적합 자체에는 오차의 정규성이 필요하지 않습니다. x는 주어진 기준으로 취급하므로 양쪽 측정오차가 중요한 질문에는 다른 접근이 필요할 수 있습니다.

평균반응 CI는 회귀선 평균의 불확실성입니다. 새 개인의 예측구간은 잔차 변동도 포함하고, 두 방법 차이의 LoA와도 다릅니다. x·y를 바꾸면 회귀식은 일반적으로 역수가 되지 않습니다. 보정·미래 예측을 주장하려면 사용 방향과 별도 평가가 필요합니다.

## 출력 → 남은 질문

회귀식·계수 CI·R²·관측 범위·잔차를 보고합니다. 절편 있는 단순 OLS에서는 R²=r²이지만 두 지표가 다른 정보를 독립적으로 검증한 것은 아닙니다. 다음에는 동일값 기준 y=x에서 얼마나 벗어나는지 확인합니다.''',
        paper='''## 입력 → 이번 질문

이번 과제는 각 시계 평균을 y, 동시 ECG 평균을 x로 둔 단순 OLS를 기기마다 적합했습니다. 질문은 관측 범위에서의 평균적 관계입니다. ECG를 시계로부터 예측하는 외부 보정 성능을 평가한 분석은 아닙니다.

## 논문 방법과 이번 과제의 구분

원문도 회귀를 사용하지만 차이·일치한계를 두 측정의 평균과 연결하는 Bland–Altman 회귀 맥락입니다. 여기의 시계~ECG 단순 OLS, 계수 CI·적합 R²는 과제 구현입니다. 이 결과를 원문의 동일 회귀계수 재현이라고 쓰지 않습니다.

## 이번 구현의 선택과 이유

R lm으로 절편을 포함해 22명 모두 적합했습니다. 산점도에는 OLS와 y=x, 평균반응 95%CI를 함께 그렸습니다. R²=r²를 수식 검산했으며 평균반응 음영을 개인 예측구간으로 해석하지 않았습니다.

## 출력·검토 결과

아래 실제 회귀식은 ECG가 100bpm일 때의 적합 평균도 보여 줍니다. 적합도가 높아도 y=x와 차이가 있으면 측정값의 일치는 별도로 확인해야 합니다. 회귀선 그림은 직전 산점도 패널과 공유합니다.

## 남은 의문과 다음 단계

S02·S05에 연결됩니다. ECG도 완전한 무오차 참값이라고 입증한 것은 아니며 작은 표본·공유 참가자·외부 평가 부재가 남습니다. 잔차 진단은 후속 보조 단계이고, 수치가 좋아지도록 표본을 삭제하지 않았습니다.''',
        paper_html='<p><a href="#association">앞 단계의 전체 산점도·OLS·y=x 그림 보기</a></p>'+regression,
        result_md=mdtable(c['R'],c['regrows']),files=['tables/device_summary.csv','tables/observation_diagnostics.csv']),

      dict(id='error',code='HR04',title='측정오차·일치도',issues=['S02','S03','C03'],deps=['HR01'],
        input='동일 대상의 시계 y·ECG x; 차이 e=y−x',output='bias·MAE·RMSE·SD·평균오차 CI·고정 LoA와 그림',
        source='paper Statistical analysis, Table 1, Figure 2; S1 Heart_Rate',figures=['02_error_histograms.png','07_bias_and_mae.png','03_bland_altman.png'],
        concept='''## 입력 → 질문

입력은 동일 대상의 두 측정값입니다. “차이가 어느 방향이며 평균적으로 얼마나 크고, 개별 차이가 얼마나 퍼지는가?”를 묻습니다. 오차의 부호를 먼저 정해야 과소·과대 추정의 뜻이 일관됩니다.

## 방법과 이유: 방향·크기·분포

`e=y−x`, `bias=mean(e)`, `MAE=mean(|e|)`, `RMSE=√mean(e²)`입니다. bias는 방향, MAE는 상쇄 없는 크기, RMSE는 제곱으로 큰 차이에 더 무게를 주는 크기입니다. 히스토그램은 비대칭·꼬리·큰 오차를 보여 줍니다.

## 최소 공식과 작은 계산 — 가상 예제

가상 오차 (−2,0,+2)이면 bias=0이지만 MAE=4/3≈1.33, RMSE=√(8/3)≈1.63입니다. 따라서 평균오차 0은 모든 측정이 같다는 뜻이 아닙니다. 이 세 숫자는 원리 설명용이며 실제 참가자 결과가 아닙니다.

## Bland–Altman과 불확실성

차이를 세로축, 두 측정의 평균 (x+y)/2를 가로축으로 놓습니다. 차이가 대략 정규이고 측정 크기 전반에서 분포가 안정적이면 고정 일치한계는 `bias±1.96·SD(e)`로 추정합니다. 이는 평균 차이의 CI가 아닙니다. 추정된 LoA 자체도 표본 불확실성이 있으며, 모든 미래 차이가 반드시 안에 든다는 보장은 없습니다.

## 가정·대안이 답하는 질문

측정 크기에 따라 차이·분산이 달라지면 고정 LoA 해석이 제한됩니다. 변환이나 회귀에 따른 가변 한계는 그 다른 구조를 다루지만 동일한 숫자로 비교할 수는 없습니다. 임상적 허용 범위는 통계에서 자동으로 생기지 않으므로 별도의 사용 목적·기준이 필요합니다.

## 출력 → 남은 질문

bias·MAE·RMSE와 차이 분포·LoA를 함께 보고합니다. 평균오차 CI가 0을 포함해도 동등성·교환 가능성이 증명되는 것은 아닙니다. 평균 집계 이전의 순간 오차도 이 지표만으로 복원할 수 없습니다.''',
        paper='''## 입력 → 이번 질문

이번 계산은 시계−ECG를 오차로 고정했습니다. 네 기기에 대해 22쌍씩 bias·MAE·RMSE·오차 SD·평균오차 t CI·MAPE와 고정 Bland–Altman LoA를 계산했습니다. 음수는 이 정의에서 과소추정입니다.

## 논문 방법과 이번 구현의 구분

원문은 Bland–Altman 일치도를 다룹니다. 특히 Mio의 상·하한은 평균 크기의 함수로 제시되어 있습니다. 이번 고정 LoA·MAE·RMSE·공통 구간 히스토그램은 과제의 기술·보조 분석이며 원문의 가변 한계까지 완전히 재현한 결과가 아닙니다.

## 출력·검토 결과

아래 실제 결과에서 네 기기의 표본 bias는 음수였습니다. Apple도 bias가 비교적 작다는 사실만으로 순간 측정이나 임상 사용에서 오차가 없다고 할 수 없습니다. 같은 축의 오차 분포와 차이 대 평균 그림을 함께 확인합니다.

## 남은 의문과 다음 단계

S02·S03·C03에 연결됩니다. 집계된 평균의 오차이고 임상 허용 기준은 정하지 않았습니다. 고정 LoA의 분포 가정과 크기 의존성은 진단을 통해 제한을 점검하되 불확실성이 해소되었다고 단정하지 않습니다.''',paper_html=error,
        result_md=mdtable(c['T'],c['mainrows'])+'\n'+mdtable(c['E'],c['errrows']),files=['tables/device_summary.csv','tables/heart_rate_pairs.csv']),

      dict(id='diagnostics',code='HR05',title='진단·영향점·민감도',issues=['S03','S04','S05'],deps=['HR01','HR03','HR04'],
        input='전체 자료의 OLS·저장된 잔차·한 명씩 제외한 별도 시나리오',output='잔차·Q–Q·Cook 진단, LOO 범위와 전체 결과의 비교',
        source='analyst supplemental diagnostics; frozen R1 tables and STYLE1 rendering manifest',figures=['04_regression_residuals.png','05_residual_qq.png','06_leave_one_out.png'],
        concept='''## 입력 → 질문

입력은 적합한 모형과 관측별 잔차입니다. “선형·분산 가정에 어긋나는 구조가 있는가, 한 사람이 결론을 크게 움직이는가?”를 묻습니다. 결과가 마음에 드는지를 평가하는 절차와 구분합니다.

## 방법과 이유

잔차 대 적합값에서는 곡선·깔때기 모양·군집을, Q–Q에서는 정규 모형 대비 꼬리·비대칭을 봅니다. 이상치는 큰 잔차, 높은 leverage는 특이한 x 위치, 영향점은 추정값을 크게 움직이는 관측입니다. Cook 거리는 영향의 한 지표이며 자동 삭제 명령이 아닙니다.

## 최소 공식과 작은 계산 — 가상 예제

가상 값 (4,6,8,22)의 전체 평균은 10입니다. 22를 제외하면 (4+6+8)/3=6입니다. 한 관측이 평균에 영향을 준다는 설명이지 22가 오류이거나 삭제해야 한다는 증거는 아닙니다.

## 가정·대안·민감도의 범위

한 명씩 제외해 관심 통계량을 다시 구하면 특정 관측 의존성을 볼 수 있습니다. 이 최솟값~최댓값은 CI가 아니며, 제외한 사람의 미래 예측 오차를 평가하지 않았다면 예측 교차검증 점수도 아닙니다. 작은 표본에서 정규성 p값 하나로 가정을 확정하거나 방법을 자동 교체하지 않습니다.

## 출력 → 남은 질문

전체 분석과 별도 민감도를 나란히 보고합니다. 오류 확인·설계 근거가 있어 자료를 바꾼 경우에만 새 버전과 하류 결과를 갱신합니다. 영향 확인만으로 표본을 선별하거나 성능 향상을 주장하지 않습니다.''',
        paper='''## 입력 → 이번 질문

이번 잔차·Q–Q·Cook·한 명씩 제외하는 분석은 과제의 추가 진단입니다. 원문에서 동일한 진단 결과를 보고했다고 주장하지 않습니다. 주 분석 22명씩은 그대로 두고 관측 하나에 대한 민감도를 확인했습니다.

## 이번 구현의 선택과 이유

기기별 22개 제외 시나리오, 총 88개 보조 적합에서 상관·기울기 등의 범위를 저장했습니다. 더 높은 r를 만드는 시나리오를 최종 결과로 고르지 않았습니다. 오차~두 측정 평균 진단선도 크기 의존성을 살피는 보조 요약입니다.

## 출력·검토 결과

아래 범위와 그림은 실제 저장된 전체·제외 시나리오 결과입니다. STYLE1의 축·기기명·ID 표시 수정은 같은 잔차 CSV를 다시 그린 서식 수정이며 통계 재적합은 없었습니다. 수치와 최초 그림은 run 안에 보존됩니다.

## 남은 의문과 다음 단계

S03–S05에 연결됩니다. 작은 표본의 진단은 정규성·등분산·외부 예측을 입증하지 못합니다. 원문과의 차이는 다음 단계에서 같은 정의·통계 종류인지 먼저 대조합니다.''',paper_html=diagnostics,
        result_md=mdtable(['기기','한 명씩 제외 r 범위','기울기 범위','가장 큰 r 변화 ID'],c['sensrows']),files=['tables/observation_diagnostics.csv','tables/sensitivity_summary.csv']),

      dict(id='publication',code='HR06',title='논문 수치 대조·해석',issues=['C01','C02','C03'],deps=['HR01','HR02','HR03','HR04'],
        input='원문 Table 1·각주·Figure 2와 같은 정의의 계산 결과',output='같은 종류 상관 4개 일치, 일부 요약치 차이·미확인 사유',
        source='paper Table 1, Figure 2, Statistical analysis; sources/published_tables.json',figures=[],
        concept='''## 입력 → 질문

입력은 출판값과 직접 계산값입니다. “같은 자료·대상·정의·통계·단위의 값을 비교하는가, 차이는 어디에서 생기는가?”를 먼저 묻습니다. 숫자가 가깝다는 사실과 원래 구현을 확인했다는 사실은 다릅니다.

## 방법과 이유: 비교 계약

분모·선정·변환·부호·상관 종류·CI와 한계의 종류를 맞춥니다. `Δ=계산값−출판값`, `|Δ|≤허용오차`로 판정하되 허용오차의 근거와 정한 시점을 적습니다. 결과를 본 뒤 만든 설명은 사후 점검으로 표시합니다.

## 최소 공식과 작은 계산 — 가상 예제

가상 원값 98.246을 소수 첫째 자리까지 인쇄하면 98.2입니다. 직접 계산값과의 차이 0.046은 0.05 이내입니다. 반올림과 양립하지만 계산 과정이 같았다는 증명은 아닙니다. 다른 통계량끼리는 우연히 숫자가 같아도 재현 일치로 세지 않습니다.

## 가정·대안이 답하는 질문

차이가 나면 자료 버전·분모·정의·반올림·코드를 확인합니다. 미공개 설정은 미확인으로 남길 수 있습니다. 수치 재현 검토는 “원문 결과와 맞는가?”, 타당성 검토는 “질문·자료에 방법과 해석이 적절한가?”라는 별개 질문입니다.

## 출력 → 남은 질문

같은 정의의 비교표, 일치·차이·비교 불가의 이유, 확인한 범위를 남깁니다. 출판 숫자에 가까워지도록 원값이나 주 방법을 바꾸지 않습니다. 일부 수치 일치는 논문 전체·임상 효용·분석 타당성 전체의 증명이 아닙니다.''',
        paper='''## 입력 → 이번 질문

공식 원문 Table 1과 Figure 2를 고정된 R1 결과와 대조했습니다. 이번 비교 범위는 공개 HR 요약치 일부이며 ICC·에너지 소비·걸음 수와 논문 전체의 재현이 아닙니다.

## 논문 원문과 직접 계산의 구분

Samsung 원문의 0.67은 Spearman입니다. 같은 종류로 대조하면 상관 4개는 허용오차 0.005 이내입니다. 과제 Pearson 0.743은 그대로 유지했습니다. Mio의 원문 가변 LoA는 이번 상수 LoA와 직접 동등 판정하지 않았습니다.

## 이번 비교 선택과 결과

n·r·평균의 허용오차는 실행 전 계획에 있었고, SD·LoA의 0.05는 원문 표 추출 후 소수 첫째 자리 정밀도에 적용했습니다. 38개 필드 중 33개가 각 허용오차 이내이며 이 비율을 정확도 점수로 해석하지 않습니다.

## 남은 의문

C01–C03에 연결됩니다. 인쇄된 bias·SD를 대입한 고정 LoA 6개가 원문과 양립하는지는 사후 설명 점검입니다. 저자의 실제 반올림 순서는 미확인이고 원자료 계산값은 수정하지 않았습니다.''',paper_html=publication,
        result_md='원문 방식 상관 4/4 허용오차 내; 직접 비교 38필드 중 33 허용오차 내.\n\n'+mdtable(['기기','항목','원문','계산','차이'],[[z['device'],z['metric'],z['published'],fmt(z['calculated'],6),fmt(z['delta'],6)] for z in c['nonmatch']]),files=['tables/publication_comparison.csv','tables/reported_rounding_diagnostic.csv']),

      dict(id='problems',code='HR07',title='문제·검증·보고의 한계',issues=[z['id'] for z in c['issues']],deps=['HR01','HR02','HR03','HR04','HR05','HR06'],
        input='단계별 문제 ID·실행·검산·출처·결과·변경 기록',output='해결한 문제와 미확인 한계, 통합 설명 및 추적 기록',
        source='analysis/memory/issues.json; run/status.json and cross-check outputs; user correction 2026-10-24',figures=[],
        concept='''## 입력 → 질문

입력은 분석의 자료·실행·근거·변경 기록입니다. “어떤 문제가 있었고, 무엇을 수정했으며, 결론은 어디까지 뒷받침되는가?”를 묻습니다. 소프트웨어 실행 성공, 수치 검산, 통계적 타당성, 임상 적용 가능성은 서로 다른 확인 범위입니다.

## 방법과 이유: 문제와 변경을 연결

문제를 자료 정의·환경/코드·방법/해석·출판 비교로 구분합니다. ID마다 발견 근거, 조치, 영향받는 산출물, 해결 여부와 남은 의문을 남깁니다. 새 자료·선정·코드가 수치를 바꾸면 하류 표·그림·해석을 갱신하고, 문구·서식만 바꾸면 해당 설명·화면을 검토합니다.

## 최소 공식과 작은 계산 — 가상 예제

가상으로 입력 1,000행에서 중복 20행을 제외했다면 분석 분모는 980행입니다. 보고서는 `입력−제외=사용`을 설명하고 이전 1,000행 결과와 섞지 않아야 합니다. 이 수치는 설명용이며 이번 연구의 제외 내역이 아닙니다.

## 가정·대안이 답하는 질문

해시 일치는 파일 무결성, 별도 수식 대조는 계산 일관성에 관한 근거입니다. 독립된 검토자·새 표본·맹검 평가를 수행했는지는 별도로 기록합니다. 미확인을 실행 실패와 섞지 않으며 유의하지 않음도 실패로 부르지 않습니다.

## 출력 → 남은 질문

완료·미확인·적용 범위가 명확한 보고서가 출력입니다. 일반 개념과 특정 논문 적용을 짝지어 학습하되 같은 HTML에 담는 것은 전달 형식의 선택입니다. 관측 결과에서 직접 나오지 않는 인과·미래 예측·임상 우열은 추가 증거가 필요한 질문으로 남깁니다.''',
        paper='''## 입력 → 이번 질문

이번 프로젝트의 자료·통계·환경·원문 비교 문제 17개를 아래에 모았습니다. 각 학습 단계에도 해당 ID를 연결해 “개념 설명→실제 적용→의문→확인→업데이트된 해석”을 따라갈 수 있게 했습니다.

## 이번 수정의 범위

사용자의 요청에 따라 기존 concept/paper 학습 구조를 복원했습니다. 원본 XLSX, R1 통계·그림·CSV와 모든 실패·중간 기록은 유지합니다. 이번 변경은 설명·MD·HTML·문서 등록부의 갱신이며 통계 모형을 다시 적합하지 않았습니다.

## 출력·검토 결과

기존 R 수식·자료 28개 점검과 동일 에이전트의 Python 402개 대조를 보존합니다. 이를 외부·맹검·독립 에이전트의 원 분석 심사라고 부르지 않습니다. 새 HTML의 내용·레이아웃·전체 자료·그림·다운로드는 문서 수정 범위에서 다시 확인합니다.

## 남은 한계

집계된 평균, 작은 건강한 표본, 기기 간 공유 참가자, 현재 제품·일상생활·환자에 대한 일반화, 임상 허용 기준 부재, 원문 계산 정밀도와 Mio 가변 LoA의 차이가 남습니다. 다음의 17개 기록에서 해결 조치와 과학적으로 미확인인 부분을 구분합니다.''',paper_html=problems,
        result_md=c['localized_issue_md'],files=['report.json','python_crosscheck.json'])
    ]
    # One theory/application pair per learning stage. Existing process/device notes stay intact.
    registry=[];sections=[]
    for index,s in enumerate(stages,1):
        n=f'{index:02d}';base='docs/learning/'+n
        paths={'concept':base+'-concept '+s['title']+'.md','paper':base+'-paper '+s['title']+'.md'}
        common=f"학습 단계: {s['code']} · 관측 단위: 기기별 참가자 protocol 평균 · 자료 버전: {c['plan']['data_version']} · 실행: {run_id}\n\n"
        for kind in ['concept','paper']:
            text='# '+s['title']+' — '+('일반 통계 개념 (concept)' if kind=='concept' else '논문·실제 데이터 적용 (paper)')+'\n\n'
            text+=('이 문서의 숫자 예제는 모두 가상이며 실제 연구 결과가 아닙니다.\n\n' if kind=='concept' else common)
            text+=s[kind]+'\n\n'
            if kind=='paper':
                text+='## 실제 산출물\n\n'+s['result_md']+'\n\n'
                text+='출처 근거: '+s['source']+'\n\n'
                text+='원본 결과: '+', '.join('analysis/runs/'+run_id+'/'+p for p in s['files'])+'\n\n'
                text+='그림: '+(', '.join(s['figures']) or '직접 연결 그림 없음')+'\n\n문제 ID: '+', '.join(s['issues'])+'\n\n'+c['source_links']+'\n'
            text+='\n짝 문서: '+Path(paths['paper' if kind=='concept' else 'concept']).name+'\n'
            c['write'](root/paths[kind],text);mds[paths[kind]]=text
        links=' · '.join(c['link'](paths[k],k+' MD 열기') for k in ['concept','paper'])
        concept_html=md_html(s['concept'])+(demo if s['id']=='association' else '')
        panel='<div class="learning-pair" data-stage="'+s['code']+'">'
        panel+='<article class="learning-part concept" id="'+s['id']+'-concept"><div class="learning-label">CONCEPT · 일반 통계 개념</div><p class="learning-scope">원리·공식·가상 계산·가정·대안 — 특정 논문과 독립적으로 읽는 설명</p>'+concept_html+'</article>'
        panel+='<div class="pair-bridge" aria-hidden="true">↓ 같은 질문을 실제 자료에 적용</div>'
        panel+='<article class="learning-part paper" id="'+s['id']+'-paper"><div class="learning-label">PAPER · 논문·실제 데이터 적용</div><p class="learning-scope">원문 사실 · 이번 구현의 선택 · 실제 출력 · 남은 의문</p>'+md_html(s['paper'])+s['paper_html']
        panel+='<div class="evidence-strip"><strong>연결 근거</strong><p>'+html.escape(s['source'])+'</p><p>문제 ID: '+html.escape(', '.join(s['issues']))+'</p><p>'+links+'</p></div></article></div>'
        sections.append('<section class="section paired-stage" id="'+s['id']+'">'+c['heading'](f'{index+1:02d}',s['title'],'일반 원리를 먼저 읽고, 같은 단계의 원문·구현·결과를 확인합니다.')+panel+'</section>')
        registry.append(dict(stage_id=s['code'],html_anchor=s['id'],title=s['title'],observation_unit='participant-level protocol mean per device; n=22',input=s['input'],output=s['output'],reading_previous=stages[index-2]['code'] if index>1 else None,reading_next=stages[index]['code'] if index<len(stages) else None,execution_dependencies=s['deps'],concept=paths['concept'],paper=paths['paper'],source_locations=s['source'],figures=s['figures'],issue_ids=s['issues']))
    # Keep the summary as overview; all learning stages now visibly use two panels.
    start=body.index('<section class="section" id="data">')
    body=body[:start]+''.join(sections)
    guide='''# 학습 문서 읽기 지도 — concept / paper

HTML 한 파일은 전달 형식입니다. 각 단계의 일반 통계 개념(concept)과 논문·실제 적용(paper) 구분은 유지합니다. 각 페이지는 입력→질문→방법과 이유→출력→남은 질문으로 연결합니다. 개념의 작은 계산은 가상이며 paper의 수치는 실제 R1 결과입니다.

읽는 순서는 학습 흐름이며 저자의 실행 순서나 통계 작업의 직렬 의존성을 뜻하지 않습니다. stage_registry.json의 execution_dependencies가 실제 산출물 관계를 별도로 표시합니다.

'''
    guide+=mdtable(['단계','일반 개념','논문·실제 적용','연결 의문'],[[s['code']+' '+s['title'],registry[i]['concept'],registry[i]['paper'],', '.join(s['issues'])] for i,s in enumerate(stages)])
    guide+='\n기존 docs/00–09 및 docs/devices의 14개 문서는 과정·기기별 보조 기록으로 그대로 보존합니다. 학습의 정본은 docs/learning의 7쌍입니다. 모든 내용은 최종 HTML에도 내장됩니다.\n'
    rel='docs/learning/00-학습문서읽기지도.md';c['write'](root/rel,guide);mds[rel]=guide
    c['jwrite'](root/'analysis/stage_registry.json',dict(schema_version=1,documentation_revision='PAIR1-20261024',run_id=run_id,reading_order_is_not_execution_order=True,paired_stages=7,stages=registry))
    return body,registry

PAIR_CSS='''
.learning-part{padding:26px 28px;border:1px solid var(--line);border-radius:7px;background:white;min-width:0}.learning-part.concept{border-top:4px solid #46669a;background:#f5f8ff}.learning-part.paper{border-top:4px solid var(--teal)}.learning-label{font-size:13px;font-weight:800;letter-spacing:.04em;color:#385988}.paper>.learning-label{color:var(--teal)}.learning-scope{font-size:12px;color:var(--muted);margin:8px 0 25px}.learning-part h3{margin-top:25px;font-size:17px}.learning-part h4{margin:23px 0 8px;font-size:15px}.learning-part p{word-break:normal;overflow-wrap:anywhere}.pair-bridge{padding:12px 15px;font-size:12px;color:var(--muted);text-align:center}.evidence-strip{border-top:1px solid var(--line);margin-top:23px;padding-top:16px;font-size:12px;color:var(--muted)}.evidence-strip p{margin:6px 0}.learning-contract{background:#edf1f9;border-left:4px solid #46669a;padding:18px 22px;margin:25px 0}.learning-contract strong{color:#385988}.paired-stage .formula{background:#edf1f9}.md-group-label{margin-top:25px}.learning-part figure{padding:13px}.learning-part .table-wrap{margin:20px 0}.learning-part .panel{padding:18px}.learning-part .demo{background:white}@media(max-width:760px){.learning-part{padding:18px 15px}.learning-label{font-size:12px}.learning-contract{padding:16px}.learning-part .grid2{grid-template-columns:1fr}.learning-part .table-wrap table{min-width:600px}}@media print{.learning-part{padding:12pt;border:1pt solid #ccc;break-inside:auto}.pair-bridge{padding:7pt}.learning-part h3,.learning-label{break-after:avoid}.learning-contract{break-inside:avoid}}
'''
