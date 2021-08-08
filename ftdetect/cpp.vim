" currently looks for cpp, c, cxx, and h file extensions
augroup CPPDETECT
autocmd BufRead,BufNewFile *.cpp call Set_cpp_filetype()
autocmd BufRead,BufNewFile *.c call Set_cpp_filetype()
autocmd BufRead,BufNewFile *.cxx call Set_cpp_filetype()
autocmd BufRead,BufNewFile *.h call Set_cpp_filetype() 
autocmd BufRead,BufNewFile *.hpp call Set_cpp_filetype() | augroup END

function! Set_cpp_filetype() abort
    if &filetype !=# 'cpp'
        set filetype=cpp
    endif
endfunction
