#!/bin/bash

MAIN_SCRIPT="./skript1.sh"

ROOT="./test_folder"
LOG="$ROOT/log"
BACKUP="$ROOT/backup"

echo "Начало тестирования $MAIN_SCRIPT"
echo "Рабочая папка: $ROOT"
echo "---------------------------------------------"
prepare() {
  rm -rf "$ROOT"
  mkdir -p "$LOG" "$BACKUP"
}

create_file() {
  size="$1"
  path="$2"
  if command -v mkfile >/dev/null 2>&1; then
    mkfile "${size}m" "$path"
  else
    dd if=/dev/zero of="$path" bs=1M count="$size" status=none
  fi
}

count_archives() { ls -1 "$BACKUP"/*.tar.gz 2>/dev/null | wc -l | awk '{print $1}'; }
count_logs()     { ls -1 "$LOG" 2>/dev/null | wc -l | awk '{print $1}'; }
size_mb()        { du -sm "$LOG" | awk '{print $1}'; }

check_log_size() {
  size=$(size_mb)
  if [ "$size" -lt 500 ]; then
    echo "FAIL: размер LOG = ${size} МБ (< 500 МБ). Тест остановлен."
    exit 1
  fi
}

# ========== ТЕСТ 1 ==========
echo "ТЕСТ 1: Ниже LIMIT — архивации быть не должно"
prepare
create_file 120 "$LOG/t1_1.log"; sleep 1
create_file 120 "$LOG/t1_2.log"; sleep 1
create_file 120 "$LOG/t1_3.log"; sleep 1
create_file 120 "$LOG/t1_4.log"; sleep 1
create_file 120 "$LOG/t1_5.log"
echo "Размер LOG: $(size_mb) МБ"
check_log_size

archives_before=$(count_archives)
logs_before=$(count_logs)
"$MAIN_SCRIPT" "$LOG" 70 2000 "$BACKUP" >"$ROOT/out1.txt" 2>&1
archives_after=$(count_archives)
logs_after=$(count_logs)

if [ "$archives_after" -eq "$archives_before" ] && [ "$logs_after" -eq "$logs_before" ]; then
  echo "Прошло: ниже LIMIT — без изменений"
else
  echo "Не прошло: ожидалось без изменений. Архивы $archives_before->$archives_after, файлы $logs_before->$logs_after"
fi
echo "---------------------------------------------"

# ========== ТЕСТ 2 ==========
echo "ТЕСТ 2: Выше LIMIT — должна быть архивация"
prepare
create_file 120 "$LOG/t2_1.log"; sleep 1
create_file 120 "$LOG/t2_2.log"; sleep 1
create_file 120 "$LOG/t2_3.log"; sleep 1
create_file 120 "$LOG/t2_4.log"; sleep 1
create_file 120 "$LOG/t2_5.log"
echo "Размер LOG: $(size_mb) МБ"
check_log_size

archives_before=$(count_archives)
logs_before=$(count_logs)
"$MAIN_SCRIPT" "$LOG" 70 500 "$BACKUP" >"$ROOT/out2.txt" 2>&1
archives_after=$(count_archives)
logs_after=$(count_logs)

if [ "$archives_after" -ge $((archives_before+1)) ] && [ "$logs_after" -lt "$logs_before" ]; then
  echo "Прошло: архив создан"
else
  echo "Не прошло: ожидался новый архив и уменьшение числа файлов. Архивы $archives_before->$archives_after, файлы $logs_before->$logs_after"
fi
echo "---------------------------------------------"

# ========== ТЕСТ 3 ==========
echo "ТЕСТ 3: Ровно 70%"
prepare
create_file 100 "$LOG/t3_1.log"; sleep 1
create_file 100 "$LOG/t3_2.log"; sleep 1
create_file 100 "$LOG/t3_3.log"; sleep 1
create_file 100 "$LOG/t3_4.log"; sleep 1
create_file 100 "$LOG/t3_5.log"; sleep 1
create_file 100 "$LOG/t3_6.log"; sleep 1
create_file 100 "$LOG/t3_7.log"
echo "Размер LOG: $(size_mb) МБ"
check_log_size

archives_before=$(count_archives)
"$MAIN_SCRIPT" "$LOG" 70 1000 "$BACKUP" >"$ROOT/out3.txt" 2>&1
archives_after=$(count_archives)

if [ "$archives_after" -ge $((archives_before+1)) ]; then
  echo "Прошло: на 70% архив создан"
else
  echo "Не прошло: на 70% архив не создан"
fi
echo "---------------------------------------------"

# ========== ТЕСТ 4 ==========
echo "ТЕСТ 4: BACKUP создаётся автоматически"
prepare
rm -rf "$BACKUP"
mkdir -p "$LOG"
create_file 120 "$LOG/t4_1.log"; sleep 1
create_file 120 "$LOG/t4_2.log"; sleep 1
create_file 120 "$LOG/t4_3.log"; sleep 1
create_file 120 "$LOG/t4_4.log"; sleep 1
create_file 120 "$LOG/t4_5.log"
echo "Размер LOG: $(size_mb) МБ"
check_log_size

"$MAIN_SCRIPT" "$LOG" 70 500 "$BACKUP" >"$ROOT/out4.txt" 2>&1
if [ -d "$BACKUP" ] && [ "$(count_archives)" -ge 1 ]; then
  echo "Прошло: BACKUP создан"
else
  echo "Не прошло: BACKUP не создан или архив отсутствует"
fi
echo "---------------------------------------------"

# ======== ТЕСТ 5 =========
echo "ТЕСТ 5: Проверка переменной LAB1_MAX_COMPRESSION=1"
prepare
create_file 120 "$LOG/t5_1.log"; sleep 1
create_file 120 "$LOG/t5_2.log"; sleep 1
create_file 120 "$LOG/t5_3.log"; sleep 1
create_file 120 "$LOG/t5_4.log"; sleep 1
create_file 120 "$LOG/t5_5.log"
echo "Размер LOG: $(size_mb) МБ"
check_log_size

archives_before=$(count_archives)
LAB1_MAX_COMPRESSION=1 "$MAIN_SCRIPT" "$LOG" 70 500 "$BACKUP" >"$ROOT/out5.txt" 2>&1
archives_after=$(count_archives)

lzma_count=$(ls -1 "$BACKUP"/*.tar.lzma 2>/dev/null | wc -l | awk '{print $1}')

if [ "$lzma_count" -ge 1 ]; then
  echo "Прошло: создан LZMA-архив (.tar.lzma)"
elif [ "$archives_after" -gt "$archives_before" ]; then
  echo "Прошло но: архив создан, но без LZMA (fallback на gzip)"
else
  echo "Не прошло: архив не создан"
fi
echo "---------------------------------------------"

echo "Готово:"
echo "- Архивы в $BACKUP:"
ls -lh "$BACKUP" 2>/dev/null || true
echo "- Содержимое $LOG после последнего теста:"
ls -lh "$LOG" 2>/dev/null || true
