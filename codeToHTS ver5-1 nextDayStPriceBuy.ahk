
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; codeToHTS ver5-1 nextDayStPriceBuy

; 작성일 : 2014-07-31

; 파이썬으로 출력한 필터된 종목코드를 이용해서 한국투자증권 HTS로 차트를 컨트롤하는 프로그램
;<<ver5-1>> - 날짜를 진행하면서 투자결정을 하는데, 손절선과 익절선을 사용자가 설정할 수 있고, 특정 시점에서 매도 여부를 결정할 수 있는 방식,
;매수 결정하고 손절, 익절 라인을 정한다음, 하루씩 전진하면서 자동 손익절 되거나, 손익절 아니더라도 상황에 따라 
; 그날 종가로 매도를 할 지 말지를 결정할 수 있게 하는 방식
; <<<5-1은 다음날 시가에 매수할 수 있는 기능 추가>>

;## 폴더 파일 세팅
; 미리 날짜별로 필터 한 파일들을 ./dateResult 폴더에 넣음.
; 결과 날짜들을 인덱싱한 ./dateResultIndex.txt 파일을 둠
; data 폴더에 모든 종목 원데이터 넣기

;======= 주의사항 ======================
;## 판단식의 왼쪽엔 변수가 오른쪽엔 값이들어간다.
; 비교문 if string1 = "sss"에서 오른쪽은 값이 들어가므로 쌍따옴표까지 인식,
; if "sss" = %string1% 에서는 왼쪽은 변수로 인식하므로 sss만 인식됨.
; 괄호로 묶으면 상관 없는듯. if (string = "sss")

;## 한 차트에서 기간 설정을 너무 크게잡으면 요청 데이터가 많기 때문에 딜레이가 생긴다. 기간 수를 짧게 잡자.

;;## 입력은  종목코드 입력후 아주 빠르게 날짜 입력하는 순서로해야한다.'날짜-> 코드'순으로 입력시 두가지가 따로 적용되도록 HTS가 설계되었기에, '날짜->코드' 순으로 입력하면, 아무리 빨라도 날짜적용된 후 종목코드 적용되면서 코드입력창이 꼬여버린다. 반면, 코드입력후 바로 날짜입력하면 두가지가 한번에 적용되므로 딜레이가 없다.


;========================================
#InstallKeybdHook
SetFormat, float, 0.3 	;; float 계산결과 포맷팅
CoordMode, Mouse, Screen


start(){
	SoundPlay, ./sound/Start-Up.wav

	mousePositionX = 445 	;; 한투HTS에서 일반차트 밑부분에 기간 [숫자] 조회[숫자]오른편에 위아래 화살표 중 위쪽화살표의 마우스 X좌표 (윈도우 스파이로 정할것 )
    mousePositionY = 780 ;; 위쪽화살표의 마우스 Y좌표

	lossCutDefault = -0.04
	revenueCutDefault = 1.00
	global lossCut := lossCutDefault
	global revenueCut := revenueCutDefault

	global lossCutChecked = 0
	global revenueCutChecked = 0
	

	;curDateStockNum = 0 ;현재 날짜의 종목 수
	;curStockIndex = 0 ;현재 날짜안에서의 위치
	curStockDataIndex = 0 	; incomeOutput 해당파일의 현재 날짜 인덱스

	date := ""
	code := ""
	dataFilePath := ""
	stPrice = 0
	highPrice = 0
	lowPrice = 0
	endPrice = 0

	owned = 0 	;;주식 보유 여부
	buyPrice = 0 	;; 매수 가격
	buyDate := ""	;; 매수 날짜
	sellPrice = 0 	;; 매도 가격
	income = -1000 	;; 손익%	: 기본값(-1000)이면 손익 계산결과 없으므로 기록X
	curIncome = 0 	;; 매수 후 현재 수익률
	dayAfter = 0 	;; 매수 후 경과 영업일
	dealed = 0 	;거래여부- 거래시 invest 기록에 Skip 기록하지 않음.
	
	total = 100 	;; 100원 투자했을 때, 최종 수익
	totalDay = 0 	;; 총 거래일

	
	
	; 시작 시 세팅
	;; 투자 결과 기록파일 경로
	investPath =  ./invest/%A_YYYY%-%A_MM%-%A_DD%.txt
	str1 ========VER5======###시작 : %A_Hour% : %A_Min% : %A_Sec% ========================================`n
	FileAppend , %str1%, %investPath%

	randomSetting(curStockDataIndex, date, code, stPrice, highPrice, lowPrice, endPrice, dataFilePath)
		
	inputCode(code, mousePositionX, mousePositionY)
	inputDate(date, mousePositionX, mousePositionY)
	sleep 1000
	inputCode(code, mousePositionX, mousePositionY)
	inputDate(date, mousePositionX, mousePositionY)

;;;;; 키보드 입력으로 컨트롤
	Loop
	{
		state := "U"
	
		sleep, 30
		GetKeyState, state, Down
		if state = D
		{
			if (owned = 1)	;; 보유중이면 비활성
	    		continue

			if (!dealed)	;거래 결정하지 않았을 경우 skip 기록	;거래했으면 skip기록X
			{
				str1 =%date% %code% Skip`n
				FileAppend , %str1%, %investPath%

			}
			dealed = 0

			if (lossCutChecked = 0) ;;체크 되어있지 않으면 다음 종목은 손절라인 디폴트로
			{
				lossCut := lossCutDefault
			}
			if (revenueCutChecked = 0)
			{
				revenueCut := revenueCutDefault
			}

			randomSetting(curStockDataIndex, date, code, stPrice, highPrice, lowPrice, endPrice, dataFilePath)
			
			inputCode(code, mousePositionX, mousePositionY)
			inputDate(date, mousePositionX, mousePositionY)
			sleep 1000
			inputCode(code, mousePositionX, mousePositionY)
			inputDate(date, mousePositionX, mousePositionY)

			SoundPlay, ./sound/page-flip-10.wav	; 페이지 넘기는 소리
			send {Down Up}	; 무한 루프 방지
			;msgbox, %date% %code% %curCodeIndex% %curDateCodeNum%
			continue
		}

		GetKeyState, state, Up
	    if state = D
	    {
	    	inputCode(code, mousePositionX, mousePositionY)
	    	inputDate(date, mousePositionX, mousePositionY)
	    	sleep 100
	    	inputCode(code, mousePositionX, mousePositionY)
	    	inputDate(date, mousePositionX, mousePositionY)

	    	send {Up Up}
	    	continue
	    }


		GetKeyState, state, Right
	    if state = D
	    {
	    	if (curStockDataIndex <= 2)
	    	{
	    		msgbox, data파일의 마지막 날짜입니다.
	    		continue
	    	}
	    	curStockDataIndex := curStockDataIndex -1 

			getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)

			inputDate(date, mousePositionX, mousePositionY)
			sleep 100
			inputDate(date, mousePositionX, mousePositionY)
			msg1 := ""
			if (owned = 1)		
			{
				dayAfter := dayAfter + 1
				Gosub, CutModule
			}
	    	sleep, 100
	    	send {Right Up}
	    	continue
	    }

		GetKeyState, state, Left
		if state = D
	    {
	    	if (owned = 1)	;; 보유중이면 비활성
	    		continue
	    	curStockDataIndex := curStockDataIndex +1 
	    	getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)

	    	inputDate(date, mousePositionX, mousePositionY)
	    	sleep, 100
	    	send {Left Up}
	    	continue
	    }

	    GetKeyState, state, PgDn
		if state = D
	    {
	    	if (owned = 1)	;; 보유중이면 비활성
	    		continue
	    	if (curStockDataIndex <= 6)
	    	{
	    		msgbox, data파일의 마지막 날짜입니다.
	    		continue
	    	}
	    	curStockDataIndex := curStockDataIndex -5
	    	getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)
			inputDate(date, mousePositionX, mousePositionY)
	    	sleep, 100
	    	send {PgDn Up}
	    	continue
	    }

	    GetKeyState, state, PgUp
		if state = D
	    {
	    	if (owned = 1)	;; 보유중이면 비활성
	    		continue
	    	curStockDataIndex := curStockDataIndex +5
	    	getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)
			inputDate(date, mousePositionX, mousePositionY)
	    	sleep, 100
	    	send {PgUp Up}
	    	continue
	    }

	   
	    GetKeyState, state, VKC0 ;; 물결버튼 : 손익절 라인 조정
	    if state = D
	    {
	    	gui1(lossCut, revenueCut, lossCutChecked, revenueCutChecked, curIncome, dayAfter)

	    	send {VKC0 Up}
			continue
	    }

	    GetKeyState, state, RShift	;; 매수 및 매도 키 
	    if state = D
	    {
	    	if (owned = 0)		;;매수
	    	{
	    		Progress, zh0 b w500 h30 cw00FF00 x180 y50, 경과일:%dayAfter% 수익률:%curIncome% 손절선: %lossCut% 익절선: %revenueCut%
	    		owned = 1
		    	buyPrice := endPrice
		    	buyDate := date
		    	msg1 = %date% : %buyPrice%에 매수
		    	SplashTextOn, 300, 30, , %msg1%
				sleep 1500
				SplashTextOff
		    	;msgbox, %date% : %buyPrice%에 매수

	    	}
	    	else if (owned = 1)		;;매도
	    	{
	    		Progress, Off
	    		owned = 0
	    		income := (endPrice - buyPrice)/buyPrice
	    		str1 = %buyDate% %buyPrice%원 %code% 수익률: %income% 경과일: %dayAfter%일, 매도: %date% %endPrice%원`n
	    		FileAppend , %str1%, %investPath%

	    		if (income >= 0.15)
					successSound()
				else if (income <= -0.04)
					failSound()
				total := total + (total * income)
				totalDay := totalDay + dayAfter
	    		dayAfter = 0
	    		dealed = 1
	    		income = -1000
	    		msg1 = %date% : %endPrice%에 매도
	    		SplashTextOn, 300, 30, , %msg1%
				sleep 1500
				SplashTextOff
				if (lossCutChecked = 0) ;; 매도됐으면 손절라인 디폴트로
				{
					lossCut := lossCutDefault
				}
				if (revenueCutChecked = 0)
				{
					revenueCut := revenueCutDefault
				}

	    	}

			send {RShift Up}
			continue
	    }

	    GetKeyState, state, NumpadDiv 	;; 다음날 시가에 매수하는 키
	    if state = D
	    {
	    	if (owned = 1)	;; 보유중이면 비활성
	    		continue

	    	nextDayIndex := curStockDataIndex - 1
	    	FileReadLine, line, %dataFilePath%, %nextDayIndex%
			if ErrorLevel
		      	msgbox, error in GetKeyState, state, NumpadDiv

			array2 := strsplit(line, A_Tab)
			nextDate := array2[1]
			nextStPrice := array2[2]
			StringReplace, nextStPrice, nextStPrice, `,,, All
			nextRate := (nextStPrice - endPrice)/endPrice

	    	msg1 = 담날(%nextDate%) 시가 : %nextStPrice%원 상승률:%nextRate%
	    	msgbox, 1, 시초가 매수할래?, %msg1%

	    	IfMsgBox OK
		    {
		    	Progress, zh0 b w500 h30 cw00FF00 x180 y50, 경과일:%dayAfter% 수익률:%curIncome% 손절선: %lossCut% 익절선: %revenueCut%
	    		owned = 1

		    	curStockDataIndex := curStockDataIndex -1 
				getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)
				inputDate(date, mousePositionX, mousePositionY)
				sleep 100
				inputDate(date, mousePositionX, mousePositionY)
				msg1 := ""

				buyPrice := nextStPrice
				buyDate  := nextDate
				Gosub, CutModule

		    }
			else
			    continue

	    	/*
	    	SplashTextOn, 300, 30, , %msg1%
			sleep 1500
			SplashTextOff
			*/
	    	send {NumpadDiv Up}
	    	continue
	    

	    }

  		GetKeyState, state, NumpadAdd ;;HTS 일반차트 아래에서 아래쪽 화살표
	    if state = D
	    {
	    	mouseclick, L, mousePositionX,  mousePositionY+7 ;; 기준좌표 대비
	    	mouseclick, L, mousePositionX,  mousePositionY+7
	    	mouseclick, L, mousePositionX,  mousePositionY+7
	    	mouseclick, L, 700, 863	; 키입력을 방지하기 위해 바탕화면 클릭
	    	
	    	send {NumpadAdd Up}
	    	continue
	    }

	    GetKeyState, state, NumpadSub ;; HTS 일반차트 아래에서 위쪽 화살표
	    if state = D
	    {
	    	mouseclick, L, mousePositionX,  mousePositionY ;; 기준좌표
	    	mouseclick, L, mousePositionX,  mousePositionY 
	    	mouseclick, L, mousePositionX,  mousePositionY 
	    	mouseclick, L, 700, 863	; 키입력을 방지하기 위해 바탕화면 클릭
	    	
	    	send {NumpadSub Up}
	    	continue
	    }


	    GetKeyState, state, NumpadMult
	    if state = D
	    {
	    	str1 =  <<성과>>`n기초자산 : 100원, 기말자산 : %total% 원, 총 경과일: %totalDay%일`n
			FileAppend , %str1%, %investPath%
			total = 100
			str1 ========VER5======###종료 :  %A_Hour% : %A_Min% : %A_Sec% ========================================`n`n
			FileAppend , %str1%, %investPath%
			Progress, Off
			;; GUI 삭제(중복 방지 위해)
			GUI, Destroy
	    	msgbox, end
	    	return 0 
	    }

	    GetKeyState, state, VKDD	;; 현재 종목 날짜를 클립보드에 복사
	    if state = D
	    {

	    	StringReplace, date1, date, `/,, All
	    	clipboard = %date1%
	    	;msgbox, %date1%
	    	send {VKDD Up}
	    	continue
	    }

	    GetKeyState, state, VKDB	;; 현재 종목 코드를 클립보드에 복사
	    if state = D
	    {
	    	StringReplace, code1, code, A,, All
	    	clipboard = %code1%
	    	;msgbox, %date1%
	    	send {VKDB Up}
	    	continue
	    }

	}

	;;;;===============================
	CutModule: 	;; 손익절 모듈 Gosub라벨
	;;보유 중 손익절 처리
	if ((stPrice - buyPrice)/buyPrice <= lossCut)	;; 시가 손절처리
	{
		income := (stPrice - buyPrice)/buyPrice
		sellPrice := stPrice
		msg1 = %sellPrice% 원에 시가 손절됨
	}
	else if ((stPrice - buyPrice)/buyPrice >= revenueCut)	;; 시가 익절처리
	{
		income := (stPrice - buyPrice)/buyPrice
		sellPrice := stPrice
		msg1 = %sellPrice% 원에 시가 익절됨
	}

	;;; 손익절 처리
	else
	{
		if (endPrice >= stPrice)	;; 양봉
		{
			if((lowPrice - buyPrice)/buyPrice <= lossCut)
			{
				income := lossCut
				sellPrice := buyPrice + buyPrice*lossCut
				msg1 = %sellPrice% 원에 손절됨
			}
			if((highPrice - buyPrice)/buyPrice >= revenueCut)
			{
				income := revenueCut
				sellPrice := buyPrice + buyPrice*revenueCut
				msg1 = %sellPrice% 원에 익절됨
			}
		}
		else if (endPrice < stPrice)	;; 음봉
		{
			if((highPrice - buyPrice)/buyPrice >= revenueCut)
			{
				income := revenueCut
				sellPrice := buyPrice + buyPrice*revenueCut
				msg1 = %sellPrice% 원에 익절됨
			}
			if((lowPrice - buyPrice)/buyPrice <= lossCut)
			{
				income := lossCut
				sellPrice := buyPrice + buyPrice*lossCut
				msg1 = %sellPrice% 원에 손절됨
			}
		}
		
	}
	if (income >= -900)	;; 어떤 식으로든 손익절이 있었으면
	{
		if (income >= 0.15)
			successSound()
		else if (income <= -0.05)
			failSound()
		total := total + (total * income)
		totalDay := totalDay + dayAfter
		str1 =%buyDate% %buyPrice%원 %code% 수익률: %income% 경과일: %dayAfter%일, 매도: %date% %sellPrice%원`n
		FileAppend , %str1%, %investPath%
		dealed = 1
		income = -1000
		owned = 0
		dayAfter = 0
		SplashTextOn, 300, 30, , %msg1%
		sleep 1500
		SplashTextOff
		Progress, Off
		if (lossCutChecked = 0) ;; 매도됐으면 손절라인 디폴트로
		{
			lossCut := lossCutDefault
		}
		if (revenueCutChecked = 0)
		{
			revenueCut := revenueCutDefault
		}
	}
	else
	{
		curIncome := (endPrice - buyPrice)/buyPrice
		Progress, Off
		Progress, zh0 b w500 h30 cw00FF00 x180 y50, 경과일:%dayAfter% 수익률:%curIncome% 손절선: %lossCut% 익절선: %revenueCut% 
	}	
	return 	;; Gosub라벨 종료
	;;;;===============================

	return

}



inputDate(date, mousePositionX, mousePositionY)	;날짜 받아서 한투 HTS 일반차트창에 날짜 세팅
{
	BlockInput, on
	StringSplit, word_array, date, "/"
	;msgbox, %word_array3%, %word_array2%, %word_array1% 	

	mouseclick, L, mousePositionX-206, mousePositionY+5 ;; 기준좌표 대비

	
	sendinput %word_array1% 
	send {Right}
	sendinput %word_array2%
	send {Right}
	sendinput %word_array3%
	
	mouseclick, L, mousePositionX+384, mousePositionY+50	; 키입력을 방지하기 위해 바탕화면 클릭
	
	BlockInput, off
	return

}

inputCode(code, mousePositionX, mousePositionY)	;코드를 받아서 HTS 클릭
{
	;날짜입력시 딜레이가 코드입력시에도 영향을 주는지 inputCode만 하면 숫자가 밀리지 않는다. randomset 함수를 쓰면 숫자 입력 시 밀리는 데??
	BlockInput, on
	StringReplace, code, code, A,, All
	
	mouseclick, L,394, 119

	sendinput %code%
	
	;;;;; HTS에서 차트 변경시 딜레이가 생기면 입력도중이나 입력후에 늦게 변경된 종목코드가 자동으로 입력돼서 오류가 생긴다. 즉, HTS에서 딜레이가 생기면 코드에 상관없이 에러난다.
	;; 한 차트에서 기간 설정을 너무 크게잡으면 요청 데이터가 많기 때문에 딜레이가 생긴다. 기간 수를 짧게 잡자.
	
	mouseclick, L, mousePositionX+384, mousePositionY+50	; 키입력을 방지하기 위해 바탕화면 클릭
	
	BlockInput, off
	return

}


getStockIndex(date, code, pOrd)
{

	StringLeft, year1, date, 4
	if (year1 = "2014")
		startIndex = 1
	else
	{
		if (year1 = "2013")
			startIndex = 118
		else if(year1 = "2012")
			startIndex = 365
		else if(year1 = "2011")
			startIndex = 613		
		else if(year1 = "2010")
			startIndex = 861
		else if(year1 = "2009")
			startIndex = 1112
		else if(year1 = "2008")
			startIndex = 1365
		else if(year1 = "2007")
			startIndex = 1613
		else if(year1 = "2006")
			startIndex = 1859
		else if(year1 = "2005")
			startIndex = 2106
		else if(year1 = "2004")
			startIndex = 2355
		else if(year1 = "2003")
			startIndex = 2604
		else if(year1 = "2002")
			startIndex = 2851
		else if(year1 = "2001")
			startIndex = 3095
		else if(year1 = "2000")
			startIndex = 3341
		else if(year1 = "1999")
			startIndex = 3582
		else if(year1 = "1998")
			startIndex = 3831
		else if(year1 = "1997")
			startIndex = 4123
		else if(year1 = "1996")
			startIndex = 4415
		else if(year1 = "1995")
			startIndex = 4708
		startIndex -= 5 ;; 데이터 상에서 하루이틀 잘못된 걸 조정하기 위해
	}


	if (pOrd = "kospi")
	{
		path1 =./data/kospi/%code%.txt
	}
	else if(pOrd = "kosdaq")
	{
		path1 =./data/kosdaq/%code%.txt
	}
	else
	{
		msgbox, in getStockIndex 해당 파일을 찾을 수 없다.
		ExitApp
	}

	Loop	; 개장일 파일에서 기준일의 줄 위치를 구함
	{
		;msgbox % path1 (A_Index +  startIndex)
	    FileReadLine, line, %path1%, % A_Index + startIndex
	    if ErrorLevel
	    {

	    	msgbox, error in getStockIndex() Loop
	    	msgbox, %path1% %date% index : %A_Index% + start : %startIndex%
        	break
        }
        index1 := A_Index + startIndex
        StringLeft, lineDate, line, 10
       
	    if (date = lineDate) 
	    { 
	    	;msgbox % "내용 :"  lineDate  "입력 :"  date "같다 " code " " index1
	    	break
	    }

	}	

	;msgbox, %index1%
	return index1

}



randomSetting(ByRef curStockDataIndex, ByRef date, ByRef code, ByRef stPrice,ByRef highPrice, ByRef lowPrice, ByRef endPrice, ByRef dataFilePath)
{

	Random, rand, 1, 3681   ; 3922는 dateResultIndex의 줄 수 = 날짜 수
	FileReadLine, date, ./dateResultIndex.txt, %rand%
	;msgbox  하하하하%date1%하하하하

	; date 2001-01-01
	path := % "./dateResult/" . date . ".txt"
		
	FileReadLine, line, %path%, 1
	StringReplace, line, line, `n,, All
	curDateStockNum := line
	
	Random, rand, 2, curDateStockNum+1
	curStockIndex := rand
	FileReadLine, line, %path%, %curStockIndex%

	array1 := strsplit(line, A_Tab)
	code := array1[1]		

	IfExist, ./data/kospi/%code%.txt
		pOrd := "kospi"
	IfExist, ./data/kosdaq/%code%.txt	
		pOrd := "kosdaq"

	StringReplace, date, date, -,/, All
	;; date  = 2001/01/01
	curStockDataIndex := getStockIndex(date, code, pOrd)

	if (pOrd = "kospi")
	{
		dataFilePath := % "./data/kospi/" . code . ".txt"
	}
	else if(pOrd = "kosdaq")
	{
		dataFilePath := % "./data/kosdaq/" . code . ".txt"
	}
	else
	{
		msgbox, in getStockIndex 해당 파일을 찾을 수 없다.
		ExitApp
	}
	
	
	getInfo(date, stPrice, highPrice, lowPrice, endPrice, dataFilePath, curStockDataIndex)


}

getInfo(ByRef date, ByRef stPrice, ByRef highPrice, ByRef lowPrice, ByRef endPrice, dataFilePath, curStockDataIndex)
{
	FileReadLine, line, %dataFilePath%, %curStockDataIndex%
	if ErrorLevel
    {
    	msgbox, error in getInfo()
  		return
    }

	array2 := strsplit(line, A_Tab)
	date := array2[1]
	stPrice := array2[2]
	highPrice := array2[3]
	lowPrice := array2[4]
	endPrice := array2[5]
	StringReplace, stPrice, stPrice, `,,, All
	StringReplace, highPrice, highPrice, `,,, All
	StringReplace, lowPrice, lowPrice, `,,, All
	StringReplace, endPrice, endPrice, `,,, All	
}



successSound()
{
	Random, rand, 1, 4
	if (rand = 1 or rand = 2)
	{
		FileDelete,./Sound1.AHK
	    FileAppend,
	    (
	    
	    #NoTrayIcon
	    FileDelete,./Sound1.AHK
	    FileAppend, 
	    `(
	    #NoTrayIcon
	   
	   	FileDelete,./Sound1.AHK
	    FileAppend, 
	    ```(
	    #NoTrayIcon
	    SoundPlay, ./soundImage/applause1.mp3, Wait
	    ```), ./Sound1.AHK
	    Run, Sound1.AHK


	    SoundPlay, ./soundImage/cash_register2.wav, Wait
	    `), ./Sound1.AHK
	    Run, Sound1.AHK

	    SoundPlay, ./soundImage/Homer - Woohoo! (1).wav, Wait
	    ), ./Sound1.AHK
	    Run, Sound1.AHK
	}
	else if (rand = 3)
		SoundPlay, ./soundImage/yeahclap2.mp3
	else if (rand = 4)
		SoundPlay, ./soundImage/brass-fanfare-4.wav

	Random, rand, 1, 4
	if (rand=1)
		SplashImage, ./soundImage/bookreading.jpg, x1000 y500 B ZW400 zh-1
	else if (rand = 2)
		SplashImage, ./soundImage/napoleon.jpg, B x1000 y500 ZW300 zh-1
	else if (rand = 3)
		SplashImage, ./soundImage/gold.jpg, B x1000 y500 ZW400 zh-1
	else if (rand = 4)
		SplashImage, ./soundImage/money1.jpg, B x1000 y500 ZW400 zh-1
	sleep 1000
	SplashImage Off
}

failSound()
{
	Random, rand, 1, 5
	if (rand = 1)
		SoundPlay, ./soundImage/boo.wav
	else if (rand = 2)
		SoundPlay, ./soundImage/Dispappointed-Crowd1.mp3
	else if (rand = 3)
		SoundPlay, ./soundImage/fail-trombone-02.wav
	else if (rand = 4)
		SoundPlay, ./soundImage/small_group_of_people_booing.mp3
	else if (rand = 5)
		SoundPlay, ./soundImage/alert2.wav
	SplashImage, ./soundImage/sonbeggar.jpg, x1000 y500 B ZW400 zh-1	
	sleep 1000
	SplashImage Off
}


gui1(ByRef lossCut, ByRef revenueCut, ByRef lossCutChecked, ByRef revenueCutChecked, curIncome, dayAfter)
{
	
	Gui, Add, Text,, 손절라인:
	Gui, Add, Text,, 익절라인:
	Gui, Add, Edit, W100 vlossCut ys, %lossCut%   ; The ym option starts a new column of controls.
	Gui, Add, Edit, W100 vrevenueCut, %revenueCut%

	Gui, Add, Checkbox, vlossCutChecked Checked%lossCutChecked%  ys xp+105
	Gui, Add, Checkbox, vrevenueCutChecked Checked%revenueCutChecked% yp+30

	Gui, Add, Button, gReset1  ys yp-33 xp+30, Reset
	Gui, Add, Button, gReset2  yp+25, Reset

	
	Gui, Add, Button, glossDown5  ys , ▼5
	Gui, Add, Button, grevenueDown5  , ▼5

	Gui, Add, Button, glossDown1  ys , ▼1
	Gui, Add, Button, grevenueDown1  , ▼1

	Gui, Add, Button, glossUp1  ys , ▲1
	Gui, Add, Button, grevenueUp1  , ▲1

	Gui, Add, Button, glossUp5  ys , ▲5
	Gui, Add, Button, grevenueUp5  , ▲5

	Gui, Add, Button, default wp ym, OK    
	Gui, Show,, Simple Input Example
	return  

	GuiClose:
	Gui, Destroy
	return

	Reset1:
	lossCut = -0.05
	Guicontrol,, lossCut, %lossCut%
	return

	Reset2:
	revenueCut = 1000
	Guicontrol,, revenueCut, %revenueCut%
	return 

	lossUp5:
	lossCut += 0.05
	Guicontrol,, lossCut, %lossCut%
	return

	revenueUp5:
	if (revenueCut = 1000)
		revenueCut = 0.00
	revenueCut += 0.05
	Guicontrol,, revenueCut, %revenueCut%
	return

	lossUp1:
	lossCut += 0.01
	Guicontrol,, lossCut, %lossCut%
	return

	revenueUp1:
	if (revenueCut = 1000)
		revenueCut = 0.00
	revenueCut += 0.01
	Guicontrol,, revenueCut, %revenueCut%
	return

	lossDown1:
	lossCut -= 0.01
	Guicontrol,, lossCut, %lossCut%

	return

	revenueDown1:
	if (revenueCut = 1000)
		revenueCut = 0.00
	revenueCut -= 0.01
	Guicontrol,, revenueCut, %revenueCut%
	return

	lossDown5:
	if (revenueCut = 1000)
		revenueCut = 0.00
	lossCut -= 0.05
	Guicontrol,, lossCut, %lossCut%

	return

	revenueDown5:
	revenueCut -= 0.05
	Guicontrol,, revenueCut, %revenueCut%
	return

	ButtonOK:
	Gui, Submit  ; Save the input from the user to each control's associated variable.
	;MsgBox You entered "%lossCut% %revenueCut%".
	Gui, Destroy
	Progress, Off
	Progress, zh0 b w500 h30 cw00FF00 x180 y50, 경과일:%dayAfter% 수익률:%curIncome% 손절선: %lossCut% 익절선: %revenueCut%
	return


}

test()
{
	Loop
	{
		
		sleep, 30
		GetKeyState, state, VKDD
		if state = D
		{
			msgbox, pressed]
		}
	}
}


test2()
{
	global lossCut = -0.05
	global revenueCut = 1000
	global lossCutChecked = 1
	global revenueCutChecked =1
	gui1( lossCut,  revenueCut,  lossCutChecked,  revenueCutChecked, 0, 0)

}


F1::
start()
return

F3::
test()
return

F4::
test2()
return