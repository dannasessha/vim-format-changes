vim -Nu <(cat << EOF
filetype off
set rtp+=~/.vim/bundle/vader.vim
set rtp+=~/.vim/bundle/vim-markdown
set rtp+=~/.vim/bundle/vim-markdown/after
filetype plugin indent on
syntax enable
EOF) +Vader*
