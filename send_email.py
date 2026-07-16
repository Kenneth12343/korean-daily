#!/usr/bin/env python3
"""
TOPIK 4  Daily Korean Push - Cloud Email Sender (Enhanced)
Runs on GitHub Actions. Sends: 5 vocab + 2 grammar + 1 expression + 1 reading
"""
import json
import random
import smtplib
import os
import sys
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
DATA_DIR = SCRIPT_DIR / "data"
PROGRESS_FILE = SCRIPT_DIR / "progress.json"

SMTP_SERVER = "smtp.qq.com"
SMTP_PORT = 587
FROM_EMAIL = "524181692@qq.com"
TO_EMAIL = "524181692@qq.com"
USERNAME = "524181692@qq.com"
PASSWORD = os.environ.get("QQ_MAIL_AUTH_CODE", "")


def load_json(path):
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)


def save_json(path, data):
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def load_progress():
    if PROGRESS_FILE.exists():
        return load_json(PROGRESS_FILE)
    return {
        "LearnedVocabulary": [],
        "LearnedGrammar": [],
        "LearnedExpressions": [],
        "LearnedReadings": [],
        "StartDate": datetime.now().strftime("%Y-%m-%d"),
        "Streak": 0,
        "LastDate": "",
        "TestHistory": [],
    }


def get_random_unlearned(items, learned_list, count=1, key_field=None):
    """Select N random unlearned items. If not enough unlearned, fill with random."""
    unlearned = []
    for item in items:
        if key_field:
            key = item.get(key_field, "")
        else:
            key = item.get("word") or item.get("grammar") or item.get("expression") or item.get("id", "")
        if key not in learned_list:
            unlearned.append(item)

    result = []
    if len(unlearned) >= count:
        result = random.sample(unlearned, count)
    else:
        result = unlearned[:]
        remaining = count - len(result)
        others = [i for i in items if i not in result]
        if others:
            result.extend(random.choices(others, k=min(remaining, len(others))))

    return result


def build_vocab_card(v):
    """Build HTML for one vocab item."""
    return f"""<div style="padding:8px 0;border-bottom:1px dashed #eee">
<span style="font-size:18px;font-weight:bold;color:#1565c0">{v['word']}</span>
<span style="font-size:14px;color:#555;margin-left:8px">{v['meaning']}</span>
<span style="font-size:11px;color:#999;margin-left:8px">[{v['pos']}] L{v['level']}</span>
<div style="font-size:12px;color:#666;margin-top:2px">例: {v['example']}</div>
<div style="font-size:11px;color:#aaa">→ {v['example_cn']}</div>
</div>"""


def build_grammar_card(g):
    """Build HTML for one grammar item."""
    return f"""<div style="padding:8px 0;border-bottom:1px dashed #eee">
<span style="font-size:18px;font-weight:bold;color:#c62828">{g['grammar']}</span>
<span style="font-size:14px;color:#555;margin-left:8px">{g['meaning']}</span>
<span style="font-size:11px;color:#999;margin-left:8px">L{g['level']}</span>
<div style="font-size:12px;color:#666;margin-top:2px"><b>用法:</b> {g['usage']}</div>
<div style="font-size:12px;color:#666">例: {g['example']}</div>
<div style="font-size:11px;color:#aaa">→ {g['example_cn']}</div>
</div>"""


def build_reading_card(r):
    """Build HTML for a reading passage."""
    questions_html = ""
    for q in r.get("questions", []):
        opts = "  |  ".join([f"{i+1}. {o}" for i, o in enumerate(q.get("options", []))])
        questions_html += f"""<div style="background:#fafafa;padding:8px 12px;margin:6px 0;border-radius:6px">
<div style="font-size:13px;color:#333;font-weight:bold">❓ {q['question']}</div>
<div style="font-size:12px;color:#999;margin-top:4px">{opts}</div>
<div style="font-size:11px;color:#2e7d32;margin-top:2px">✓ 答案: {q['options'][q['answer']]}</div>
</div>"""
    return f"""<div style="padding:10px 0">
<div style="font-size:13px;color:#444;line-height:1.8;background:#fafafa;padding:12px;border-radius:8px;border-left:3px solid #667eea">
<b>📖 {r['title']}</b> <span style="color:#999;font-size:11px">TOPIK L{r['level']}</span><br><br>
{r['passage']}
</div>
<div style="font-size:11px;color:#aaa;margin-top:4px">→ {r['passage_cn']}</div>
{questions_html}
</div>"""


def build_html_email(vocabs, grammars, expr, reading, progress):
    """Build a rich daily HTML email."""
    today = datetime.now().strftime("%Y-%m-%d")
    day_of_week = ["月曜日", "火曜日", "水曜日", "木曜日", "金曜日", "土曜日", "日曜日"]
    dow = day_of_week[datetime.now().weekday()]
    streak = progress.get("Streak", 0)
    vocab_count = len(progress.get("LearnedVocabulary", []))
    grammar_count = len(progress.get("LearnedGrammar", []))
    expr_count = len(progress.get("LearnedExpressions", []))

    vocab_cards = "\n".join([build_vocab_card(v) for v in vocabs])
    grammar_cards = "\n".join([build_grammar_card(g) for g in grammars])
    reading_html = build_reading_card(reading)

    # Calculate progress toward TOPIK 4
    vocab_pct = min(100, round(vocab_count / 450 * 100))
    grammar_pct = min(100, round(grammar_count / 74 * 100))

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body {{ font-family: 'Segoe UI','Microsoft YaHei','Malgun Gothic',sans-serif; background:#f5f5f5; margin:0; padding:20px; }}
.card {{ max-width:620px; margin:0 auto; background:white; border-radius:12px; overflow:hidden; box-shadow:0 2px 12px rgba(0,0,0,0.1); }}
.header {{ background:linear-gradient(135deg,#667eea 0%,#764ba2 100%); color:white; padding:24px; text-align:center; }}
.header h1 {{ margin:0; font-size:22px; }}
.header p {{ margin:6px 0 0; opacity:0.9; font-size:13px; }}
.stats {{ display:flex; justify-content:space-around; padding:14px; background:#fafafa; border-bottom:1px solid #eee; }}
.stat {{ text-align:center; }}
.stat .num {{ font-size:20px; font-weight:bold; color:#667eea; }}
.stat .label {{ font-size:11px; color:#999; margin-top:2px; }}
.bar-wrap {{ background:#e0e0e0; border-radius:4px; height:6px; margin-top:4px; width:60px; margin-left:auto;margin-right:auto; }}
.bar-fill {{ background:#667eea; border-radius:4px; height:6px; }}
.section {{ padding:16px 20px; border-bottom:1px solid #f0f0f0; }}
.section .tag {{ display:inline-block; padding:2px 10px; border-radius:12px; font-size:11px; font-weight:bold; margin-bottom:10px; }}
.tag-vocab {{ background:#e3f2fd; color:#1565c0; }}
.tag-grammar {{ background:#fce4ec; color:#c62828; }}
.tag-expr {{ background:#e8f5e9; color:#2e7d32; }}
.tag-reading {{ background:#fff3e0; color:#e65100; }}
.expr-main {{ font-size:20px; font-weight:bold; color:#333; margin:6px 0; }}
.motto {{ background:#fff9e6; padding:16px 20px; text-align:center; border-top:1px solid #f0f0f0; }}
.motto .kr {{ font-size:15px; color:#b8860b; font-style:italic; }}
.motto .cn {{ font-size:12px; color:#999; margin-top:4px; }}
.footer {{ text-align:center; padding:14px; font-size:10px; color:#bbb; }}
</style>
</head>
<body>
<div class="card">
<div class="header">
<h1>🇰🇷 오늘의 한국어 | TOPIK 4 DAILY</h1>
<p>{today} ({dow}) | 연속 {streak}일째 | 오늘도 화이팅!</p>
</div>
<div class="stats">
<div class="stat">
<div class="num">{streak}</div><div class="label">连续天数</div>
</div>
<div class="stat">
<div class="num">{vocab_count}</div><div class="label">累计词汇</div>
<div class="bar-wrap"><div class="bar-fill" style="width:{vocab_pct}%"></div></div>
</div>
<div class="stat">
<div class="num">{grammar_count}</div><div class="label">累计语法</div>
<div class="bar-wrap"><div class="bar-fill" style="width:{grammar_pct}%"></div></div>
</div>
<div class="stat">
<div class="num">{expr_count}</div><div class="label">累计表达</div>
</div>
</div>

<div class="section">
<span class="tag tag-vocab">📝 오늘의 어휘 (今日词汇 x5)</span>
{vocab_cards}
</div>

<div class="section">
<span class="tag tag-grammar">📐 오늘의 문법 (今日语法 x2)</span>
{grammar_cards}
</div>

<div class="section">
<span class="tag tag-expr">🗣️ 오늘의 표현 (今日表达)</span>
<div class="expr-main">{expr['expression']}</div>
<div style="font-size:15px;color:#555;margin:4px 0">{expr['meaning']}</div>
<div style="font-size:12px;color:#999">{expr['context']}</div>
<div style="font-size:12px;color:#888">发音: {expr['pronunciation']}</div>
</div>

<div class="section">
<span class="tag tag-reading">📖 오늘의 읽기 (今日阅读)</span>
{reading_html}
</div>

<div class="motto">
<div class="kr">"끊임없이 노력하는 사람만이 목표에 도달할 수 있다"</div>
<div class="cn">只有不断努力的人才能达到目标 | 3个月拿下TOPIK 4! 💪</div>
</div>
<div class="footer">
TOPIK 4 Daily Korean Push · 每日08:00自动推送 · Powered by GitHub Actions
</div>
</div>
</body>
</html>"""


def send_email(html_body, subject):
    if not PASSWORD:
        print("[ERROR] QQ_MAIL_AUTH_CODE not set!")
        sys.exit(1)

    msg = MIMEMultipart("alternative")
    msg["From"] = FROM_EMAIL
    msg["To"] = TO_EMAIL
    msg["Subject"] = subject

    msg.attach(MIMEText(html_body, "html", "utf-8"))

    try:
        server = smtplib.SMTP(SMTP_SERVER, SMTP_PORT, timeout=30)
        server.starttls()
        server.login(USERNAME, PASSWORD)
        server.sendmail(FROM_EMAIL, [TO_EMAIL], msg.as_string())
        server.quit()
        print(f"[SUCCESS] Email sent to {TO_EMAIL}")
        return True
    except Exception as e:
        print(f"[ERROR] Failed to send email: {e}")
        sys.exit(1)


def main():
    print("=" * 50)
    print("  TOPIK 4 DAILY KOREAN PUSH (ENHANCED)")
    print("  5 Vocab + 2 Grammar + 1 Expression + 1 Reading")
    print("=" * 50)

    vocabulary = load_json(DATA_DIR / "vocabulary.json")
    grammar = load_json(DATA_DIR / "grammar.json")
    expressions = load_json(DATA_DIR / "expressions.json")
    readings = load_json(DATA_DIR / "reading_passages.json")

    print(f"Loaded: {len(vocabulary)} vocab, {len(grammar)} grammar, "
          f"{len(expressions)} expressions, {len(readings)} readings")

    progress = load_progress()
    today = datetime.now().strftime("%Y-%m-%d")
    is_today_done = progress.get("LastDate") == today

    # Select content
    vocabs = get_random_unlearned(vocabulary, progress.get("LearnedVocabulary", []),
                                  count=5, key_field="word")
    grams = get_random_unlearned(grammar, progress.get("LearnedGrammar", []),
                                 count=2, key_field="grammar")
    expr = get_random_unlearned(expressions, progress.get("LearnedExpressions", []),
                                count=1, key_field="expression")[0]
    reading = get_random_unlearned(readings, progress.get("LearnedReadings", []),
                                   count=1, key_field="id")[0]

    # Update progress
    if not is_today_done:
        for v in vocabs:
            progress["LearnedVocabulary"].append(v["word"])
        for g in grams:
            progress["LearnedGrammar"].append(g["grammar"])
        progress["LearnedExpressions"].append(expr["expression"])
        progress["LearnedReadings"].append(reading["id"])
        progress["LastDate"] = today

        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        prev_date = progress.get("_prevDate", "")
        if prev_date == yesterday or progress.get("Streak", 0) == 0:
            progress["Streak"] = progress.get("Streak", 0) + 1
        else:
            progress["Streak"] = 1
        progress["_prevDate"] = today

    save_json(PROGRESS_FILE, progress)

    # Build and send
    vocab_preview = "、".join([v["word"] for v in vocabs])
    subject = (f"🇰🇷 TOPIK韩语 {today} | 词汇:{vocabs[0]['word']}等5个 "
               f"| 语法:{grams[0]['grammar']} | 连续{progress['Streak']}天")
    html = build_html_email(vocabs, grams, expr, reading, progress)

    print(f"Vocab: {vocab_preview}")
    print(f"Grammar: {grams[0]['grammar']}, {grams[1]['grammar']}")
    print(f"Expression: {expr['expression']}")
    print(f"Reading: {reading['title']}")
    print(f"Streak: {progress['Streak']} days")

    send_email(html, subject)
    print("Done!")


if __name__ == "__main__":
    main()
