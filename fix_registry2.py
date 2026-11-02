import json, datetime

BS = chr(92)
OLD = 'D:' + BS + BS + 'luji-build'
NEW = 'D:' + BS + BS + 'systemDir' + BS + BS + 'Desktop' + BS + BS + '手机app' + BS + BS + 'luji_app'

path = 'D:/systemDir/Desktop/手机app/luji_app/.flutter-plugins-dependencies'
with open('D:/luji-build/.flutter-plugins-dependencies', encoding='utf-8') as f:
    data = json.load(f)

replaced = 0
for platform, plugins in data['plugins'].items():
    for p in plugins:
        if 'path' in p and OLD in p['path']:
            p['path'] = p['path'].replace(OLD, NEW)
            replaced += 1

data['date_created'] = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')
with open(path, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

with open(path, encoding='utf-8') as f:
    chk = json.load(f)
ap = [p['name'] for p in chk['plugins']['android']]
print('android 插件数:', len(ap))
print('lifecycle 在列:', 'flutter_plugin_android_lifecycle' in ap)
print('amap path:', [p['path'] for p in chk['plugins']['android'] if p['name'] == 'amap_flutter_map_plus_x'][0])
assert len(ap) == 11 and 'flutter_plugin_android_lifecycle' in ap
print('OK: 完整注册表已恢复（11 个 android 插件）')
