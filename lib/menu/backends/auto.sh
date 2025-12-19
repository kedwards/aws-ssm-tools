_menu_backend() {
  if [[ "${MENU_NO_FZF:-0}" == "1" ]]; then
    echo "fallback"
  elif command -v fzf >/dev/null 2>&1; then
    echo "fzf"
  else
    echo "fallback"
  fi
}
