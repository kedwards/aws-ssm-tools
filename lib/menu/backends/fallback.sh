_menu_backend_select_one_fallback2() {
  local prompt="$1" header="$2" result_var="$3"; shift 3

  echo "$header" >&2
  select choice in "$@"; do
    [[ -n "$choice" ]] || return 130
    printf -v "$result_var" '%s' "$choice"
    return 0
  done
}

_menu_backend_select_one_auto() {
  local prompt="$1"
  local header="$2"
  local result_var="$3"
  shift 3
  local items=("$@")

  # single-item fast path (IMPORTANT)
  if (( ${#items[@]} == 1 )); then
    printf -v "$result_var" '%s' "${items[0]}"
    return 0
  fi

  echo "$header"
  local i=1
  for item in "${items[@]}"; do
    printf "%d) %s\n" "$i" "$item"
    ((i++))
  done

  read -r choice || return 130

  [[ "$choice" =~ ^[0-9]+$ ]] || return 1
  (( choice >= 1 && choice <= ${#items[@]} )) || return 1

  printf -v "$result_var" '%s' "${items[choice-1]}"
}


_menu_backend_select_many_fallback() {
  local prompt="$1" header="$2" result_var="$3"; shift 3

  echo "$header" >&2
  echo "Enter selections (e.g. 1 3 4):" >&2

  read -r -a picks || return 1
  local -a results=()

  for i in "${picks[@]}"; do
    results+=( "${@:i:1}" )
  done

  printf -v "$result_var" '%s\n' "${results[@]}"
}

