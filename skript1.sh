#!/bin/bash
set -euo pipefail   #защищает программу от бесполезной работы
LOG="${1:-}"
LIMIT="${2:-70}"
MAX="${3:-500}"
BACKUP="${4:-backup}"
if [ -z "$LOG" ]; then 
echo "Не указана папка с логами!"
echo "Использование: ./skript1.sh <папка_логов> [порог%] [макс_размер] [папка_архивов]"
exit 1
fi

if [ ! -d "$LOG" ]; then
echo "Ошибка: папка '$LOG' не существует!"
exit 1
fi

mkdir -p "$BACKUP"
SIZE=$(du -sm "$LOG"| awk '{print $1}')
PERCENT=$((100 * SIZE / MAX))

echo "Папка логов: $LOG"
echo "Размер: ${SIZE} МБ (${PERCENT}% из ${MAX} МБ)"
echo "Лимит: ${LIMIT}%"

if [ "$PERCENT" -lt "$LIMIT" ]; then
echo "Архивация не требуется"
exit 0
fi

echo "Папка заполнена более чем на ${LIMIT}%"

FILES=$(ls -ltr "$LOG" | awk '{print $9}')

to_archive=""
removed_size=0
for f in $FILES; do
  [ -z "$f" ] && continue
  s=$(du -sm "$LOG/$f" | awk '{print $1}')
  to_archive="$to_archive $f"
  removed_size=$((removed_size + s))
  new_percent=$((100 * (SIZE - removed_size) / MAX))
  if [ "$new_percent" -lt "$LIMIT" ]; then
    break
  fi
done

if [ -z "$to_archive" ]; then
  echo "Нет подходящих файлов для архивации."
  exit 0
fi

# Создаём архив (LAB1_MAX_COMPRESSION=1)
TIME=$(date +%Y%m%d_%H%M%S)

COMPRESS_FLAG="-z"
ARCH_EXT="tar.gz"

if [ "${LAB1_MAX_COMPRESSION:-0}" = "1" ]; then
  if tar --help 2>/dev/null | grep -q -- '--lzma'; then
    COMPRESS_FLAG="--lzma"
    ARCH_EXT="tar.lzma"
  elif command -v lzma >/dev/null 2>&1; then
    COMPRESS_FLAG="--use-compress-program=lzma"
    ARCH_EXT="tar.lzma"
  else
    echo "Предупреждение: LZMA недоступен, используем gzip."
    COMPRESS_FLAG="-z"
    ARCH_EXT="tar.gz"
  fi
fi

ARCHIVE="$BACKUP/archive_$TIME.$ARCH_EXT"

echo "Архивирование файлов: $to_archive"
tar c $COMPRESS_FLAG -f "$ARCHIVE" -C "$LOG" $to_archive
echo "Архив создан: $ARCHIVE"
echo "Удаление заархивированных файлов"
for f in $to_archive; do
  rm -f "$LOG/$f"
done

echo "Удаление завершено"

NEW_SIZE=$(du -sm "$LOG" | awk '{print $1}')
NEW_PERCENT=$((100 * NEW_SIZE / MAX))

echo "Новый размер: ${NEW_SIZE} МБ (${NEW_PERCENT}% из ${MAX} МБ)"
echo "Архивация завершена"
