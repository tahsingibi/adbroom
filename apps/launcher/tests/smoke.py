#!/usr/bin/env python3
"""Integration test on a disposable emulator, never a physical TV."""
import argparse
import pathlib
import re
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('--adb', required=True)
parser.add_argument('--serial', default='emulator-5580')
args = parser.parse_args()
assert re.fullmatch(r'emulator-\d+', args.serial), 'Use a disposable emulator only'
root = pathlib.Path(__file__).resolve().parents[3]
base = [args.adb, '-s', args.serial]

def adb(*command):
    result = subprocess.run(base + list(command), text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=40)
    if result.returncode:
        raise AssertionError(result.stdout)
    return result.stdout

def shell(command):
    return adb('shell', command)

for attempt in range(30):
    try:
        if shell('getprop sys.boot_completed').strip() == '1':
            break
    except AssertionError:
        pass
    time.sleep(2)
else:
    raise AssertionError('Emulator did not finish booting')

assert 'Success' in adb('install', '-r', str(root / 'build/launcher/ADBroomLauncher.apk'))
shell('input keyevent KEYCODE_WAKEUP')
shell('wm dismiss-keyguard')
shell('settings put system system_locales en-US')
start = shell('am start -W -n io.github.adbroom.launcher/.HomeActivity')
assert 'Status: ok' in start, start
print('Cold launch:', start.strip(), flush=True)
uri = 'content://io.github.adbroom.launcher.order/apps'

def snapshot():
    text = shell(f'content query --user 0 --uri {uri}')
    rows = re.findall(r'package=([A-Za-z0-9_.]+), label64=([^,]*), revision=(\d+)', text)
    assert rows and rows[0][0] == '__meta__', text
    revisions = {int(row[2]) for row in rows}
    assert len(revisions) == 1
    return [row[0] for row in rows[1:]], revisions.pop()

order, revision = snapshot()
assert len(order) > 1, order
reversed_order = list(reversed(order))
command = f"content call --user 0 --uri {uri} --method setOrder --arg '{revision}:{','.join(reversed_order)}'"
assert 'status=ok' in shell(command)
assert snapshot() == (reversed_order, revision + 1)
assert 'status=conflict' in shell(command), 'Stale writes must not overwrite TV order'
assert snapshot() == (reversed_order, revision + 1)
shell('am force-stop io.github.adbroom.launcher')
shell('am start -W -n io.github.adbroom.launcher/.HomeActivity')
time.sleep(2)
assert snapshot() == (reversed_order, revision + 1), 'Order must survive process restart'
# Native D-pad editing: reset selection, then Menu starts a transaction; OK commits it.
shell('input keyevent KEYCODE_BACK')
shell('input keyevent KEYCODE_MENU')
shell('input keyevent KEYCODE_DPAD_RIGHT')
shell('input keyevent KEYCODE_DPAD_CENTER')
time.sleep(1)
moved, moved_revision = snapshot()
assert moved_revision == revision + 2, (moved, moved_revision)
assert moved != reversed_order and set(moved) == set(order), 'D-pad must reorder the selected app'
# Back cancels the current edit without changing persisted state.
shell('input keyevent KEYCODE_MENU')
shell('input keyevent KEYCODE_DPAD_LEFT')
shell('input keyevent KEYCODE_BACK')
assert snapshot() == (moved, moved_revision)
# A Mac write while TV editing cancels the local transaction and updates the UI.
shell('input keyevent KEYCODE_MENU')
shell('input keyevent KEYCODE_DPAD_RIGHT')
external_order = list(reversed(moved))
external_command = f"content call --user 0 --uri {uri} --method setOrder --arg '{moved_revision}:{','.join(external_order)}'"
assert 'status=ok' in shell(external_command)
time.sleep(1)
assert snapshot() == (external_order, moved_revision + 1)
shell('input keyevent KEYCODE_BACK')
assert snapshot() == (external_order, moved_revision + 1)
# Hold OK opens app options; Back closes them without launching the app.
shell('input keyevent --longpress KEYCODE_DPAD_CENTER')
time.sleep(0.3)
shell('uiautomator dump /sdcard/adbroom-test-window.xml')
layout = shell('cat /sdcard/adbroom-test-window.xml')
assert 'Move / rearrange' in layout and ('Add favorite' in layout or 'Remove favorite' in layout), 'Hold OK should open app options'
shell('input keyevent KEYCODE_BACK')
assert snapshot() == (external_order, moved_revision + 1)
# HOME resolution works without disabling the stock launcher.
assert 'Success' in shell('cmd package set-home-activity --user current io.github.adbroom.launcher/.HomeActivity')
resolved = shell('cmd package resolve-activity --brief --user current -a android.intent.action.MAIN -c android.intent.category.HOME')
assert 'io.github.adbroom.launcher/' in resolved, resolved
shell('input keyevent KEYCODE_HOME')
shell('am start -W -n io.github.adbroom.launcher/.HomeActivity')
# Take an artifact for visual review.
with open('/private/tmp/adbroom-launcher-screen.png', 'wb') as output:
    subprocess.run(base + ['exec-out', 'screencap', '-p'], stdout=output, check=True, timeout=20)
crashes = shell('logcat -d -b crash -t 100')
assert 'Process: io.github.adbroom.launcher' not in crashes, crashes
print(f'PASS: {len(order)} apps; bridge writes, stale-write protection, process persistence, D-pad save/cancel, HOME resolution', flush=True)
