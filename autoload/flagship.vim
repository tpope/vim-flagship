" Location: autoload/flagship.vim
" Author: Tim Pope <http://tpo.pe/>

if exists('g:autoloaded_flagship')
  finish
endif
let g:autoloaded_flagship = 1

" Section: General

" Remove duplicates from a list.  Different from uniq() in that the duplicates
" do not have to be consecutive.
function! flagship#uniq(list) abort
  let i = 0
  let seen = {}
  while i < len(a:list)
    let str = string(a:list[i])
    if has_key(seen, str)
      call remove(a:list, i)
    else
      let seen[str] = 1
      let i += 1
    endif
  endwhile
  return a:list
endfunction

" Double %'s, preventing them from being expanded.
function! flagship#escape(expr) abort
  return substitute(a:expr, '%', '%%', 'g')
endfunction

" Surround the value in brackets, but return an empty string for empty input.
" Give additional arguments to use characters other than brackets.
function! flagship#surround(str, ...) abort
  if empty(a:str)
    return ''
  endif
  let match = {'[': ']', '{': '}', '(': ')', '<': '>', ',': ''}
  let open = a:0 ? a:1 : '['
  return open . a:str . (a:0 > 1 ? a:2 : get(match, open, open))
endfunction

" Remove surrounding brackets, whitespace, and commas.
function! flagship#clean(str) abort
  return substitute(a:str, '^[[, ]\|[], ]$', '', 'g')
endfunction

" Call a function with arguments if it exists.  Otherwise return ''.  Useful
" if you are not sure if a plugin is installed.  Here's an example that I use
" for Syntastic:
"
"     %#ErrorMsg#%{flagship#try('SyntasticStatuslineFlag')}%*
function! flagship#try(...) abort
  let args = copy(a:000)
  let dict = {}
  let default = ''
  if type(get(args, 0)) == type({})
    let dict = remove(args, 0)
  endif
  if type(get(args, 0)) == type([])
    let default = remove(args, 0)[0]
  endif
  if empty(args)
    return default
  endif
  let Func = remove(args, 0)
  if type(Func) == type(function('tr')) || exists('*'.Func)
    return call(Func, args, dict)
  else
    return default
  endif
endfunction

" Call a function with flagship#try() and normalize the result with
" flagship#clean() and flagship#surround().
function! flagship#call(...) abort
  let dict = {'host': 'flagship'}
  return flagship#surround(flagship#clean(call('flagship#try', [dict] + a:000)))
endfunction

" Create a dictionary from alternating keys and values.  Useful because it's
" impossible to nest a dictionary literal in %{} expressions.
function! flagship#dict(...) abort
  let dict = {}
  for i in range(0, a:0-1, 2)
    let dict[a:000[i]] = dict[a:000[i+1]]
  endfor
  return dict
endfunction

" Currently logged in user.
function! flagship#user() abort
  if has('win32')
    return $USERNAME
  elseif empty($LOGNAME) && has('unix')
    let me = system('whoami')[1:-1]
    let $LOGNAME = v:shell_error ? fnamemodify(expand('~'), ':t') : me
  endif
  return empty($LOGNAME) ? 'unknown' : $LOGNAME
endfunction

" Returns v:servername if present, or @hostname() when sshed.  This is the
" default tab prefix.
function! flagship#id() abort
  let servername = v:servername
  if has('nvim')
    let servername = fnamemodify(servername, ':h:t')
  endif
  return servername . (empty($SSH_TTY) ? '': '@'.substitute(hostname(), '\..*', '', ''))
endfunction

" Returns "Help" for help buffers and the filetype otherwise.
" flagship#surround(flagship#filetype()) essentially combines %h and %y.
function! flagship#filetype(...) abort
  let buffer = bufnr((a:0 && a:1 isnot 0) ? a:1 : '%')
  if getbufvar(buffer, '&buftype') ==# 'help'
    return 'Help'
  else
    return getbufvar(buffer, '&filetype')
  endif
endfunction

" Section: Tab Page

" All tab functions accept a tab number as this first optional argument,
" with a default of v:lnum.  Note that v:lnum is set to the tab number
" automatically in a tab label.

" Return the active buffer number for the tab.
function! flagship#tabbufnr(...) abort
  let tab = a:0 ? a:1 : v:lnum
  return tab > 0 ? tabpagebuflist(v:lnum)[tabpagewinnr(v:lnum)-1] : 0
endfunction

" Returns a string consisting of one plus sign for each modified buffer and
" one exclamation point for each terminal buffer in the given tab number.
" If no tab number is given, use the tab number in v:lnum.
function! flagship#tabmodified(...) abort
  let tab = a:0 ? a:1 : v:lnum
  let str = ''
  for tab in tab ? [tab] : range(1, tabpagenr('$'))
    for buf in tabpagebuflist(tab)
      if getbufvar(buf, '&buftype') ==# 'terminal'
        let str .= '!'
      elseif getbufvar(buf, '&modified')
        let str .= '+'
      endif
    endfor
  endfor
  return str
endfunction

" Return the number of times a given buffer variable is nonempty for the given
" tab number.
function! flagship#tabcountbufvar(var, ...) abort
  let tab = a:0 ? a:1 : v:lnum
  let cnt = 0
  for tab in tab ? [tab] : range(1, tabpagenr('$'))
    for buf in tabpagebuflist(tab)
      let cnt += !empty(getbufvar(buf, a:var))
    endfor
  endfor
  if !cnt
    return ''
  else
    return cnt
  endif
endfunction

" Return the number of times a given window variable is nonempty for the given
" tab number.
function! flagship#tabcountwinvar(var, ...) abort
  let tab = a:0 ? a:1 : v:lnum
  let cnt = 0
  for tab in tab ? [tab] : range(1, tabpagenr('$'))
    for win in range(1, tabpagewinnr(tab, '$'))
      let cnt += !empty(gettabwinvar(tab, win, a:var))
    endfor
  endfor
  if !cnt
    return ''
  else
    return cnt
  endif
endfunction

" Section: Current Working Directory

" Returns the local working directory for a given tab and window number.  Pass
" zero as both arguments to get the global working directory (ignoring the
" current window).  Will return a path relative to 'cdpath' when possible;
" pass 'raw' as an additional argument to disable this.  Pass 'shorten' to
" call a variant of pathshorten() on the result.
function! flagship#cwd(...) abort
  call flagship#winleave()
  let args = copy(a:000)
  let gcwd = exists('*haslocaldir') ? get(g:, 'flagship_cwd', '') : getcwd()
  if a:0 > 1 && a:1 && a:2
    if !exists('g:flagship_no_getcwd_local') && has('patch-7.4.1126')
      let path = getcwd(a:2, a:1)
    else
      let path = gettabwinvar(a:1, a:2, 'flagship_cwd')
    endif
    let path = empty(path) ? gcwd : path
    let buf = bufname(tabpagebuflist(a:1)[a:2-1])
  elseif a:0 && a:1 is# 0
    let path = gcwd
  elseif type(get(args, 0, '')) !=# type(0)
    let path = getcwd()
    let buf = bufname('')
  else
    throw 'Invalid flagship#cwd arguments'
  endif
  while type(get(args, 0, '')) == type(0)
    call remove(args, 0)
  endwhile
  if index(args, 'raw') < 0
    let path = s:cwdpresent(path)
  endif
  if index(args, 'shorten') >= 0
    let path = matchstr(path, '^[^\/]*') . pathshorten(matchstr(path, '[\/].*'))
  endif
  return path
endfunction

" Return a unique list of all working directories for a given tab or v:lnum.
" Accepts the 'raw' and 'shorten' flags from flagship#cwd().
function! flagship#tabcwds(...) abort
  call flagship#winleave()
  let args = copy(a:000)
  let tabnr = type(get(args, 0, '')) == type(0) ? remove(args, 0) : v:lnum
  let gcwd = exists('*haslocaldir') ? get(g:, 'flagship_cwd', '') : getcwd()
  let path = []
  for t in tabnr ? [tabnr] : range(1, tabpagenr('$'))
    let types = map(tabpagebuflist(t), 'getbufvar(v:val, "&buftype")')
    let all_typed = empty(filter(copy(types), 'empty(v:val)'))
    for w in range(1, tabpagewinnr(t, '$'))
      if empty(types[w-1]) || all_typed
        call add(path, call('flagship#cwd', [t, w] + args))
      endif
    endfor
  endfor
  if index(args, 'raw') < 0
    call flagship#uniq(path)
  endif
  let join = get(filter(args, 'v:val =~# "[[:punct:][:space:]]"'), 0, '')
  return empty(join) ? path : join(path, join)
endfunction

" Section: Private Implementation

function! s:slash() abort
  return has('+shellslash') && !&shellslash ? '\' : '/'
endfunction

function! s:locatepath(path, paths) abort
  let path = a:path
  let parent = ''
  for entry in a:paths
    if empty(entry)
      continue
    endif
    for dir in split(glob(entry), "\n")
      if dir !~# '\'.s:slash().'$'
        let dir .= s:slash()
      endif
      if strpart(a:path, 0, len(dir)) ==# dir && len(a:path) - len(dir) < len(path)
        let parent = dir
        let path = strpart(a:path, len(dir))
      endif
    endfor
  endfor
  return [parent, path]
endfunction

function! s:cwdpresent(dir) abort
  let parents = map(split(&cdpath, ','), 'expand(v:val)')
  let dir = a:dir
  call filter(parents, '!empty(v:val) && v:val !=# expand("~")')
  let dir = s:locatepath(dir, parents)[1]
  return substitute(dir, '^'.escape(expand('~'), '\'), '\~', '')
endfunction

function! s:cpath(path, ...) abort
  if exists('+fileignorecase') && &fileignorecase
    let path = tolower(a:path)
  else
    let path = a:path
  endif
  let path = tr(path, s:slash(), '/')
  return a:0 ? path ==# s:cpath(a:1) : path
endfunction

function! flagship#filename(...) abort
  if &buftype ==# 'quickfix'
    return '[Quickfix List]'
  elseif &buftype =~# '^\%(nofile\|acwrite\|terminal\)$'
    return empty(@%) ? '[Scratch]' : @%
  elseif empty(@%)
    return '[No Name]'
  elseif &buftype ==# 'help'
    return fnamemodify(@%, ':t')
  endif
  let f = @%
  let ns = substitute(matchstr(f, '^\a\a\+\ze:'), '^\a', '\u&', 'g')
  if len(ns) && exists('*' . ns . 'Real')
    try
      let f2 = {ns}Real(f)
      if !empty(f2)
        let f = f2
      endif
    catch
    endtry
  endif
  let cwd = getcwd()
  let home = expand('~')
  if s:cpath((f . '/')[0 : len(cwd)], cwd . '/')
    let f = f[len(cwd) + 1 : -1]
    let f = len(f) ? f : '.'
  elseif len(home) && s:cpath((f . '/')[0 : len(home)], home . '/')
    let f = '~' . f[len(home) : -1]
  endif
  return f
endfunction

unlet! s:did_setup
function! flagship#enter() abort
  let s:mark = tabpagenr().'-'.winnr()
  if !exists('s:did_setup')
    call flagship#setup()
  endif
endfunction

function! flagship#winleave() abort
  let id = tabpagenr().'-'.winnr()
  if tabpagenr().'-'.winnr() !=# get(s:, 'mark', '')
    return
  elseif !exists('*haslocaldir') || haslocaldir()
    let w:flagship_cwd = getcwd()
  else
    unlet! w:flagship_cwd
    let g:flagship_cwd = getcwd()
  endif
  let cwds = g:flagship_cwd
  for t in range(1, tabpagenr('$'))
    for w in range(1, tabpagewinnr(t, '$'))
      let cwds .= "\n" . gettabwinvar(t, w, 'flagship_cwd')
    endfor
  endfor
  let g:FlagshipCwds = cwds
endfunction

function! flagship#session_load_post() abort
  if &sessionoptions =~ 'sesdir'
    let g:flagship_cwd = fnamemodify(v:this_session, ':h')
  endif
  if &sessionoptions =~# 'globals' && exists('g:FlagshipCwds')
    let cwds = split(g:FlagshipCwds, "\n", 1)
    let dir = remove(cwds, 0)
    let wins = 0
    for t in range(1, tabpagenr('$'))
      let wins += tabpagewinnr(t, '$')
    endfor
    if wins !=# len(cwds)
      return
    endif
    if &sessionoptions =~# 'curdir'
      let g:flagship_cwd = dir
    endif
    for t in range(1, tabpagenr('$'))
      for w in range(1, tabpagewinnr(t, '$'))
        let dir = remove(cwds, 0)
        if !empty(dir)
          call settabwinvar(t, w, 'flagship_cwd', dir)
        endif
      endfor
    endfor
  endif
endfunction

function! s:tabexpand(count, char, tab) abort
  let w = tabpagewinnr(a:tab)
  let b = tabpagebuflist(a:tab)[w-1]
  if a:char ==# 'N'
    let s = a:tab
  elseif a:char ==# 'f'
    let s = bufname(b)
  elseif a:char ==# 'F'
    let s = fnamemodify(bufname(b), ':p')
  elseif a:char ==# 'm'
    let s = getbufvar(b, '&modified') ? '[+]' : (getbufvar(b, '&modifiable') ? '' : '[-]')
  elseif a:char ==# 'M'
    let s = getbufvar(b, '&modified') ? ',+' : (getbufvar(b, '&modifiable') ? '' : ',-')
  else
    return '%' . a:count . a:char
  endif
  return '%'.a:count.'('.flagship#escape(s).'%)'
endfunction

function! s:tablabel(tab, fmt) abort
  if a:fmt =~# '^%!'
    let fmt = eval(a:fmt[2:-1])
  else
    let fmt = a:fmt
  endif
  return substitute(fmt, '%\(-\=\d*\%(\.\d*\)\=\)\([NFfMm%]\)', '\=s:tabexpand(submatch(1), submatch(2), a:tab)', 'g')
endfunction

function! flagship#in(...) abort
  let v:lnum = a:0 ? a:1 : tabpagenr()
  return ''
endfunction

function! s:in(...) abort
  return '%{flagship#in('.(a:0 ? a:1 : '').')}'
endfunction

function! s:tabfmtvar(var, ...) abort
  if get(g:, a:var, '') =~# '^%!'
    return eval(get(g:, a:var)[2:-1])
  else
    return get(g:, a:var, a:0 ? a:1 : '')
  endif
endfunction

function! flagship#tablabel() abort
  return s:tabfmtvar('tablabel', '%N') . s:flags('tabpage')
endfunction

function! s:hinorm(expr, highlight) abort
  return substitute(a:expr, '%\*', '%#'.a:highlight.'#', 'g')
endfunction

function! flagship#tablabels() abort
  let s = ''

  let lasttabpagenr = tabpagenr('$')
  for t in range(1, lasttabpagenr)
    let hi = t == tabpagenr() ? 'TabLineSel' : 'TabLine'
    let v:lnum = t
    let label = s:tablabel(t, flagship#tablabel())
    let s .= '%#'.hi.'#%'.t.'T'.s:in(t).' '.s:hinorm(label, hi).' '
    if t != lasttabpagenr
      let s .= '%#TabLineFill#%T'.g:tabinfix
    endif
  endfor

  return s . '%#TabLineFill#%T'.s:in()
endfunction

function! flagship#tabline(...) abort
  let hi = flagship#user() ==# 'root' ? 'ErrorMsg' : 'TabLineFill'
  let prefix = s:tabfmtvar('tabprefix')
  let suffix = s:tabfmtvar('tabsuffix')
  if prefix.suffix !~# '%='
    let suffix = '%=' . suffix
  endif
  if prefix.suffix !~# '%<'
    let suffix = '%<' . suffix
  endif
  let s = '%{flagship#in('.tabpagenr().')}'
        \ . '%#' . hi . '#'
        \ . s:hinorm(prefix . s:flags('global'), hi)
        \ . ' ' . call('flagship#tablabels', a:000)
        \ . s:hinorm(suffix, 'TabLineFill')
  return s:hinorm(s, 'TabLineFill')
endfunction

function! flagship#statusline(...) abort
  let s = a:0 ? a:1 : ''
  if s =~# '^%!'
    let s = eval(s[2:-1])
  endif
  if empty(s)
    let s = '%<%f %{flagship#surround(flagship#filetype())}%w%m%r'
  endif
  if s !~# '%='
    let rulerformat = (empty(&rulerformat) ? '%-14.(%l,%c%V%) %P' : &rulerformat)
    let s .= '%=' . (&ruler ? ' '.rulerformat : '')
  endif
  let s = s:in('winnr()=='.winnr().'?'.tabpagenr().':-'.winnr()).s.s:in(0)
  let s = substitute(s, '%-\=\d*\.\=\d*\zsf\(\s\)\=', '{flagship#filename()."\1"}', 'g')
  return substitute(s, '%=', '\=s:flags("file").s:flags("buffer")."%=".s:flags("window",-1)', '')
endfunction

function! flagship#_hoist(type, ...) abort
  if type(a:type) != type('') || a:type !~# '^[a-z]'
    return
  endif
  if !exists('s:new_flags')
    throw 'Hoist from User Flags autocommand only'
  endif
  let args = copy(a:000)
  if type(get(args, 0, '')) != type(0)
    call insert(args, 0)
  endif
  let args[0] = printf('%09d', args[0])
  if len(args) < 2
    return
  elseif len(args) == 2
    call add(args, {})
  elseif type(args[1]) == type({})
    let [args[1], args[2]] = [args[2], args[1]]
  endif
  if !has_key(s:new_flags, a:type)
    let s:new_flags[a:type] = []
  endif
  let flags = s:new_flags[a:type]
  let index = index(map(copy(flags), 'v:val[1]'), args[1])
  if index < 0
    call add(flags, args)
  else
    let flags[index][0] += args[0]
    call extend(flags[index][2], args[2], 'keep')
  endif
endfunction

function! flagship#flags_for(type) abort
  let flags = []
  for [F, opts; rest] in exists('s:flags') ? get(s:flags, a:type, []) : []
    let str = join([F])
    unlet! F Hl
    if !empty(get(g:, 'flagship_skip', '')) && str =~# g:flagship_skip
      let flag = ''
    elseif str =~# '^function('
      let flag = '%{flagship#call('.str.')}'
    elseif str =~# '^<lambda>\d\+$'
      let flag = '%{flagship#call(function('.string(str).'))}'
    elseif str =~# '^\%(\h\|<SNR>\)[[:alnum:]_#]*$' && exists('*'.str)
      let flag = '%{flagship#call('.string(str).')}'
    elseif str =~# '^%!'
      let flag = eval(str[2:-1])
    elseif str =~# '%'
      let flag = str
    else
      let flag = ''
    endif
    if empty(flag)
      continue
    endif
    let Hl = get(opts, 'hl', '')
    if type(Hl) == type('') && hlexists(substitute(Hl, '^\d$', 'User&', ''))
      if Hl =~# '^\d$'
        let flag = '%'.Hl.'*'.flag.'%*'
      elseif Hl ==? 'ignore'
        continue
      elseif !empty(Hl)
        let flag = '%#'.Hl.'#'.flag.'%*'
      endif
    endif
    call add(flags, flag)
  endfor
  return flags
endfunction

function! s:flags(type, ...) abort
  let flags = flagship#flags_for(a:type)
  if a:0 && a:1 is -1
    call reverse(flags)
  endif
  return join(flags, '')
endfunction

function! flagship#setup(...) abort
  if a:0 && a:1
    unlet! g:tablabel g:tabprefix
    if a:1 > 1
      setglobal statusline=
    endif
  endif
  if !exists('g:tablabel') && !exists('g:tabprefix')
    redir => blame
    silent verbose set showtabline?
    redir END
    if &showtabline == 1 && blame !~# "\t"
      set showtabline=2
    endif
    if exists('&guitablabel') && empty(&guitablabel)
      set guioptions-=e
    endif
  endif
  if !exists('g:tablabel')
    let g:tablabel =
          \ "%N%{flagship#tabmodified()} %{flagship#tabcwds('shorten',',')}"
  endif
  if !exists('g:tabprefix')
    let g:tabprefix = "%{flagship#id()}"
  endif
  if !exists('g:tabinfix')
    let g:tabinfix = ""
  endif
  if !empty(g:tablabel)
    set tabline=%!flagship#tabline()
    if exists('&guitablabel')
      set guitablabel=%!flagship#tablabel()
    endif
  endif
  if empty(&g:statusline)
    setglobal statusline=%!flagship#statusline()
    if &laststatus == 1
      set laststatus=2
    endif
  elseif &g:statusline !~# '^%!'
    let &g:statusline = '%!flagship#statusline('.string(&g:statusline).')'
  elseif &g:statusline !~# 'flagship#statusline'
    let &g:statusline = '%!flagship#statusline('.&g:statusline[2:-1].')'
  endif
  let s:new_flags = {}
  let modelines = &modelines
  try
    let g:Hoist = function('flagship#_hoist')
    function! Hoist(...) abort
      return call(g:Hoist, a:000)
    endfunction
    if exists('#User#Flags')
      if v:version >= 704 || (v:version == 703 && has('patch442'))
        doautocmd <nomodeline> User Flags
      else
        let &modelines = 0
        doautocmd User Flags
      endif
    endif
    for [k, v] in items(s:new_flags)
      call map(sort(v), 'v:val[1:-1]')
    endfor
    unlockvar s:flags
    let s:flags = s:new_flags
    lockvar! s:flags
  finally
    if &modelines != modelines
      let &modelines = modelines
    endif
    unlet! s:new_flags g:Hoist
    if exists('*Hoist')
      delfunction Hoist
    endif
  endtry
  let s:did_setup = 1
  let &l:readonly = &l:readonly
endfunction

" vim:set et sw=2 foldmethod=expr foldexpr=getline(v\:lnum)=~'^\"\ Section\:'?'>1'\:getline(v\:lnum)=~#'^fu'?'a1'\:getline(v\:lnum)=~#'^endf'?'s1'\:'=':
