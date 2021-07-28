"  this filename should match the buffer's filetype selected in ftdetect

"  produce a list populated by a complete line-by-line output 
"  of who authored which line in the file open in the current buffer.
"  The -M option can be customized (like -M[<num>]) 
"  where num is the lower bound on the 
"  alphanumeric characters that Git must detect as
"  moving/copying within a file for it to associate those
"  lines with the parent commit, according to git blame docs 
"
"  TODO : functionalize to be able to test.
"
function! IngestGitBlame() abort
    let blamelist = systemlist('git blame -M ' . @%)
    return blamelist
endfunction

function! CollectUncommitedLines(blamelines) abort
    let blameless = []
"  collect blameless (ie, output lines that have not been committed)
  for blame in a:blamelines
    if match(blame, '00000000 (Not Committed Yet ') == 0
       call add(blameless, blame) 
    endif
  endfor
  return blameless
endfunction

function! CleanLines(uncommitedlines) abort
"  process output lines to only retain line numbers
  let temp = '' 
  let clean = [] 
  for entry in a:uncommitedlines
    let temp = matchstr(entry, '\v\d+\)\ ') 
    call add(clean, str2nr(matchstr(temp, '\v\d+')))
  endfor
"  clean is now a list of altered line numbers
  return clean
endfunction

let blamelines = IngestGitBlame()
let uncommitedlines = CollectUncommitedLines()

" --------------------TESTS-------------------------
"  creating function for confirming Vader tests work
function! Vadertest()
    let testvalue = 'x'
    return testvalue
endfunction
