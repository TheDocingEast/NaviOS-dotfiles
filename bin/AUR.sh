#!/bin/bash

# ~/.local/bin/rofi-aur.sh

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-aur"
CACHE_FILE="$CACHE_DIR/packages.list"
REFRESH_FLAG="$CACHE_DIR/.refresh"

mkdir -p "$CACHE_DIR"

# Обновление кэша
update_cache() {
    echo "🔄 Обновление AUR-кэша..." >&2
    # Получаем только имена пакетов из AUR
    yay -Sl --aur 2>/dev/null | awk '{print $2}' | sort > "$CACHE_FILE.tmp" && mv "$CACHE_FILE.tmp" "$CACHE_FILE"
    touch "$REFRESH_FLAG"
}

# Обновляем кэш раз в 24 часа или при отсутствии
if [ ! -f "$CACHE_FILE" ] || [ ! -f "$REFRESH_FLAG" ] || [ "$(find "$REFRESH_FLAG" -mtime +1 2>/dev/null)" ]; then
    update_cache
fi

# Режим запуска: rofi передаёт аргументы
case "$1" in
    -i|--index)
        # Этот режим не используется в нашем случае
        exit 0
        ;;
    *)
        # Без аргументов — выводим список пакетов для rofi
        if [ "$ROFI_RETV" = "0" ]; then
            cat "$CACHE_FILE"
        else
            # Пользователь выбрал элемент → устанавливаем
            selected="$@"
            if [ -n "$selected" ]; then
                # Подтверждение (опционально)
                confirm=$(echo -e "Нет\nДа" | rofi -dmenu -i -p "Установить '$selected'?" -theme-str 'window {width: 20%;}')
                if [ "$confirm" = "Да" ]; then
                    kitty --title "Установка AUR: $selected" sh -c "yay -S --noconfirm '$selected'; echo '✅ Готово. Нажмите Enter...'; read"
                fi
            fi
        fi
        ;;
esac
