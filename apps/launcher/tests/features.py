#!/usr/bin/env python3
"""Feature regression tests. Only use a disposable emulator; touches its launcher profile."""
import argparse
import base64
import json
import pathlib
import re
import subprocess
import time
import xml.etree.ElementTree as ET

parser=argparse.ArgumentParser()
parser.add_argument('--adb',required=True)
parser.add_argument('--serial',default='emulator-5580')
args=parser.parse_args()
assert re.fullmatch(r'emulator-\d+',args.serial),'Disposable emulators only'
base=[args.adb,'-s',args.serial]
uri='content://io.github.adbroom.launcher.order/'

def adb(*parts):
    r=subprocess.run(base+list(parts),text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=40)
    assert r.returncode==0,r.stdout
    return r.stdout

def shell(command):return adb('shell',command)

def read_config():
    text=shell(f'content query --user 0 --uri {uri}settings')
    match=re.search(r'config64=([^,]+), revision=(\d+)',text)
    assert match,text
    return json.loads(base64.b64decode(match[1])),int(match[2])

def read_order():
    text=shell(f'content query --user 0 --uri {uri}apps')
    rows=re.findall(r'package=([A-Za-z0-9_.]+), label64=([^,]*), revision=(\d+)',text)
    return [row[0] for row in rows if row[0]!='__meta__'],{row[0]:base64.b64decode(row[1]).decode() for row in rows if row[0]!='__meta__'}

def save(config,order,revision):
    profile=base64.b64encode(json.dumps({'settings':config,'order':order},ensure_ascii=False).encode()).decode()
    return shell(f"content call --user 0 --uri {uri}apps --method setProfile --arg '{revision}:{profile}'")

def layout():
    shell('uiautomator dump /sdcard/adbroom-features.xml')
    return ET.fromstring(shell('cat /sdcard/adbroom-features.xml'))

def click(text,exact=False):
    for attempt in range(14):
        tree=layout()
        for node in tree.iter('node'):
            label=node.get('text','')
            if label==text or (not exact and label.startswith(text+'\n')):
                bounds=list(map(int,re.findall(r'\d+',node.get('bounds',''))))
                if len(bounds)==4 and bounds[2]>bounds[0] and bounds[3]>bounds[1] and 100<bounds[1]<960:
                    shell(f'input tap {(bounds[0]+bounds[2])//2} {(bounds[1]+bounds[3])//2}')
                    time.sleep(.25)
                    return
        # Native ScrollView does not virtualize rows; off-screen app preferences
        # must be brought into view just as they would be with the TV remote.
        shell('input swipe 1600 850 1600 400 200' if attempt<7 else 'input swipe 1600 400 1600 850 200')
    raise AssertionError('Missing UI target '+text+'; '+str([(n.get('text')) for n in tree.iter('node') if n.get('text')]))

def screen(path):
    with open(path,'wb') as output:subprocess.run(base+['exec-out','screencap','-p'],stdout=output,check=True,timeout=20)

# Start from a known profile without removing app data or breaking the signing/update test.
config,revision=read_config()
order,names=read_order()
assert len(order)>=4
config.update(layout='grid',language='en',columns=5,theme='forest',accent='blue',cardStyle='banner',profileName='Living room',
              showClock=False,showDate=True,showMedia=False,showSideloaded=True,
              favorites=[order[0]],hidden=[order[-1]],labels={order[0]:'Cinema TV',order[-1]:'Hidden app 999'},groups={order[0]:'Video',order[1]:'Video'})
assert 'status=ok' in save(config,order,revision)
config_after,next_revision=read_config()
assert config_after==config and next_revision==revision+1
assert 'status=conflict' in save(config,order,revision),'Profile writes must share revision protection'
_,labels=read_order()
assert labels[order[0]]=='Cinema TV' and labels[order[-1]]=='Hidden app 999'
invalid=dict(config,columns=9)
assert 'status=ok' not in save(invalid,order,next_revision)
assert read_config()==(config,next_revision),'Invalid settings must not mutate the profile'
shell('am force-stop io.github.adbroom.launcher')
shell('am start -W -n io.github.adbroom.launcher/.HomeActivity')
time.sleep(1)
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'Cinema TV' in text and 'Hidden app 999' not in text and 'Video' in text and 'Hello, Living room' in text,text
screen('/private/tmp/adbroom-launcher-grid.png')
print('PASS: atomic settings, aliases, favorites, hidden apps, folders, validation, profile persistence',flush=True)

# Native TV settings must be reachable from Home, and a toggle must persist back to Mac.
click('Settings',True)
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'Appearance' in text and 'Parental controls' in text and 'Device &amp; about' in text,text
screen('/private/tmp/adbroom-launcher-settings.png')
click('Modules',True)
click('Clock')
time.sleep(.4)
assert read_config()[0]['showClock'] is True,'TV setting must update the ADB-readable profile'
click('Applications',True)
time.sleep(.4)
click('Hidden app 999')
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'Show on home' in text,'Hidden apps must remain manageable in settings'
shell('input keyevent KEYCODE_BACK')
click('Home screen',True)
click('Layout')
click('Horizontal row',True)
time.sleep(.4)
assert read_config()[0]['layout']=='row'
shell('input keyevent KEYCODE_BACK')
time.sleep(1)
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'android.widget.Gallery' in text,'Row layout must use a recycled horizontal view'
screen('/private/tmp/adbroom-launcher-row.png')
print('PASS: native settings navigation, TV-to-Mac toggle persistence, hidden-app recovery, horizontal layout',flush=True)

# PIN setup is a TV-only flow. The exported profile must never include PIN material.
click('Settings',True)
click('Parental controls',True)
tree=layout();text=ET.tostring(tree,encoding='unicode')
if 'Set 4-digit PIN' in text:
    click('Set 4-digit PIN',True)
    shell('input text 1234');click('OK',True)
    shell('input text 1234');click('OK',True)
    time.sleep(1)
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'Change PIN' in text and 'Remove PIN and all locks' in text,text
# App locks must also gate favorite shortcuts, not only grid tiles.
click('Applications',True)
click('Cinema TV')
menu_text=ET.tostring(layout(),encoding='unicode')
if 'Lock with PIN' in menu_text:
    click('Lock with PIN',True)
    shell('input text 1234');click('OK',True)
    # PIN hashing intentionally runs off the UI thread; let verification finish
    # before navigating away (leaving the Activity cancels the pending action).
    time.sleep(1)
else:
    assert 'Remove PIN lock' in menu_text
    shell('input keyevent KEYCODE_BACK')
shell('input keyevent KEYCODE_BACK')
time.sleep(.4)
click('★ Cinema TV',True)
assert 'Parental PIN' in ET.tostring(layout(),encoding='unicode'),'Locked favorites must require PIN'
click('CANCEL',True)
click('Settings',True);click('Parental controls',True)
click('Protect settings and editing')
shell('input text 1234');click('OK',True)
time.sleep(.7)
shell('input keyevent KEYCODE_BACK')
time.sleep(.4)
click('Settings',True)
tree=layout();text=ET.tostring(tree,encoding='unicode')
assert 'Parental PIN' in text,'Protected settings must be gated'
click('CANCEL',True)
# Clean up the optional protection through the real UI so the smoke test can be repeated.
click('Settings',True);shell('input text 1234');click('OK',True)
click('Parental controls',True)
click('Remove PIN and all locks',True);shell('input text 1234');click('OK',True)
time.sleep(.4)
exported,_=read_config()
assert not any('pin' in key.lower() or 'salt' in key.lower() or 'hash' in key.lower() for key in exported)
shell('input keyevent KEYCODE_BACK')
print('PASS: PIN setup, protected settings, cancellation, PIN removal, private credential isolation',flush=True)

# Enabling a module does not silently grant its sensitive system permission.
current,rev=read_config()
current['showMedia']=True
assert 'status=ok' in save(current,order,rev)
time.sleep(.3)
text=ET.tostring(layout(),encoding='unicode')
assert 'Last media · enable access' in text,'Missing media permission must have a safe UI fallback'
# Restore simple defaults and original ordering for repeatable test runs.
current,rev=read_config()
current.update(layout='grid',language='system',columns=6,theme='midnight',accent='sage',cardStyle='icon',profileName='',
               showClock=True,showMedia=False,favorites=[],hidden=[],labels={},groups={})
assert 'status=ok' in save(current,order,rev)
crashes=shell('logcat -d -b crash -t 100')
assert 'Process: io.github.adbroom.launcher' not in crashes,crashes
print('PASS: all launcher feature checks',flush=True)
