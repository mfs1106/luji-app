import json, datetime

# 从 package_config.json 拿每个包的真实路径（rootUri），保证指向实际存在的目录
with open('D:/systemDir/Desktop/手机app/luji_app/.dart_tool/package_config.json', encoding='utf-8') as f:
    pc = json.load(f)
root = {p['name']: p['rootUri'] for p in pc['packages']}

def hosted_path(name):
    """file:///C:/x/y -> C:\\\\x\\\\y （注册表用的 Windows 双反斜杠格式）"""
    uri = root[name]
    assert uri.startswith('file:///'), f'{name}: {uri}'
    p = uri[len('file://'):]  # /C:/x/y
    p = p.lstrip('/')          # C:/x/y
    return p.replace('/', chr(92) * 2)  # C:\\x\\y

LOCAL = 'D:' + chr(92) * 2 + 'systemDir' + chr(92) * 2 + 'Desktop' + chr(92) * 2 + '手机app' + chr(92) * 2 + 'luji_app' + chr(92) * 2 + 'third_party' + chr(92) * 2 + 'amap_flutter_map_plus_x' + chr(92) * 2

def entry(name, native=True, deps=None, local=False):
    return {
        'name': name,
        'path': LOCAL if local else hosted_path(name),
        'native_build': native,
        'dependencies': deps or [],
        'dev_dependency': False,
    }

plugins = {
    'ios': [
        entry('amap_flutter_map_plus_x', local=True),
        entry('flutter_local_notifications'),
        entry('geolocator_apple'),
        entry('image_picker_ios'),
        entry('path_provider_foundation', native=False),
        entry('shared_preferences_foundation'),
        entry('sqflite_darwin'),
        entry('url_launcher_ios'),
    ],
    'android': [
        entry('amap_flutter_map_plus_x', deps=['flutter_plugin_android_lifecycle'], local=True),
        entry('flutter_local_notifications'),
        entry('flutter_plugin_android_lifecycle'),
        entry('geolocator_android'),
        entry('image_picker_android', deps=['flutter_plugin_android_lifecycle']),
        entry('jni'),
        entry('jni_flutter', deps=['jni']),
        entry('path_provider_android', native=False, deps=['jni', 'jni_flutter']),
        entry('shared_preferences_android', deps=['jni']),
        entry('sqflite_android'),
        entry('url_launcher_android'),
    ],
    'macos': [
        entry('file_selector_macos'),
        entry('flutter_local_notifications'),
        entry('geolocator_apple'),
        entry('image_picker_macos', native=False),
        entry('path_provider_foundation', native=False),
        entry('shared_preferences_foundation'),
        entry('sqflite_darwin'),
        entry('url_launcher_macos'),
    ],
    'linux': [
        entry('file_selector_linux'),
        entry('flutter_local_notifications_linux', native=False),
        entry('image_picker_linux', native=False),
        entry('jni'),
        entry('jni_flutter'),
        entry('path_provider_linux', native=False),
        entry('url_launcher_linux'),
    ],
    'windows': [
        entry('file_selector_windows'),
        entry('geolocator_windows'),
        entry('image_picker_windows', native=False),
        entry('jni'),
        entry('jni_flutter'),
        entry('path_provider_windows', native=False),
        entry('shared_preferences_windows'),
        entry('url_launcher_windows'),
    ],
    'web': [
        entry('geolocator_web'),
        entry('image_picker_for_web'),
        entry('shared_preferences_web'),
        entry('url_launcher_web'),
    ],
}

dependency_graph = [
    ('amap_flutter_map_plus_x', ['flutter_plugin_android_lifecycle']),
    ('file_selector_linux', []), ('file_selector_macos', []), ('file_selector_windows', []),
    ('flutter_local_notifications', ['flutter_local_notifications_linux']),
    ('flutter_local_notifications_linux', []),
    ('flutter_plugin_android_lifecycle', []),
    ('geolocator', ['geolocator_android', 'geolocator_apple', 'geolocator_web', 'geolocator_windows']),
    ('geolocator_android', []), ('geolocator_apple', []), ('geolocator_web', []), ('geolocator_windows', []),
    ('image_picker', ['image_picker_android', 'image_picker_for_web', 'image_picker_ios', 'image_picker_linux', 'image_picker_macos', 'image_picker_windows']),
    ('image_picker_android', ['flutter_plugin_android_lifecycle']),
    ('image_picker_for_web', []), ('image_picker_ios', []), ('image_picker_linux', []), ('image_picker_macos', []), ('image_picker_windows', []),
    ('jni', []), ('jni_flutter', ['jni']),
    ('path_provider', ['path_provider_android', 'path_provider_foundation', 'path_provider_linux', 'path_provider_windows']),
    ('path_provider_android', ['jni', 'jni_flutter']),
    ('path_provider_foundation', []), ('path_provider_linux', []), ('path_provider_windows', []),
    ('shared_preferences', ['shared_preferences_android', 'shared_preferences_foundation', 'shared_preferences_linux', 'shared_preferences_web', 'shared_preferences_windows']),
    ('shared_preferences_android', ['jni']),
    ('shared_preferences_foundation', []), ('shared_preferences_linux', []), ('shared_preferences_web', []), ('shared_preferences_windows', []),
    ('sqflite', ['sqflite_android', 'sqflite_darwin']),
    ('sqflite_android', []), ('sqflite_darwin', []),
    ('url_launcher', ['url_launcher_android', 'url_launcher_ios', 'url_launcher_linux', 'url_launcher_macos', 'url_launcher_web', 'url_launcher_windows']),
    ('url_launcher_android', []), ('url_launcher_ios', []), ('url_launcher_linux', []), ('url_launcher_macos', []), ('url_launcher_web', []), ('url_launcher_windows', []),
]

data = {
    'info': 'This is a generated file; do not edit or check into version control.',
    'plugins': plugins,
    'dependencyGraph': [{'name': n, 'dependencies': d} for n, d in dependency_graph],
    'date_created': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f'),
    'version': '3.47.7',
    'swift_package_manager_enabled': {'ios': False, 'macos': False},
}

out = 'D:/systemDir/Desktop/手机app/luji_app/.flutter-plugins-dependencies'
with open(out, 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

# 验证：所有路径目录真实存在
import os
missing = []
for plat, plist in plugins.items():
    for p in plist:
        real = p['path'].replace(chr(92) * 2, '/')
        if not os.path.isdir(real):
            missing.append(p['name'])
print('android 插件数:', len(plugins['android']))
print('ios 插件数:', len(plugins['ios']))
print('缺失目录的插件:', missing if missing else '无（全部路径有效）')
assert not missing and len(plugins['android']) == 11
print('OK: 完整注册表重建完成')
