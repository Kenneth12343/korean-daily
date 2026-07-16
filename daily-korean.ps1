<#
.SYNOPSIS
    TOPIK 4 Daily Korean Push System (with Email Support)
.DESCRIPTION
    Daily Korean learning push with vocabulary, grammar, and expressions.
    Supports email delivery via QQ Mail SMTP.
.EXAMPLE
    .\daily-korean.ps1               # Console output
    .\daily-korean.ps1 -SendMail      # Send via email
    .\daily-korean.ps1 -Quiz          # Quick daily quiz
    .\daily-korean.ps1 -Test          # Stage-based test
    .\daily-korean.ps1 -ShowAll       # Progress stats
    .\daily-korean.ps1 -MockExam         # Full TOPIK mock exam
    .\daily-korean.ps1 -Reading          # Practice reading comprehension
    .\daily-korean.ps1 -Writing          # Get a writing prompt
    .\daily-korean.ps1 -SendMail -NoToast  # Email only, no popup
#>

param(
    [switch]$ShowAll,
    [switch]$Quiz,
    [switch]$Test,
    [int]$Stage = 0,
    [switch]$MockExam,
    [switch]$Reading,
    [switch]$Writing,
    [switch]$SendMail,
    [switch]$NoToast
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$DataDir = Join-Path $ScriptDir "data"
$ProgressFile = Join-Path $ScriptDir "progress.json"
$EmailConfigFile = Join-Path $ScriptDir "email-config.json"

# =============================================
# STAGE TEST MODE
# =============================================
if ($Test) {
    $testsData = Get-Content (Join-Path $DataDir "tests.json") -Encoding UTF8 | ConvertFrom-Json

    if (Test-Path $ProgressFile) {
        $progress = Get-Content $ProgressFile -Encoding UTF8 | ConvertFrom-Json
    } else {
        $progress = @{
            LearnedVocabulary = @()
            LearnedGrammar = @()
            LearnedExpressions = @()
            StartDate = (Get-Date -Format "yyyy-MM-dd")
            Streak = 0
            LastDate = ""
            TestHistory = @()
        }
    }

    $totalLearned = $progress.LearnedVocabulary.Count + $progress.LearnedGrammar.Count + $progress.LearnedExpressions.Count
    $availableStages = @($testsData.stages | Where-Object { $totalLearned -ge $_.unlock_count })

    if ($availableStages.Count -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Red
        Write-Host "  STAGE TEST - LOCKED" -ForegroundColor Red
        Write-Host "========================================" -ForegroundColor Red
        Write-Host ""
        Write-Host ("You have learned " + $totalLearned + " items so far.") -ForegroundColor White
        Write-Host ("You need 15 items to unlock Stage 1.") -ForegroundColor Yellow
        Write-Host ""
        return
    }

    if ($Stage -gt 0 -and $Stage -le $availableStages.Count) {
        $selectedStage = $testsData.stages[$Stage - 1]
        if ($totalLearned -lt $selectedStage.unlock_count) {
            Write-Host ("Stage " + $Stage + " is locked! Need " + $selectedStage.unlock_count + " items.") -ForegroundColor Red
            return
        }
    } else {
        $selectedStage = $availableStages[-1]
    }

    $canUnlock = @($testsData.stages | Where-Object { $totalLearned -ge $_.unlock_count }).Count

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("  TOPIK STAGE TEST: " + $selectedStage.name) -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("Description : " + $selectedStage.description) -ForegroundColor Gray
    Write-Host ("Questions   : " + $selectedStage.questions.Count) -ForegroundColor Gray
    Write-Host ("Pass Score  : " + $selectedStage.pass_score + "%") -ForegroundColor Gray
    Write-Host ("Unlocked    : Stage 1-" + $canUnlock + " / 4") -ForegroundColor Gray
    Write-Host ""
    Write-Host "----------------------------------------" -ForegroundColor DarkGray

    $score = 0
    $total = $selectedStage.questions.Count
    $qNum = 1

    foreach ($q in $selectedStage.questions) {
        $typeLabel = switch ($q.type) {
            "vocab" { "[VOCAB]" }
            "grammar" { "[GRAMMAR]" }
            "expression" { "[EXPRESSION]" }
            "reading" { "[READING]" }
            default { "[Q]" }
        }

        Write-Host ("--- Q" + $qNum + "/" + $total + " " + $typeLabel + " ---") -ForegroundColor Yellow

        if ($q.type -eq "reading" -and $q.passage) {
            Write-Host ""
            Write-Host $q.passage -ForegroundColor White
            if ($q.passage_cn) { Write-Host ("  -> " + $q.passage_cn) -ForegroundColor DarkGray }
            Write-Host ""
        }

        Write-Host $q.question -ForegroundColor White
        if ($q.question_cn) { Write-Host ("  (" + $q.question_cn + ")") -ForegroundColor DarkGray }
        Write-Host ""

        for ($i = 0; $i -lt $q.options.Count; $i++) {
            Write-Host ("  [" + ($i + 1) + "] " + $q.options[$i]) -ForegroundColor Gray
        }
        Write-Host ""

        $answer = Read-Host "Your answer (1-4)"
        try { $answerIdx = [int]$answer - 1 } catch { $answerIdx = -1 }

        if ($answerIdx -eq $q.answer) {
            Write-Host "  >> CORRECT!" -ForegroundColor Green
            $score++
        } else {
            Write-Host ("  >> WRONG! Answer: " + ($q.answer + 1) + ". " + $q.options[$q.answer]) -ForegroundColor Red
            if ($q.explanation) { Write-Host ("  >> " + $q.explanation) -ForegroundColor DarkYellow }
        }
        Write-Host ""
        $qNum++
    }

    $percent = [math]::Round(($score / $total) * 100)
    $passed = ($percent -ge $selectedStage.pass_score)

    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "  TEST RESULTS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("Stage : " + $selectedStage.name) -ForegroundColor White
    Write-Host ("Score : " + $score + "/" + $total + " (" + $percent + "%)") -ForegroundColor $(if ($passed) { "Green" } else { "Red" })
    Write-Host ("Pass  : " + $selectedStage.pass_score + "%") -ForegroundColor Gray
    Write-Host ""
    if ($passed) {
        Write-Host "   PASSED! " -ForegroundColor Green -NoNewline
        Write-Host "Good job! Keep going!" -ForegroundColor White
    } else {
        Write-Host "   NOT YET " -ForegroundColor Red -NoNewline
        Write-Host "Review and try again!" -ForegroundColor White
    }

    $testResult = @{
        Date = (Get-Date -Format "yyyy-MM-dd HH:mm")
        Stage = $selectedStage.stage
        StageName = $selectedStage.name
        Score = $score
        Total = $total
        Percent = $percent
        Passed = $passed
    }

    if (-not $progress.TestHistory) { $progress.TestHistory = @() }
    $progress.TestHistory += $testResult

    if ($progress.TestHistory.Count -gt 1) {
        Write-Host ""
        Write-Host "--- Test History ---" -ForegroundColor Cyan
        foreach ($h in $progress.TestHistory) {
            $icon = if ($h.Passed) { "[PASS]" } else { "[FAIL]" }
            $color = if ($h.Passed) { "Green" } else { "Red" }
            Write-Host ("  " + $icon + " " + $h.Date + " | Stage " + $h.Stage + " | " + $h.Percent + "%") -ForegroundColor $color
        }
    }

    $progress | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8
    Write-Host ""
    return
}

# =============================================
# MOCK EXAM MODE
# =============================================
if ($MockExam) {
    $testsData = Get-Content (Join-Path $DataDir "tests.json") -Encoding UTF8 | ConvertFrom-Json
    $exam = $testsData.mock_exam

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ("  TOPIK MOCK EXAM: " + $exam.name) -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ("Questions : " + $exam.total_questions) -ForegroundColor Gray
    Write-Host ("Time      : " + $exam.time_limit_minutes + " min") -ForegroundColor Gray
    Write-Host ("Pass      : " + $exam.pass_score + "%") -ForegroundColor Gray
    Write-Host ""

    $score = 0
    $total = $exam.questions.Count
    $qNum = 1

    foreach ($q in $exam.questions) {
        $typeLabel = switch ($q.type) {
            "vocab" { "[VOCAB]" }
            "grammar" { "[GRAMMAR]" }
            "reading" { "[READING]" }
            "expression" { "[EXPRESSION]" }
            default { "[Q]" }
        }

        Write-Host ("--- Q" + $qNum + "/" + $total + " " + $typeLabel + " ---") -ForegroundColor Yellow

        if ($q.type -eq "reading" -and $q.passage) {
            Write-Host ""
            Write-Host $q.passage -ForegroundColor White
            Write-Host ""
        }

        Write-Host $q.question -ForegroundColor White
        Write-Host ""

        for ($i = 0; $i -lt $q.options.Count; $i++) {
            Write-Host ("  [" + ($i + 1) + "] " + $q.options[$i]) -ForegroundColor Gray
        }
        Write-Host ""

        $answer = Read-Host "Your answer (1-4)"
        try { $answerIdx = [int]$answer - 1 } catch { $answerIdx = -1 }

        if ($answerIdx -eq $q.answer) {
            Write-Host "  >> CORRECT!" -ForegroundColor Green
            $score++
        } else {
            Write-Host ("  >> WRONG! Answer: " + ($q.answer + 1)) -ForegroundColor Red
            if ($q.explanation) { Write-Host ("  >> " + $q.explanation) -ForegroundColor DarkYellow }
        }
        Write-Host ""
        $qNum++
    }

    $percent = [math]::Round(($score / $total) * 100)
    $passed = ($percent -ge $exam.pass_score)

    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "  MOCK EXAM RESULTS" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host ("Score : " + $score + "/" + $total + " (" + $percent + "%)") -ForegroundColor $(if ($passed) { "Green" } else { "Red" })
    Write-Host ("Pass  : " + $exam.pass_score + "%") -ForegroundColor Gray

    if ($passed) {
        Write-Host ""
        Write-Host "  CONGRATULATIONS! " -ForegroundColor Green -NoNewline
        Write-Host "You are ready for TOPIK 4!" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "  Keep studying! Review the wrong answers." -ForegroundColor Yellow
    }
    Write-Host ""

    # Save to test history
    if (Test-Path $ProgressFile) { $progress = Get-Content $ProgressFile -Encoding UTF8 | ConvertFrom-Json } else { $progress = @{ TestHistory = @() } }
    $examResult = @{ Date = (Get-Date -Format "yyyy-MM-dd HH:mm"); Stage = 0; StageName = $exam.name; Score = $score; Total = $total; Percent = $percent; Passed = $passed }
    if (-not $progress.TestHistory) { $progress.TestHistory = @() }
    $progress.TestHistory += $examResult
    $progress | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8
    return
}

# =============================================
# READING PRACTICE MODE
# =============================================
if ($Reading) {
    $passages = Get-Content (Join-Path $DataDir "reading_passages.json") -Encoding UTF8 | ConvertFrom-Json
    $rp = $passages | Get-Random

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("  READING PRACTICE | " + $rp.topic) -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("Title : " + $rp.title + "  |  TOPIK Level: " + $rp.level) -ForegroundColor Gray
    Write-Host ""
    Write-Host $rp.passage -ForegroundColor White
    Write-Host ("  -> " + $rp.passage_cn) -ForegroundColor DarkGray
    Write-Host ""

    foreach ($q in $rp.questions) {
        Write-Host ("Q: " + $q.question) -ForegroundColor Yellow
        Write-Host ""
        for ($i = 0; $i -lt $q.options.Count; $i++) {
            Write-Host ("  [" + ($i + 1) + "] " + $q.options[$i]) -ForegroundColor Gray
        }
        Write-Host ""
        $answer = Read-Host "Your answer (1-4)"
        try { $ansIdx = [int]$answer - 1 } catch { $ansIdx = -1 }
        if ($ansIdx -eq $q.answer) {
            Write-Host "  >> CORRECT!" -ForegroundColor Green
        } else {
            Write-Host ("  >> Answer: " + ($q.answer + 1) + ". " + $q.options[$q.answer]) -ForegroundColor Red
            if ($q.explanation) { Write-Host ("  >> " + $q.explanation) -ForegroundColor DarkYellow }
        }
        Write-Host ""
    }
    Write-Host "More reading: .\daily-korean.ps1 -Reading" -ForegroundColor DarkGray
    return
}

# =============================================
# WRITING PROMPT MODE
# =============================================
if ($Writing) {
    $prompts = Get-Content (Join-Path $DataDir "writing_prompts.json") -Encoding UTF8 | ConvertFrom-Json
    $wp = $prompts | Get-Random

    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ("  WRITING PRACTICE | TOPIK Level " + $wp.level) -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("TOPIC : " + $wp.topic) -ForegroundColor Yellow
    Write-Host ("       " + $wp.topic_cn) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("PROMPT:") -ForegroundColor White
    Write-Host $wp.prompt -ForegroundColor White
    Write-Host ("  -> " + $wp.prompt_cn) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("GUIDE WORDS: " + ($wp.guide_words -join ", ")) -ForegroundColor Gray
    Write-Host ("            " + ($wp.guide_words_cn -join ", ")) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host ("SAMPLE OPENING:") -ForegroundColor Cyan
    Write-Host $wp.sample_opening -ForegroundColor Cyan
    Write-Host ("  -> " + $wp.sample_opening_cn) -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Try writing 300-600 characters using the guide words." -ForegroundColor Gray
    Write-Host "More prompts: .\daily-korean.ps1 -Writing" -ForegroundColor DarkGray
    return
}

# =============================================
# DAILY PUSH MODE
# =============================================

$vocabulary = Get-Content (Join-Path $DataDir "vocabulary.json") -Encoding UTF8 | ConvertFrom-Json
$grammar = Get-Content (Join-Path $DataDir "grammar.json") -Encoding UTF8 | ConvertFrom-Json
$expressions = Get-Content (Join-Path $DataDir "expressions.json") -Encoding UTF8 | ConvertFrom-Json

if (Test-Path $ProgressFile) {
    $progress = Get-Content $ProgressFile -Encoding UTF8 | ConvertFrom-Json
} else {
    $progress = @{
        LearnedVocabulary = @()
        LearnedGrammar = @()
        LearnedExpressions = @()
        StartDate = (Get-Date -Format "yyyy-MM-dd")
        Streak = 0
        LastDate = ""
        TestHistory = @()
    }
}

$today = Get-Date -Format "yyyy-MM-dd"
$isTodayDone = ($progress.LastDate -eq $today)

function Get-RandomUnlearned {
    param($items, $learnedList)
    $unlearned = @($items | Where-Object {
        $item = $_
        ($item.word -notin $learnedList) -and
        ($item.grammar -notin $learnedList) -and
        ($item.expression -notin $learnedList)
    })
    if ($unlearned.Count -eq 0) { return ($items | Get-Random) }
    return ($unlearned | Get-Random)
}

$todayVocab = Get-RandomUnlearned -items $vocabulary -learnedList $progress.LearnedVocabulary
$todayGrammar = Get-RandomUnlearned -items $grammar -learnedList $progress.LearnedGrammar
$todayExpr = Get-RandomUnlearned -items $expressions -learnedList $progress.LearnedExpressions

if (-not $isTodayDone) {
    $progress.LearnedVocabulary += $todayVocab.word
    $progress.LearnedGrammar += $todayGrammar.grammar
    $progress.LearnedExpressions += $todayExpr.expression
    $progress.LastDate = $today
    $progress.Streak += 1
}

$progress | ConvertTo-Json -Depth 10 | Set-Content $ProgressFile -Encoding UTF8

$totalLearned = $progress.LearnedVocabulary.Count + $progress.LearnedGrammar.Count + $progress.LearnedExpressions.Count

# Stage info
$stageInfo = ""
if (Test-Path (Join-Path $DataDir "tests.json")) {
    $testsData = Get-Content (Join-Path $DataDir "tests.json") -Encoding UTF8 | ConvertFrom-Json
    $unlockedStage = 0
    foreach ($s in $testsData.stages) { if ($totalLearned -ge $s.unlock_count) { $unlockedStage = $s.stage } }
    if ($unlockedStage -gt 0) {
        $stageInfo = " | STAGE " + $unlockedStage + " UNLOCKED!"
    } else {
        $remaining = $testsData.stages[0].unlock_count - $totalLearned
        $stageInfo = " | " + $remaining + " more to unlock Stage 1"
    }
}

# Build text output
$sep = "-" * 50
$textOutput = @"

$sep
    [KR] TODAY KOREAN  |  [CN] TODAY KOREAN
$sep

DATE: $today  |  STREAK: $($progress.Streak) DAYS$stageInfo
LEARNED: VOCAB $($progress.LearnedVocabulary.Count) | GRAMMAR $($progress.LearnedGrammar.Count) | EXPRESSIONS $($progress.LearnedExpressions.Count)


==================== [VOCAB] ====================
WORD   : $($todayVocab.word)
MEANING: $($todayVocab.meaning)
POS    : $($todayVocab.pos) | TOPIK LEVEL: $($todayVocab.level)
EXAMPLE: $($todayVocab.example)
  -> $($todayVocab.example_cn)


==================== [GRAMMAR] ===================
PATTERN: $($todayGrammar.grammar)
MEANING: $($todayGrammar.meaning)
USAGE  : $($todayGrammar.usage)
DESC   : $($todayGrammar.explanation)
EXAMPLE: $($todayGrammar.example)
  -> $($todayGrammar.example_cn)


==================== [EXPRESSION] ================
PHRASE : $($todayExpr.expression)
MEANING: $($todayExpr.meaning)
CONTEXT: $($todayExpr.context)
PRON   : $($todayExpr.pronunciation)


==================== [MOTTO] =====================
MOTTO: Keep studying, the goal is near!
  -> Keep studying, you will reach TOPIK 4!

$sep
    [KR] TODAY STUDY FIGHTING!  |  TODAY STUDY FIGHTING!
$sep

"@

# Console output
if (-not $SendMail) {
    Write-Host $textOutput -ForegroundColor White
}

# =============================================
# EMAIL SENDING FUNCTION
# =============================================
function Send-KoreanMail {
    param($Vocab, $Grammar, $Expr, $Progress, $TotalLearned, $StageInfo)

    if (-not (Test-Path $EmailConfigFile)) {
        Write-Host "[EMAIL] Config file not found: $EmailConfigFile" -ForegroundColor Red
        return $false
    }

    $emailConfig = Get-Content $EmailConfigFile -Encoding UTF8 | ConvertFrom-Json

    if ($emailConfig.Password -eq "YOUR_AUTH_CODE_HERE" -or [string]::IsNullOrEmpty($emailConfig.Password)) {
        Write-Host "[EMAIL] Please set your QQ Mail authorization code in email-config.json" -ForegroundColor Red
        Write-Host "[EMAIL] See instructions above for getting your auth code" -ForegroundColor Yellow
        return $false
    }

    if (-not $emailConfig.UseEmail) {
        Write-Host "[EMAIL] Email is disabled in config (UseEmail = false)" -ForegroundColor Yellow
        return $false
    }

    # Build HTML email body
    $streakDays = $Progress.Streak
    $htmlBody = @"
<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body { font-family: 'Segoe UI', 'Microsoft YaHei', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }
.card { max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.1); }
.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }
.header h1 { margin: 0; font-size: 24px; }
.header p { margin: 8px 0 0; opacity: 0.9; font-size: 14px; }
.stats { display: flex; justify-content: space-around; padding: 16px; background: #fafafa; border-bottom: 1px solid #eee; }
.stat { text-align: center; }
.stat .num { font-size: 22px; font-weight: bold; color: #667eea; }
.stat .label { font-size: 12px; color: #999; margin-top: 4px; }
.section { padding: 20px 24px; border-bottom: 1px solid #f0f0f0; }
.section:last-child { border-bottom: none; }
.section .tag { display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 11px; font-weight: bold; margin-bottom: 8px; }
.tag-vocab { background: #e3f2fd; color: #1565c0; }
.tag-grammar { background: #fce4ec; color: #c62828; }
.tag-expr { background: #e8f5e9; color: #2e7d32; }
.section .word { font-size: 22px; font-weight: bold; color: #333; margin: 6px 0; }
.section .meaning { font-size: 16px; color: #555; margin: 4px 0; }
.section .meta { font-size: 12px; color: #999; margin: 4px 0; }
.section .example { background: #fafafa; padding: 10px 14px; border-left: 3px solid #667eea; margin: 10px 0; border-radius: 0 6px 6px 0; font-size: 14px; color: #444; }
.section .example-cn { font-size: 12px; color: #888; margin-top: 4px; }
.motto { background: #fff9e6; padding: 20px 24px; text-align: center; border-top: 1px solid #f0f0f0; }
.motto .kr { font-size: 16px; color: #b8860b; font-style: italic; }
.motto .cn { font-size: 13px; color: #999; margin-top: 4px; }
.footer { text-align: center; padding: 16px; font-size: 11px; color: #bbb; }
.footer a { color: #667eea; text-decoration: none; }
.stage-alert { background: #e8f5e9; padding: 10px 20px; text-align: center; font-size: 14px; color: #2e7d32; font-weight: bold; }
</style>
</head>
<body>
<div class="card">
<div class="header">
<h1> [KR] TODAY KOREAN</h1>
<p>$today | [KR] TODAY STUDY FIGHTING!</p>
</div>
<div class="stats">
<div class="stat"><div class="num">$($progress.Streak)</div><div class="label">DAY STREAK</div></div>
<div class="stat"><div class="num">$($Progress.LearnedVocabulary.Count)</div><div class="label">VOCAB</div></div>
<div class="stat"><div class="num">$($Progress.LearnedGrammar.Count)</div><div class="label">GRAMMAR</div></div>
<div class="stat"><div class="num">$($Progress.LearnedExpressions.Count)</div><div class="label">EXPRESSIONS</div></div>
</div>
$($stageAlert)
<div class="section">
<span class="tag tag-vocab">[VOCAB]</span>
<div class="word">$($Vocab.word)</div>
<div class="meaning">$($Vocab.meaning)</div>
<div class="meta">$($Vocab.pos) | TOPIK LEVEL $($Vocab.level)</div>
<div class="example">$($Vocab.example)<div class="example-cn">$($Vocab.example_cn)</div></div>
</div>
<div class="section">
<span class="tag tag-grammar">[GRAMMAR]</span>
<div class="word">$($Grammar.grammar)</div>
<div class="meaning">$($Grammar.meaning)</div>
<div class="meta">$($Grammar.usage)</div>
<div class="example">$($Grammar.example)<div class="example-cn">$($Grammar.example_cn)</div></div>
</div>
<div class="section">
<span class="tag tag-expr">[EXPRESSION]</span>
<div class="word">$($Expr.expression)</div>
<div class="meaning">$($Expr.meaning)</div>
<div class="meta">$($Expr.context) | $($Expr.pronunciation)</div>
</div>
<div class="motto">
<div class="kr">"[KR] KEEP STUDYING!"</div>
<div class="cn">[CN] KEEP STUDYING, YOU WILL REACH TOPIK 4!</div>
</div>
<div class="footer">
TOPIK 4 Daily Korean Push System<br>
CMD: .\daily-korean.ps1 | .\daily-korean.ps1 -Test
</div>
</div>
</body>
</html>
"@
    # Stage alert banner
    $stageAlert = ""
    if ($StageInfo -match "UNLOCKED") {
        $stageAlert = '<div class="stage-alert"> ' + $StageInfo + ' - Try: .\daily-korean.ps1 -Test</div>'
    }

    try {
        $smtp = New-Object Net.Mail.SmtpClient($emailConfig.SmtpServer, $emailConfig.Port)
        $smtp.EnableSsl = $emailConfig.UseSSL
        $smtp.Credentials = New-Object System.Net.NetworkCredential($emailConfig.Username, $emailConfig.Password)

        $mailMessage = New-Object Net.Mail.MailMessage
        $mailMessage.From = $emailConfig.From
        $mailMessage.To.Add($emailConfig.To)
        $mailMessage.Subject = "[KR] TODAY KOREAN " + $today + " | VOCAB: " + $Vocab.word + " | " + $Grammar.grammar + " | STREAK " + $Progress.Streak + " DAYS"
        $mailMessage.Body = $htmlBody
        $mailMessage.IsBodyHtml = $true
        $mailMessage.BodyEncoding = [System.Text.Encoding]::UTF8
        $mailMessage.SubjectEncoding = [System.Text.Encoding]::UTF8

        $smtp.Send($mailMessage)
        Write-Host "[EMAIL] Sent successfully to $($emailConfig.To)" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[EMAIL] Send failed: $_" -ForegroundColor Red
        Write-Host "[EMAIL] Check: 1) Auth code is correct 2) SMTP service is enabled in QQ Mail" -ForegroundColor Yellow
        return $false
    }
}

# Send email if requested
if ($SendMail) {
    Write-Host "[EMAIL] Sending daily Korean lesson..." -ForegroundColor Cyan
    $result = Send-KoreanMail -Vocab $todayVocab -Grammar $todayGrammar -Expr $todayExpr -Progress $progress -TotalLearned $totalLearned -StageInfo $stageInfo
    if ($result) {
        Write-Host "[EMAIL] Check your inbox: $($emailConfig.To)" -ForegroundColor Green
    }
}

# Save log
$logDir = Join-Path $ScriptDir "logs"
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Force -Path $logDir | Out-Null }
$logFile = Join-Path $logDir ("daily-" + $today + ".txt")
$textOutput | Set-Content $logFile -Encoding UTF8

# Toast notification
if (-not $NoToast) {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
        $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
        $notifyIcon.BalloonTipTitle = "[KR] TODAY KOREAN"
        $notifyIcon.BalloonTipText = ("WORD: " + $todayVocab.word + " | GRAMMAR: " + $todayGrammar.grammar)
        $notifyIcon.BalloonTipIcon = [System.Windows.Forms.ToolTipIcon]::Info
        $notifyIcon.Visible = $true
        $notifyIcon.ShowBalloonTip(10000)
    } catch { }
}

# ShowAll stats
if ($ShowAll) {
    Write-Host ""
    Write-Host "========== OVERALL STATS ==========" -ForegroundColor Cyan
    Write-Host ("Total Vocab       : " + $vocabulary.Count) -ForegroundColor Gray
    Write-Host ("Total Grammar     : " + $grammar.Count) -ForegroundColor Gray
    Write-Host ("Total Expressions : " + $expressions.Count) -ForegroundColor Gray
    Write-Host ("Learned Vocab     : " + $progress.LearnedVocabulary.Count) -ForegroundColor Gray
    Write-Host ("Learned Grammar   : " + $progress.LearnedGrammar.Count) -ForegroundColor Gray
    Write-Host ("Learned Express   : " + $progress.LearnedExpressions.Count) -ForegroundColor Gray
    Write-Host ("Total Learned     : " + $totalLearned) -ForegroundColor White

    if (Test-Path (Join-Path $DataDir "tests.json")) {
        Write-Host ""
        Write-Host "--- Stage Test Progress ---" -ForegroundColor Yellow
        foreach ($s in $testsData.stages) {
            $status = if ($totalLearned -ge $s.unlock_count) { "[UNLOCKED]" } else { "[LOCKED]" }
            $color = if ($totalLearned -ge $s.unlock_count) { "Green" } else { "DarkGray" }
            Write-Host ("  Stage " + $s.stage + " " + $status + " " + $s.name + " (need " + $s.unlock_count + " items)") -ForegroundColor $color
        }
    }

    if ($progress.TestHistory -and $progress.TestHistory.Count -gt 0) {
        Write-Host ""
        Write-Host "--- Test History ---" -ForegroundColor Cyan
        foreach ($h in $progress.TestHistory) {
            $icon = if ($h.Passed) { "[PASS]" } else { "[FAIL]" }
            $color = if ($h.Passed) { "Green" } else { "Red" }
            Write-Host ("  " + $icon + " " + $h.Date + " | Stage " + $h.Stage + " | " + $h.Percent + "%") -ForegroundColor $color
        }
    }
}

# Quick quiz
if ($Quiz) {
    Write-Host ""
    Write-Host "========== QUICK QUIZ ==========" -ForegroundColor Yellow
    $quizType = @("vocab", "grammar", "expr") | Get-Random
    if ($quizType -eq "vocab") {
        $q = $vocabulary | Get-Random
        Write-Host ("Q: What does this word mean?") -ForegroundColor Cyan
        Write-Host ("   " + $q.word) -ForegroundColor White
        Write-Host ("A: " + $q.meaning) -ForegroundColor Green
    } elseif ($quizType -eq "grammar") {
        $q = $grammar | Get-Random
        Write-Host ("Q: What does this grammar mean?") -ForegroundColor Cyan
        Write-Host ("   " + $q.grammar) -ForegroundColor White
        Write-Host ("A: " + $q.meaning) -ForegroundColor Green
    } else {
        $q = $expressions | Get-Random
        Write-Host ("Q: What does this expression mean?") -ForegroundColor Cyan
        Write-Host ("   " + $q.expression) -ForegroundColor White
        Write-Host ("A: " + $q.meaning) -ForegroundColor Green
    }
}

