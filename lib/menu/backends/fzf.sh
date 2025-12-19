_menu_backend_select_one_fzf() {
  local prompt="$1" header="$2" result_var="$3"; shift 3
  local selected

  selected="$(printf '%s\n' "$@" | fzf --prompt="$prompt> " --header="$header")" \
    || return 130

  printf -v "$result_var" '%s' "$selected"
}

_menu_backend_select_many_fzf() {
  local prompt="$1" header="$2" result_var="$3"; shift 3
  local -a selected

  mapfile -t selected < <(
    printf '%s\n' "$@" | fzf --multi --prompt="$prompt> " --header="$header"
  ) || return 130

  printf -v "$result_var" '%s\n' "${selected[@]}"
}
