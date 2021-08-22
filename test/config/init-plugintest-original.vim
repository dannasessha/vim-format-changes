" modified from vader helpdocs
" https://github.com/junegunn/vader.vim/blob/6fff477431ac3191c69a3a5e5f187925466e275a/doc/vader.txt#L339
nvim -Nu <(cat << EOF
filetype off
set runtimepath+=~/.vim/bundle/vader.vim
set runtimepath+=~/.vim/bundle/vim-markdown
set runtimepath+=~/.vim/bundle/vim-markdown/after
filetype plugin indent on
syntax enable
EOF) +Vader*
