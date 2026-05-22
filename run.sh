#!/usr/bin/env bash
# Проверяет наличие ключа Яндекс Карт в android/local.properties и запускает приложение.
# Ключ используется в build.gradle.kts → BuildConfig → MainApplication (нативно).
set -e

PROPS="android/local.properties"
get_prop() { grep "^$1=" "$PROPS" | cut -d'=' -f2-; }

YANDEX_KEY=$(get_prop "yandex.maps.api.key")

if [ -z "$YANDEX_KEY" ] || [ "$YANDEX_KEY" = "YOUR_KEY_HERE" ]; then
  echo "❌ Укажи yandex.maps.api.key в android/local.properties"
  exit 1
fi

flutter run \
  --dart-define=BASE_URL=https://api.hookahorder.ru \
  --dart-define=APP_VERSION=dev \
  "$@"
