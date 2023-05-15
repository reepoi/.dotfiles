alias vim='nvim'

export PATH="~/.dotfiles/bin":$PATH
export PATH="~/.local/share/bob/nvim-bin":$PATH

bind '"\C-f":"tmux-sessionizer\n"'

# PUT LAST
eval "$(rtx activate bash)"
