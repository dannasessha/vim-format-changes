" the directory of this vim file should match the
" buffer's filetype selected in ftdetect...
" currently only designed for linux + bash + C++ 
"
" the plugin relies on accurate, normative file extensions! 
" this plugin sets the 'filetype' options to cpp (C++) for 
" *.cpp , *.c, *.cxx, *.h and *.hpp on buffer read (BufRead)
" or creating a new file matching those extensions (BufNewFile).
" The same file types will have the plugin's logic (accessing git's 
" database and then a selective clang-format run on them) 
" on write (BufWritePost).
"
" this plugin does not provide protections from files which 
" have mismatched languages and extensions.
"
" the plugin uses `job-id`s to handle calls to the command line.
" `job-id`s share "key space" with `channel-id`s which can be used
" to handle io tasks. Therefore it is not advised to use this plugin 
" in combination with a vim session that uses other `channel-id`s,
" as unexpected behavior may result.
"
" Dependency: 
" git in PATH
" clang-format in PATH
" ...(and for testing): 
" Plug 'https://github.com/junegunn/vader.vim'

function! FindTotalLines() abort
  let l:filesummary = execute('file')
  let l:startnumberindex = match(l:filesummary, '\v\d{1,10}\s{1}lines=\s{1}--')
  let l:endnumberindex = matchend(l:filesummary, '\v".+"\s\d{1,10}')
  return str2nr(strpart(l:filesummary, str2nr(l:startnumberindex), (str2nr(l:endnumberindex) - str2nr(l:startnumberindex))))
endfunction

" produce a list populated by a complete line-by-line output 
" of who authored which line in the file open in the current buffer.
" The -M option can be customized (like -M[<num>]) 
" where num is the lower bound on the 
" alphanumeric characters that Git must detect as
" moving/copying within a file for it to associate those
" lines with the parent commit, Default 20, 
" according to git annotate docs.
function! IngestGitAnnotate() abort
  let l:annotatedlines = systemlist('git annotate --line-porcelain -M ' . @%)
  return l:annotatedlines
endfunction

function! CollectUncommittedLines(annotatedlines) abort
  let l:uncommittedlines = []
  " collect uncommittedlines lines
  for l:line in a:annotatedlines
    if match(l:line, '\v0000000000000000000000000000000000000000\s\d{1,10}\s\d{1,10}') == 0
      call add(l:uncommittedlines, l:line) 
    endif
  endfor
  return l:uncommittedlines
endfunction

function! CollectCommittedLines(annotatedlines) abort
  let l:committedlines = []
  let l:hashline = []
  let l:detectcommitted = v:false
  " collect committed line hashes and their content in a list (committedlines)
  " of tuple-like lists (hashline).
  for l:line in a:annotatedlines
    " detect content line, complete, write, and reset hashline.
    if l:detectcommitted == v:true
      if match(l:line, '\v\t') == 0
      call add(l:hashline, l:line)
      call add(l:committedlines, l:hashline)
      let l:hashline = []
      endif
    endif
    " detect a commitedline
    if match(l:line, '\v0000000000000000000000000000000000000000\s\d{1,10}\s\d{1,10}') != 0 && match(l:line, '\v\x{40}\s\d{1,10}\s\d{1,10}') == 0
      call add(l:hashline, l:line)
      let l:detectcommitted = v:true
    " detect uncommittedline to reset detection bit
    elseif match(l:line, '\v0000000000000000000000000000000000000000\s\d{1,10}\s\d{1,10}') == 0
      let l:detectcommitted = v:false
    endif
  endfor
  return l:committedlines
endfunction

"  process output (clean) to only retain line numbers
function! CleanLines(uncommittedlines) abort
  let l:clean = []
  for l:entry in a:uncommittedlines
    " find beginning and ending indices (byte offset)
    " of line number in uncommittedlines 
    let l:startindex = matchend(l:entry, '\v0000000000000000000000000000000000000000\s\d*\s')
    let l:endindex = matchend(l:entry, '\v0000000000000000000000000000000000000000\s\d*\s\d*')
    " coerce strings to numbers for calculating indices
    " and to record line numbers in l:clean
    let l:linenumber = str2nr(strpart(l:entry, str2nr(l:startindex), (str2nr(l:endindex) - str2nr(l:startindex))))
    " with no match the result is 0.
    " defense in case uncommittedlines is given 
    " invalid input, or l:linenumber is not a number
    if l:linenumber != 0 && type(l:linenumber) == v:t_number
      call add(l:clean, l:linenumber)
    else
      echoerr 'Problem with linenumber!'
    endif
    unlet l:entry
  endfor
  " clean is now a list of uncommitted line numbers

  " defensive check in case cleanedlines is in wrong order 
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
        " this means the range in temp is complete!
        " add the temp list (pair of numbers) to range
        call add(l:range, l:temp)
        let l:temp = []
        call add(l:temp, l:line)
      endif
    else 
      echoerr 'Something went wrong. temp should have 0, 1, or 2 items'
    endif
    unlet l:line
  endfor
  " now every line has been evaluated, but we still need
  " to cleanup uneven ranges.
  if len(l:temp) == 1
    " the last line is a range of its own.
    call add(l:temp, l:temp[0])
    call add(l:range, l:temp)
  elseif len(l:temp) == 2
    " the last line completed a range
    call add(l:range, l:temp)
  endif
  return l:range
endfunction

function! MakeArguments(ranges) abort
  let b:args = ' --style=file --sort-includes=false'
  for l:range in a:ranges 
    let b:args .= printf(' --lines=%d:%d', l:range[0], l:range[1])
  endfor
  " style options are currently left to the user to handle
  let b:filename = expand('%')
  let b:args .= printf(' -i %s', b:filename) 
  return b:args
endfunction

function! FormatChanges() abort
  let g:totallines = FindTotalLines()
  let g:annotatedlines = IngestGitAnnotate()
  let b:notcommittedlines = CollectUncommittedLines(deepcopy(g:annotatedlines))
  " if no ranges, stop.
  if b:notcommittedlines == []
    return
  endif
  " cleanedlines is _uncommitted_ cleanedlines
  " TODO rename
  let b:cleanedlines = CleanLines(b:notcommittedlines)
  let g:committedlines = CollectCommittedLines(deepcopy(g:annotatedlines))
  if g:totallines != (len(g:committedlines) + len(b:notcommittedlines))
    echoerr 'error! committedlines + notcommittedlines should equal totallines' 
  endif
  let g:ranges = CreateRanges(b:cleanedlines)
  let g:arguments = MakeArguments(g:ranges)
  function! s:Event(job_id, data, event) dict
    if a:event == 'exit'
      let g:str = 'good evening and good night'
      "suspicion: it is running more than once.
      "the next line is the culprit (again.) 
      "Does this command need a handler, or to be swapped out?
      :e!
      call s:CheckUncommitted()
    else
      echoerr 'error! condition other than exit'
    endif
  endfunction
  let s:callbacks = { 'on_exit': function('s:Event') } 
  call jobstart(('clang-format' . g:arguments), s:callbacks)

  function! s:CheckUncommitted() abort
    "make tuple-like lists to check
    let g:checkannotatedlines = IngestGitAnnotate()
    let g:checkcommittedlines = CollectCommittedLines(deepcopy(g:checkannotatedlines))
    if g:checkcommittedlines != g:committedlines
      echoerr 'ERROR!!! committedlines changed (strong assert)' . string(g:checkcommittedlines) . ' != ' . string(g:committedlines)
    else
      let g:endmessage = 'success with check'
    endif
  endfunction
endfunction

augroup CPP
autocmd BufWritePost *.h call FormatChanges() 
autocmd BufWritePost *.c call FormatChanges()
autocmd BufWritePost *.cxx call FormatChanges()
autocmd BufWritePost *.hpp call FormatChanges()
autocmd BufWritePost *.cpp call FormatChanges() | augroup END

" TODO: 
" finish tests
" move code to more noramtive dirs
" add functionality for python
" add support for other clang-format targets?
" logo
