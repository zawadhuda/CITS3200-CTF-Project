#!/usr/bin/env python3
"""Visit unreviewed support tickets as the W3 administrator browser."""

import json
import os
import time
import urllib.parse
import urllib.request

from selenium import webdriver
from selenium.webdriver.chrome.options import Options


BASE_URL = os.environ.get("HELIX_BASE_URL", "http://127.0.0.1:5000").rstrip("/")
REVIEW_KEY = os.environ["HELIX_REVIEW_KEY"]
FLAG_PATH = os.environ.get("W3_FLAG_PATH", "/opt/helix/flags/w3.txt")
POLL_SECONDS = int(os.environ.get("HELIX_POLL_SECONDS", "5"))


def get_json(path):
    with urllib.request.urlopen(BASE_URL + path, timeout=10) as response:
        return json.load(response)


def post(path):
    request = urllib.request.Request(BASE_URL + path, data=b"", method="POST")
    with urllib.request.urlopen(request, timeout=10) as response:
        return response.status


def review_ticket(ticket_id, flag):
    options = Options()
    options.add_argument("--headless")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")

    driver = webdriver.Chrome(options=options)
    try:
        driver.get(BASE_URL + "/")
        # This challenge cookie is readable by JavaScript on purpose.
        driver.add_cookie({"name": "helix_admin", "value": flag, "path": "/"})
        key = urllib.parse.quote(REVIEW_KEY, safe="")
        driver.get(f"{BASE_URL}/internal/review/{ticket_id}?key={key}")
        time.sleep(2)
    finally:
        driver.quit()


def run_once():
    key = urllib.parse.quote(REVIEW_KEY, safe="")
    pending = get_json(f"/internal/next-ticket?key={key}")
    ticket_id = pending.get("ticket_id")
    if ticket_id is None:
        return False

    flag = open(FLAG_PATH, encoding="utf-8").read().strip()
    review_ticket(ticket_id, flag)
    post(f"/internal/mark-reviewed/{ticket_id}?key={key}")
    return True


def main():
    while True:
        try:
            if not run_once():
                time.sleep(POLL_SECONDS)
        except Exception as error:
            print(f"W3 bot error: {error}", flush=True)
            time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
