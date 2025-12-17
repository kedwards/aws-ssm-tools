#!/usr/bin/env bash

is_interactive() {
  [[ -t 0 && -t 1 ]]
}
