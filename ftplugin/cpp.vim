"  this filename should match the buffer's filetype selected in ftdetect

"  produce a list populated by a complete line-by-line output 
"  of who authored which line in the file open in the current buffer.
"  The -M option can be customized (like -M[<num>]) 
"  where num is the lower bound on the 
"  alphanumeric characters that Git must detect as
"  moving/copying within a file for it to associate those
"  lines with the parent commit, according to git blame docs 

function! IngestGitBlame() abort
    let blamelist = systemlist('git blame -M ' . @%)
    return blamelist
endfunction

function! CollectUncommittedLines(blamelines) abort
    let blameless = []
"  collect blameless (ie, output lines that have not been committed)
  for blame in a:blamelines
    if match(blame, '00000000 (Not Committed Yet ') == 0
       call add(blameless, blame) 
    endif
  endfor
  return blameless
endfunction

function! CleanLines(uncommittedlines) abort
"  process output lines to only retain line numbers
  let temp = '' 
  let clean = [] 
  for entry in a:uncommittedlines
    let temp = matchstr(entry, '\v\d+\)\ ') 
    call add(clean, str2nr(matchstr(temp, '\v\d+')))
  endfor
"  clean is now a list of altered line numbers
  return clean
endfunction

function! CreateRanges(cleanedlines) abort
    let range = []
    let temp = []
    for line in a:cleanedlines
        if temp == [] 
            call add(temp, line)
        elseif len(temp) == 1
            if line == temp[0] + 1
                call add(temp, line)
            else 
                " the next number represents a new range.
                " Therefore, a range must be entered...
                call add(range, [temp[0], temp[0]])
                " and a new one begun.
                let temp = []
                call add(temp, line)
            endif
        elseif len(temp) == 2
            if line == temp[1] + 1
                " this line number represents a continuation
                " of the range being built.
                let temp[1] = line
            else
                "this means the range in temp is complete!
                "add the temp list (pair of numbers) to range
                call add(range, temp)
                let temp = []
                call add(temp, line)
            endif
        else 
            echoerr 'Something went wrong. temp should have 0, 1, or 2 items'
        endif
    endfor
    "now every line has been evaluated, but we still need
    "to cleanup uneven ranges.
    if len(temp) == 1
        "the last line is a range of its own.
        call add(temp, temp[0])
        call add(range, temp)
    elseif len(temp) == 2
        "the last line completed a range
        call add(range, temp)
    endif
    return range
endfunction

let blamelines = IngestGitBlame()
let uncommittedlines = CollectUncommittedLines(blamelines)
let cleanedlines = CleanLines(uncommittedlines)
let ranges = CreateRanges(cleanedlines)

" --------------------TESTS-------------------------
"  creating function for confirming Vader tests work
function! Vadertest()
    let testvalue = 'x'
    return testvalue
endfunction
