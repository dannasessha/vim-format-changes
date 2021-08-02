"  this filename should match the buffer's filetype selected in ftdetect

"  produce a list populated by a complete line-by-line output 
"  of who authored which line in the file open in the current buffer.
"  The -M option can be customized (like -M[<num>]) 
"  where num is the lower bound on the 
"  alphanumeric characters that Git must detect as
"  moving/copying within a file for it to associate those
"  lines with the parent commit, Default 20, 
"  according to git annotate docs 
"
"  TODO: check for external plugins
"
"  Dependencies : 
"  Plug 'https://github.com/junegunn/vader.vim'
"  Plug 'https://github.com/rhysd/vim-clang-format.git'

function! IngestGitAnnotate() abort
  let l:annotatedlines = systemlist('git annotate --line-porcelain -M ' . @%)
  return l:annotatedlines
endfunction

function! CollectUncommittedLines(annotatedlines) abort
  let l:uncommittedlines = []
  "  collect uncommittedlines lines
  for l:line in a:annotatedlines
    if match(l:line, '0000000000000000000000000000000000000000 ') == 0
      call add(l:uncommittedlines, l:line) 
    endif
  endfor
  return l:uncommittedlines
endfunction

"  process output (clean) to only retain line numbers
function! CleanLines(uncommittedlines) abort
  let l:clean = []
  for l:entry in a:uncommittedlines
    " find beginning and ending indices (byte offset)
    " of line number in uncommittedlines 
    let l:startindex = matchend(l:entry, '\v0000000000000000000000000000000000000000\s\d*\s')
    let l:endindex = matchend(l:entry, '\v0000000000000000000000000000000000000000\s\d*\s\d*')
    "  coerce strings to numbers for calculating indices
    "  and to record line numbers in l:clean
    let l:linenumber = str2nr(strpart(l:entry, str2nr(l:startindex), (str2nr(l:endindex) - str2nr(l:startindex))))
    " with no match the result is 0.
    " this if is defense in case uncommittedlines is given 
    " invalid input or l:linenumber is not a number
    if l:linenumber != 0 && type(l:linenumber) == v:t_number
      call add(l:clean, l:linenumber)
    else
      echoerr 'Problem with linenumber!'
    endif
    unlet l:entry
  endfor
  "  clean is now a list of uncommitted line numbers

  " defense check in case cleanedlines is in wrong order 
  " aka invalid input
  let l:lastline = 0
  for l:line in l:clean
    if l:line <= l:lastline
      echoerr 'Invalid Input! cleanedlines are out of order or duplicated'
    endif
    let l:lastline = deepcopy(l:line)
  endfor
  return l:clean
endfunction

function! CreateRanges(cleanedlines) abort
  let l:range = []
  let l:temp = []
  for l:line in a:cleanedlines
    if l:temp == [] 
      call add(l:temp, l:line)
    elseif len(l:temp) == 1
      if l:line == l:temp[0] + 1
        call add(l:temp, l:line)
      else 
        " the next number represents a new range.
        " Therefore, a range must be entered...
        call add(l:range, [l:temp[0], l:temp[0]])
        " and a new one begun.
        let l:temp = []
        call add(l:temp, l:line)
        endif
    elseif len(l:temp) == 2
      if l:line == l:temp[1] + 1
        " this line number represents a continuation
        " of the range being built.
        let l:temp[1] = l:line
      else
        "this means the range in temp is complete!
        "add the temp list (pair of numbers) to range
        call add(l:range, l:temp)
        let l:temp = []
        call add(l:temp, l:line)
      endif
    else 
      echoerr 'Something went wrong. temp should have 0, 1, or 2 items'
    endif
  endfor
  "  now every line has been evaluated, but we still need
  "  to cleanup uneven ranges.
  if len(l:temp) == 1
    "the last line is a range of its own.
    call add(l:temp, l:temp[0])
    call add(l:range, l:temp)
  elseif len(l:temp) == 2
    "the last line completed a range
    call add(l:range, l:temp)
  endif
  return l:range
endfunction

function! FormatChanges() abort
  let l:annotatedlines = IngestGitAnnotate()
  let l:notcommittedlines = CollectUncommittedLines(l:annotatedlines)
  let l:cleanedlines = CleanLines(l:notcommittedlines)
  let l:ranges = CreateRanges(l:cleanedlines)
  let l:reversedranges = reverse(deepcopy(l:ranges))
  for l:range in l:reversedranges 
    call clang_format#replace(l:range[0], l:range[1]) 
  endfor
endfunction

" TODO: change hook from load to write<?>
call FormatChanges()
