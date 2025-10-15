#!/usr/bin/env bash
# greyhound_bootstrap.sh
# Quick local experiment for UK Greyhound odds feed
# Usage:
#   chmod +x greyhound_bootstrap.sh
#   ./greyhound_bootstrap.sh

set -e

echo "=== Setting up local environment ==="
python3 -m venv .venv
source .venv/bin/activate
pip install --quiet requests pandas tabulate

API_KEY="87cf4413022aac306302e88e3bdb510b"
SPORT_KEY="upcoming"   # Use 'upcoming' to get odds for all sports

echo "=== Fetching UK Greyhound odds ==="

python3 - <<PYCODE
import requests, pandas as pd
from tabulate import tabulate

API_KEY = "${API_KEY}"
SPORT_KEY = "${SPORT_KEY}"
url = f"https://api.the-odds-api.com/v4/sports/{SPORT_KEY}/odds/?regions=uk&markets=h2h&apiKey={API_KEY}"

print(f"Requesting odds for {SPORT_KEY} ...")
resp = requests.get(url)
if resp.status_code != 200:
    print("Error:", resp.status_code, resp.text)
    exit(1)

data = resp.json()
if not data:
    print("No data returned.")
    exit(0)

rows = []
for ev in data:
    race = ev.get("home_team","") + " vs " + ev.get("away_team","")
    race_time = ev.get("commence_time","")[:19].replace("T"," ")
    for book in ev.get("bookmakers", []):
        if book.get("key") != "ladbrokes_uk":
            continue  # Only include Ladbrokes UK
        for m in book.get("markets", []):
            if m["key"] != "h2h": 
                continue
            for out in m["outcomes"]:
                rows.append({
                    "time": race_time,
                    "event": race.strip(" vs "),
                    "bookmaker": book["title"],
                    "selection": out["name"],
                    "odds": out["price"]
                })

df = pd.DataFrame(rows)
if df.empty:
    print("No Ladbrokes UK odds data found.")
else:
    df = df.sort_values(["time","event","bookmaker","selection"])
    print("\n=== Upcoming Ladbrokes UK Odds (sample) ===")
    print(tabulate(df.head(20), headers="keys", tablefmt="psql"))
    df.to_csv("ladbrokes_odds.csv", index=False)
    print("\nSaved to ladbrokes_odds.csv")
PYCODE

echo "=== Done. You can inspect ladbrokes_odds.csv or rerun anytime. ==="