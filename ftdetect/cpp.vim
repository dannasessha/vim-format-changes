" vint: -ProhibitAutocmdWithNoGroup
" currently looks for cpp, c, cxx, and h file extensions
autocmd BufRead,BufNewFile *.cpp call s:set_cpp_filetype()
"autocmd BufRead,BufNewFile *.c call s:set_cpp_filetype()
"autocmd BufRead,BufNewFile *.cxx call s:set_cpp_filetype()
"autocmd BufRead,BufNewFile *.h call s:set_cpp_filetype()

function! s:set_cpp_filetype() abort
    if &filetype !=# 'cpp'
        set filetype=cpp
        let b:cppdetected = 1 
    endif
endfunction
