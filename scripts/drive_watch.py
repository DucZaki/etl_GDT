#!/usr/bin/env python3
"""Poll Google Drive for changes and trigger the ETL when the source file moves.

Uses the OAuth refresh token already stored by Apache Hop (StoredCredential), so no
extra secret is required. State (pageToken) is kept in .drive_watch_state.json.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.parse
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_FILE = os.path.join(ROOT, ".drive_watch_state.json")
CRED_FILE = os.environ.get("GDRIVE_CREDENTIALS_FILE",
                            r"C:\Users\minhd\.hop\gdrive\client_secret.json")
# fallback to the location actually used during setup
if not os.path.exists(CRED_FILE):
    CRED_FILE = r"D:\client_secret_246513311175-96ogk6151oifgjn9bm80h8gtb0l059sl.apps.googleusercontent.com.json"
TOKEN_FILE = os.environ.get("GDRIVE_STORED_CREDENTIAL",
                            r"C:\Users\minhd\.hop\gdrive\tokens\StoredCredential")
SOURCE_NAME = os.path.basename(os.environ.get("GDRIVE_SOURCE_PATH", "sample_data_dirty.xlsx"))
INTERVAL = int(os.environ.get("DRIVE_WATCH_INTERVAL_SECONDS", "300"))


def read_refresh_token():
    data = open(TOKEN_FILE, "rb").read()
    idx = data.find(b"1//")
    if idx < 2:
        raise RuntimeError("refresh_token not found in StoredCredential")
    ln = int.from_bytes(data[idx-2:idx], "big")
    return data[idx:idx+ln].decode("latin-1")


def load_creds():
    with open(CRED_FILE) as f:
        c = json.load(f)["installed"]
    return c["client_id"], c["client_secret"]


def http_post(url, data):
    body = urllib.parse.urlencode(data).encode()
    req = urllib.request.Request(url, data=body,
                                headers={"Content-Type": "application/x-www-form-urlencoded"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def http_get(url, token):
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def access_token():
    cid, csec = load_creds()
    rt = read_refresh_token()
    t = http_post("https://oauth2.googleapis.com/token", {
        "client_id": cid, "client_secret": csec,
        "refresh_token": rt, "grant_type": "refresh_token",
    })
    return t["access_token"]


def load_state():
    if os.path.exists(STATE_FILE):
        try:
            return json.load(open(STATE_FILE))
        except Exception:
            return {}
    return {}


def save_state(s):
    with open(STATE_FILE, "w") as f:
        json.dump(s, f)


def get_start_token(tok):
    url = "https://www.googleapis.com/drive/v3/changes/startPageToken"
    return http_get(url, tok)["startPageToken"]


def list_changes(tok, page_token):
    params = {"pageToken": page_token,
              "fields": "nextPageToken,newStartPageToken,changes(fileId,removed,file(name,mimeType))"}
    url = "https://www.googleapis.com/drive/v3/changes?" + urllib.parse.urlencode(params)
    return http_get(url, tok)


def trigger():
    run = os.path.join(ROOT, "scripts", "run.ps1")
    print("TRIGGER: running ETL")
    subprocess.run(["powershell", "-ExecutionPolicy", "Bypass", "-File", run, "-All"],
                   cwd=ROOT, check=False)


def once():
    tok = access_token()
    state = load_state()
    if not state.get("pageToken"):
        pt = get_start_token(tok)
        save_state({"pageToken": pt})
        print("initialized pageToken =", pt)
        return
    pt = state["pageToken"]
    total = 0
    relevant = 0
    while True:
        resp = list_changes(tok, pt)
        for c in resp.get("changes", []):
            total += 1
            f = c.get("file") or {}
            name = f.get("name", "")
            if (not c.get("removed")) and name == SOURCE_NAME:
                relevant += 1
                print("change:", name, c.get("fileId"))
        if resp.get("nextPageToken"):
            pt = resp["nextPageToken"]
            continue
        new_pt = resp.get("newStartPageToken", pt)
        save_state({"pageToken": new_pt})
        break
    print(f"changes={total} relevant={relevant}")
    if relevant:
        trigger()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--once", action="store_true", help="single poll then exit")
    ap.add_argument("--interval", type=int, default=INTERVAL)
    args = ap.parse_args()

    if args.once:
        once()
        return

    print(f"watching Google Drive every {args.interval}s for '{SOURCE_NAME}'")
    while True:
        try:
            once()
        except Exception as e:
            print("ERROR:", repr(e), file=sys.stderr)
        time.sleep(args.interval)


if __name__ == "__main__":
    main()