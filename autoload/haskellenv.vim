function! s:HaskellHealth(state, resolver)
  if a:state is# 'ide'
    hi LanguageHealth guifg=#B8E673 guibg=#465457
  elseif a:state is# 'ready'
    hi LanguageHealth guifg=#B8E673 guibg=#465457
  elseif a:state is# 'initialized'
    hi LanguageHealth guifg=#E6DB74 guibg=#465457
  elseif a:state is# 'uninitialized'
    hi LanguageHealth guifg=#EF5939 guibg=#465457
  elseif a:state is# 'missing'
    hi LanguageHealth guifg=#EF5939 guibg=#465457
  endif

  let g:language_health = a:resolver
endfunction

let g:haskell_supported_extensions = []

let g:haskell_supported_pragmas = [
  \ 'COLUMN',
  \ 'COMPLETE',
  \ 'DEPRECATED',
  \ 'INCOHERENT',
  \ 'INLINABLE',
  \ 'INLINE',
  \ 'INLINE CONLIKE',
  \ 'LANGUAGE',
  \ 'LINE',
  \ 'MINIMAL',
  \ 'NOLINE',
  \ 'NOINLINE CONLIKE',
  \ 'NOUNPACK',
  \ 'OPTIONS_GHC',
  \ 'OVERLAPPABLE',
  \ 'OVERLAPPING',
  \ 'OVERLAPS',
  \ 'RULES',
  \ 'SOURCE',
  \ 'SPECIALIZE',
  \ 'SPECIALIZE INLINE',
  \ 'UNPACK',
  \ 'WARNING']

let g:haskell_supported_deriving_strategies = [
  \ 'anyclass',
  \ 'instance',
  \ 'newtype',
  \ 'stock']

let g:haskell_supported_keywords = [
  \ 'as',
  \ 'capi',
  \ 'case',
  \ 'ccall',
  \ 'class',
  \ 'data',
  \ 'data family',
  \ 'data instance',
  \ 'default',
  \ 'deriving',
  \ 'deriving anyclass',
  \ 'deriving instance',
  \ 'deriving newtype',
  \ 'deriving stock',
  \ 'export',
  \ 'forall',
  \ 'foreign',
  \ 'foreign import',
  \ 'hiding',
  \ 'import',
  \ 'import qualified',
  \ 'in',
  \ 'infix',
  \ 'infixl',
  \ 'infixr',
  \ 'instance',
  \ 'interruptible',
  \ 'let',
  \ 'mdo',
  \ 'module',
  \ 'newtype',
  \ 'of',
  \ 'pattern',
  \ 'prim',
  \ 'proc',
  \ 'qualified',
  \ 'rec',
  \ 'safe',
  \ 'static',
  \ 'type',
  \ 'type family',
  \ 'type instance',
  \ 'type role',
  \ 'unsafe',
  \ 'where']

function! HaskellComplete(findstart, base)
  if a:findstart
    let line = getline('.')
    let start = col('.') - 1
    while start > 0 && line[start - 1] =~ '\S'
      let start -= 1
    endwhile
    return start
  else
    let res = []
    let l:line = getline('.')
    if l:line =~ '^{-#\s\+LANGUAGE'
      for m in g:haskell_supported_extensions
        if m =~ '^' . a:base
          call add(res, m)
        endif
      endfor
    elseif l:line =~ '^{-#\s\+$'
      for m in g:haskell_supported_pragmas
        if m =~ '^' . a:base
          call add(res, m)
        endif
      endfor
    elseif l:line =~ 'deriving\s*$'
      for m in g:haskell_supported_deriving_strategies
        if m =~ '^' . a:base
          call add(res, m)
        endif
      endfor
    else
      for m in g:haskell_supported_keywords
        if m =~ '^' . a:base
          call add(res, m)
        endif
      endfor
    endif
    return res
  endif
endfunction
set omnifunc=HaskellComplete

function! s:HaskellSetup(...) abort
  let g:haskell_original_path = get(g:, 'haskell_original_path', $PATH)
  let g:haskell_supported_extensions = []

  function! s:HaskellRegisterExtensions(job_id, data, event) abort
    for ext in a:data
      if ext isnot# ''
        call add(g:haskell_supported_extensions, ext)
      endif
    endfor
  endfunction
  let s:HaskellRegisterExtensionsHandler = {
    \ 'on_stdout': function('s:HaskellRegisterExtensions')
    \ }

  function! s:HaskellSetupEnv() abort
    call <SID>HaskellHealth('ready', get(g:, 'haskell_resolver', '[unknown]'))
  endfunction

  function! s:HaskellPackagePath(job_id, data, event) abort
    let l:path = a:data[0]

    if l:path isnot# ''
      let $GHC_PACKAGE_PATH = l:path
      call <SID>HaskellHealth('initialized', get(g:, 'haskell_resolver', '[unknown]'))

      call <SID>HaskellSetupEnv()
    endif
  endfunction
  let s:HaskellPackagePathHandler = {
   \ 'on_stdout': function('s:HaskellPackagePath')
   \ }

  function! s:HaskellPath(job_id, data, event) abort
    let l:path = a:data[0]

    if l:path isnot# ''
      let l:lts_prefix = matchstr(get(g:, 'haskell_resolver'), '^[^.]*')
      if l:lts_prefix isnot# ''
        let l:envpath = $HOME . '/Local/ghc/' . l:lts_prefix . '/bin'
        let $PATH = l:envpath . ':' . join(filter(split(l:path, ':'), 'v:val isnot# "' . l:envpath . '"'), ':')

        call jobstart('ghc --supported-extensions', s:HaskellRegisterExtensionsHandler)
        call jobstart('env PATH=' . l:envpath . ':' . g:haskell_original_path . ' stack --no-install-ghc exec printenv GHC_PACKAGE_PATH', s:HaskellPackagePathHandler)
      else
        let $PATH = l:path

        call jobstart('ghc --supported-extensions', s:HaskellRegisterExtensionsHandler)
        call jobstart('env PATH=' . g:haskell_original_path . ' stack --no-install-ghc exec printenv GHC_PACKAGE_PATH', s:HaskellPackagePathHandler)
      endif
    endif
  endfunction
  let s:HaskellPathHandler = {
   \ 'on_stdout': function('s:HaskellPath')
   \ }

  if a:0
    let l:ghc = a:1
    let l:envpath = $HOME . '/Local/ghc/' . l:ghc . '/bin'

    call <SID>HaskellHealth('missing', l:ghc)

    "resolve current ghc version
    if l:ghc is# 'current'
      if isdirectory(l:envpath)
        let l:ghc = systemlist('readlink $HOME/Local/ghc/current')[0]
        let l:envpath = $HOME . '/Local/ghc/' . l:ghc . '/bin'
      else
        return
      end
    end
    let g:haskell_resolver = l:ghc

    if isdirectory(l:envpath)
      let $PATH = l:envpath . ':' . g:haskell_original_path
      call <SID>HaskellHealth('ready', l:ghc)
      call jobstart('ghc --supported-extensions', s:HaskellRegisterExtensionsHandler)
    endif
  else
    let l:resolver = systemlist('grep "^resolver:" stack.yaml | cut -d" " -f2')[0]

    let g:haskell_resolver = l:resolver
    let l:lts_prefix = matchstr(l:resolver, '^[^.]*')
    let l:envpath = $HOME . '/Local/ghc/' . l:lts_prefix . '/bin'
    if isdirectory(l:envpath)
      let $PATH = l:envpath . ':' . g:haskell_original_path

      if l:lts_prefix isnot# '' && isdirectory(l:envpath)
        call <SID>HaskellHealth('uninitialized', get(g:, 'haskell_resolver', '[unknown]'))
        if isdirectory($HOME . '/.stack/snapshots/x86_64-freebsd/' . g:haskell_resolver)
          call jobstart('env PATH=' . l:envpath . ':' . g:haskell_original_path . ' stack --no-install-ghc exec printenv PATH', s:HaskellPathHandler)
        endif
      endif
    else
      call <SID>HaskellHealth('missing', l:resolver)
    endif
  endif
endfunction
function! s:HaskellEnvs(lead, line, pos) abort
  return system("find ~/Local/ghc -depth 1 -exec basename '{}' + | sort")
endfunction
command! -complete=custom,<SID>HaskellEnvs -nargs=? HaskEnv call <SID>HaskellSetup(<f-args>)

function! s:HaskellSkel() abort
  if @% is# 'Main.hs'
    silent! normal! imodule Main wheremain :: IO ()main = return ()2B
  else
    silent! normal! "%p
    silent! s/\v^%([0-9a-z].{-}\/)*(.{-})\.hs/module \u\1 where/
    silent! s/\//./g
    silent! normal!o
  endif
endfunction

function! s:Move(m, count, inclusive, visual, jump)
  if a:jump
    normal! m'
  endif
  if a:visual
    normal! gv
  endif
  let l:f = 'call <SID>'. a:m . '(' . a:inclusive . ')'
  for i in range(a:count > 1 ? a:count : 1)
    execute l:f
  endfor
endfunction

function! s:NextBlockStart(inclusive) abort
  let l:line = getline(line('.'))
  if l:line =~ '^\S'
    call search('^\s*$\|\%$', 'W')
  endif
  if line('.') != 1
    call search('^\S', 'W')
  endif
endfunction

function! s:NextBlockEnd(inclusive) abort
  let l:lnum = line('.')
  call <SID>NextBlockStart(0)
  call search('\S$', 'bW')
  let l:end = line('.')
  call <SID>PrevBlockStart(0)
  let l:start = line('.')
  if !(l:start <= l:lnum && l:lnum < l:end)
    call cursor(l:lnum, 0)
    call <SID>NextBlockStart(0)
  endif
  call <SID>NextBlockStart(0)
  call search('\S$', 'bW')
  if a:inclusive
    call cursor(line('.') + 1, 0)
  endif
endfunction

function! s:PrevBlockStart(inclusive) abort
  call search('^\S', 'bW')
  call search('^\s*$\|\%^', 'bW')
  if line('.') != 1
    call search('^\S', 'W')
  endif
endfunction

function! s:PrevBlockEnd(inclusive) abort
  let l:lnum = line('.')
  call <SID>PrevBlockStart(0)
  call <SID>NextBlockStart(0)
  call search('\S$', 'bW')
  let l:end = line('.')
  if l:lnum <= l:end
    call cursor(l:lnum, 0)
    call <SID>PrevBlockStart(0)
    call search('\S$', 'bW')
  endif
  if !a:inclusive
    call cursor(line('.') + 1, 0)
  endif
endfunction

function! s:HaskellSettings() abort
  nnoremap <buffer><silent> [[ :<C-U>call <SID>Move('PrevBlockStart',v:count,0,0,1)<cr>
  nnoremap <buffer><silent> [] :<C-U>call <SID>Move('PrevBlockEnd',v:count,1,0,1)<cr>
  nnoremap <buffer><silent> ][ :<C-U>call <SID>Move('NextBlockEnd',v:count,0,0,1)<cr>
  nnoremap <buffer><silent> ]] :<C-U>call <SID>Move('NextBlockStart',v:count,0,0,1)<cr>

  vnoremap <buffer><silent> [[ :<C-U>call <SID>Move('PrevBlockStart',v:count,0,1,0)<cr>
  vnoremap <buffer><silent> [] :<C-U>call <SID>Move('PrevBlockEnd',v:count,1,1,0)<cr>
  vnoremap <buffer><silent> ][ :<C-U>call <SID>Move('NextBlockEnd',v:count,0,1,0)<cr>
  vnoremap <buffer><silent> ]] :<C-U>call <SID>Move('NextBlockStart',v:count,0,1,0)<cr>

  onoremap <buffer><silent> [[ :<C-U>call <SID>Move('PrevBlockStart',v:count,0,0,0)<cr>
  onoremap <buffer><silent> [] :<C-U>call <SID>Move('PrevBlockEnd',v:count,0,0,0)<cr>
  onoremap <buffer><silent> ][ :<C-U>call <SID>Move('NextBlockEnd',v:count,1,0,0)<cr>
  onoremap <buffer><silent> ]] :<C-U>call <SID>Move('NextBlockStart',v:count,0,0,0)<cr>

  setlocal suffixesadd+=.hs,.hamlet

  if executable('stylish-haskell')
    setlocal formatprg=stylish-haskell
  endif

  if executable('hoogle')
    setlocal keywordprg=hoogle\ --info
  endif
endfunction

function! s:HaskellSortImports(line1, line2)
  exe a:line1 . "," . a:line2 . "sort /import\\s\\+\\(qualified\\s\\+\\)\\?/"
endfunction
command! -buffer -range HaskSortImports call <SID>HaskellSortImports(<line1>, <line2>)

function! <SID>HaskellFormatImport(line1, line2)
  exec a:line1 . ",". a:line2 . "s/import\\s\\+\\([A-Z].*\\)/import           \\1"
endfunction
command! -buffer -range HaskFormatImport call <SID>HaskellFormatImport(<line1>, <line2>)

function! haskellenv#start()
  augroup haskellenv_commands
    au!
    au BufNewFile *.hs call <SID>HaskellSkel() | call <SID>HaskellSettings()
    au BufRead *.hs call <SID>HaskellSettings()
    au BufNewFile,BufRead *.dump-stg,*.dump-simpl setf haskell
    au BufNewFile,BufRead *.dump-cmm,*.dump-opt-cmm setf c
    au BufNewFile,BufRead *.dump-asm setf asm
    au BufWritePost stack.yaml call <SID>HaskellSetup()
  augroup end

  if executable('hasktags')
    function! s:HaskellRebuildTagsFinished(job_id, data, event) abort
      let g:haskell_rebuild_tags = 0
    endfunction
    let s:HaskellRebuildTagsFinishedHandler = {
      \ 'on_exit': function('s:HaskellRebuildTagsFinished')
      \ }

    function! s:HaskellRebuildTags() abort
      if !get(g:, 'haskell_rebuild_tags', 0)
        let l:cmd = 'hasktags --ignore-close-implementation --ctags .; sort tags'
        let g:haskell_rebuild_tags = jobstart(l:cmd, s:HaskellRebuildTagsFinishedHandler)
      endif
    endfunction

    augroup haskell_tags
      au!
      au BufWritePost *.hs call <SID>HaskellRebuildTags()
    augroup end

    command! HaskTags call <SID>HaskellRebuildTags()
  endif

  if filereadable('stack.yaml')
    au VimEnter * call <SID>HaskellSetup()
  else
    HaskEnv current
  endif

  if &ft == 'haskell'
    call s:HaskellSettings()
  endif
endfunction
