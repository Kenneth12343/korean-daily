#!/usr/bin/env python3
"""
TOPIK 4  Daily Korean Push - Cloud Email Sender
Runs on GitHub Actions to send daily Korean learning emails via QQ Mail.
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

# ── Email Config ──────────────────────────────
SMTP_SERVER = "smtp.qq.com"
SMTP_PORT = 587
FROM_EMAIL = "524181692@qq.com"
TO_EMAIL = "524181692@qq.com"
USERNAME = "524181692@qq.com"
# Password from environment variable (GitHub Secret)
PASSWORD = os.environ.get("QQ_MAIL_AUTH_CODE", "")


def load_json(path):
    with open(path, "r", encoding="utf-8") as f:
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
        "StartDate": datetime.now().strftime("%Y-%m-%d"),
        "Streak": 0,
        "LastDate": "",
        "TestHistory": [],
    }


def get_random_unlearned(items, learned_list):
    """Select a random item that hasn't been learned yet."""
    # Build keys depending on item type
    unlearned = []
    for item in items:
        key = item.get("word") or item.get("grammar") or item.get("expression")
        if key not in learned_list:
            unlearned.append(item)

    if not unlearned:
        return random.choice(items)
    return random.choice(unlearned)


def build_html_email(vocab, grammar, expr, progress):
    """Build a beautiful HTML email."""
    today = datetime.now().strftime("%Y-%m-%d")
    streak = progress.get("Streak", 0)
    vocab_count = len(progress.get("LearnedVocabulary", []))
    grammar_count = len(progress.get("LearnedGrammar", []))
    expr_count = len(progress.get("LearnedExpressions", []))

    return f"""<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<style>
body {{ font-family: 'Segoe UI', 'Microsoft YaHei', 'Malgun Gothic', sans-serif; background: #f5f5f5; margin: 0; padding: 20px; }}
.card {{ max-width: 600px; margin: 0 auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 2px 12px rgba(0,0,0,0.1); }}
.header {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }}
.header h1 {{ margin: 0; font-size: 24px; }}
.header p {{ margin: 8px 0 0; opacity: 0.9; font-size: 14px; }}
.stats {{ display: flex; justify-content: space-around; padding: 16px; background: #fafafa; border-bottom: 1px solid #eee; }}
.stat {{ text-align: center; }}
.stat .num {{ font-size: 22px; font-weight: bold; color: #667eea; }}
.stat .label {{ font-size: 12px; color: #999; margin-top: 4px; }}
.section {{ padding: 20px 24px; border-bottom: 1px solid #f0f0f0; }}
.section .tag {{ display: inline-block; padding: 2px 10px; border-radius: 12px; font-size: 11px; font-weight: bold; margin-bottom: 8px; }}
.tag-vocab {{ background: #e3f2fd; color: #1565c0; }}
.tag-grammar {{ background: #fce4ec; color: #c62828; }}
.tag-expr {{ background: #e8f5e9; color: #2e7d32; }}
.section .main {{ font-size: 22px; font-weight: bold; color: #333; margin: 6px 0; }}
.section .meaning {{ font-size: 16px; color: #555; margin: 4px 0; }}
.section .meta {{ font-size: 12px; color: #999; margin: 4px 0; }}
.section .example {{ background: #fafafa; padding: 10px 14px; border-left: 3px solid #667eea; margin: 10px 0; border-radius: 0 6px 6px 0; font-size: 14px; color: #444; }}
.section .example-cn {{ font-size: 12px; color: #888; margin-top: 4px; }}
.motto {{ background: #fff9e6; padding: 20px 24px; text-align: center; border-top: 1px solid #f0f0f0; }}
.motto .kr {{ font-size: 16px; color: #b8860b; font-style: italic; }}
.motto .cn {{ font-size: 13px; color: #999; margin-top: 4px; }}
.footer {{ text-align: center; padding: 16px; font-size: 11px; color: #bbb; }}
.footer a {{ color: #667eea; text-decoration: none; }}
</style>
</head>
<body>
<div class="card">
<div class="header">
<h1>🇰🇷 오늘의 한국어 | TODAY KOREAN</h1>
<p>{today} | 오늘도 화이팅!</p>
</div>
<div class="stats">
<div class="stat"><div class="num">{streak}</div><div class="label">DAY STREAK</div></div>
<div class="stat"><div class="num">{vocab_count}</div><div class="label">VOCAB</div></div>
<div class="stat"><div class="num">{grammar_count}</div><div class="label">GRAMMAR</div></div>
<div class="stat"><div class="num">{expr_count}</div><div class="label">EXPRESSIONS</div></div>
</div>
<div class="section">
<span class="tag tag-vocab">📝 VOCABULARY</span>
<div class="main">{vocab['word']}</div>
<div class="meaning">{vocab['meaning']}</div>
<div class="meta">{vocab['pos']} | TOPIK LEVEL {vocab['level']}</div>
<div class="example">{vocab['example']}<div class="example-cn">➜ {vocab['example_cn']}</div></div>
</div>
<div class="section">
<span class="tag tag-grammar">📐 GRAMMAR</span>
<div class="main">{grammar['grammar']}</div>
<div class="meaning">{grammar['meaning']}</div>
<div class="meta">{grammar['usage']}</div>
<div class="example">{grammar['example']}<div class="example-cn">➜ {grammar['example_cn']}</div></div>
</div>
<div class="section">
<span class="tag tag-expr">🗣️ EXPRESSION</span>
<div class="main">{expr['expression']}</div>
<div class="meaning">{expr['meaning']}</div>
<div class="meta">{expr['context']} | {expr['pronunciation']}</div>
</div>
<div class="motto">
<div class="kr">끊임없이 노력하는 사람만이 목표에 도달할 수 있다</div>
<div class="cn">只有不断努力的人才能达到目标 | NEVER GIVE UP, YOU WILL REACH TOPIK 4!</div>
</div>
<div class="footer">
TOPIK 4 Daily Korean Push System<br>
Powered by GitHub Actions - Runs every day at 08:00 UTC
</div>
</div>
</body>
</html>"""


def send_email(html_body, subject):
    """Send email via QQ Mail SMTP."""
    if not PASSWORD:
        print("[ERROR] QQ_MAIL_AUTH_CODE not set in environment!")
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
    print("  TOPIK 4 DAILY KOREAN PUSH (CLOUD)")
    print("=" * 50)

    # Load data
    vocabulary = load_json(DATA_DIR / "vocabulary.json")
    grammar = load_json(DATA_DIR / "grammar.json")
    expressions = load_json(DATA_DIR / "expressions.json")

    print(f"Loaded: {len(vocabulary)} vocab, {len(grammar)} grammar, {len(expressions)} expressions")

    # Load progress
    progress = load_progress()

    today = datetime.now().strftime("%Y-%m-%d")
    is_today_done = progress.get("LastDate") == today

    # Select today's content
    vocab = get_random_unlearned(vocabulary, progress.get("LearnedVocabulary", []))
    gram = get_random_unlearned(grammar, progress.get("LearnedGrammar", []))
    expr = get_random_unlearned(expressions, progress.get("LearnedExpressions", []))

    # Update progress
    if not is_today_done:
        progress["LearnedVocabulary"].append(vocab["word"])
        progress["LearnedGrammar"].append(gram["grammar"])
        progress["LearnedExpressions"].append(expr["expression"])
        progress["LastDate"] = today

        # Calculate streak
        yesterday = (datetime.now() - timedelta(days=1)).strftime("%Y-%m-%d")
        prev_date = progress.get("_prevDate", "")
        if prev_date == yesterday or progress.get("Streak", 0) == 0:
            progress["Streak"] = progress.get("Streak", 0) + 1
        else:
            progress["Streak"] = 1
        progress["_prevDate"] = today

    # Save progress
    save_json(PROGRESS_FILE, progress)

    # Build email
    subject = f"🇰🇷 TODAY KOREAN {today} | {vocab['word']} | {gram['grammar']} | STREAK {progress['Streak']} DAYS"
    html = build_html_email(vocab, gram, expr, progress)

    # Send
    print(f"Today's vocab: {vocab['word']} ({vocab['meaning']})")
    print(f"Today's grammar: {gram['grammar']} ({gram['meaning']})")
    print(f"Today's expression: {expr['expression']} ({expr['meaning']})")
    print(f"Streak: {progress['Streak']} days")
    print()

    send_email(html, subject)
    print("Done!")


if __name__ == "__main__":
    main()
