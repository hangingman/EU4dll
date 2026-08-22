set pagination off
set confirm off
set breakpoint pending on

# Track only the two requested call boundaries; depth is intentionally shallow.
set $localize_depth = 0
set $setup_hits = 0
set $readfolder_hits = 0
set $yaml_hits = 0
set $parse_hits = 0

break PdxLocalizeInitialize
commands
  silent
  set $localize_depth = $localize_depth + 1
  printf "TRACE_LOCALIZE event=enter symbol=PdxLocalizeInitialize tid=%d pc=%p depth=%d\n", $_thread, $pc, $localize_depth
  set $localize_return = *(void **)$rsp
  tbreak *$localize_return
  commands
    silent
    set $localize_depth = $localize_depth - 1
    printf "TRACE_LOCALIZE event=return symbol=PdxLocalizeInitialize tid=%d pc=%p depth=%d\n", $_thread, $pc, $localize_depth
    continue
  end
  continue
end

break ReloadPdxLocalize
commands
  silent
  set $localize_depth = $localize_depth + 1
  printf "TRACE_LOCALIZE event=enter symbol=ReloadPdxLocalize tid=%d pc=%p depth=%d\n", $_thread, $pc, $localize_depth
  set $localize_return = *(void **)$rsp
  tbreak *$localize_return
  commands
    silent
    set $localize_depth = $localize_depth - 1
    printf "TRACE_LOCALIZE event=return symbol=ReloadPdxLocalize tid=%d pc=%p depth=%d\n", $_thread, $pc, $localize_depth
    continue
  end
  continue
end

# Loading-chain helpers: log only the first ten entries of each helper.
break PdxLocalizeSetup
commands
  silent
  set $setup_hits = $setup_hits + 1
  if $setup_hits <= 10
    printf "TRACE_LOCALIZE event=enter symbol=PdxLocalizeSetup tid=%d pc=%p hit=%d depth=%d\n", $_thread, $pc, $setup_hits, $localize_depth
  end
  continue
end

break PdxLocalizeReadFolder
commands
  silent
  set $readfolder_hits = $readfolder_hits + 1
  if $readfolder_hits <= 10
    printf "TRACE_LOCALIZE event=enter symbol=PdxLocalizeReadFolder tid=%d pc=%p hit=%d depth=%d\n", $_thread, $pc, $readfolder_hits, $localize_depth
  end
  continue
end

break LocalizeAddLocalizationYAMLBuffer
commands
  silent
  set $yaml_hits = $yaml_hits + 1
  if $yaml_hits <= 10
    printf "TRACE_LOCALIZE event=enter symbol=LocalizeAddLocalizationYAMLBuffer tid=%d pc=%p hit=%d depth=%d\n", $_thread, $pc, $yaml_hits, $localize_depth
  end
  continue
end

break YmlParse
commands
  silent
  set $parse_hits = $parse_hits + 1
  if $parse_hits <= 10
    printf "TRACE_LOCALIZE event=enter symbol=YmlParse tid=%d pc=%p hit=%d depth=%d\n", $_thread, $pc, $parse_hits, $localize_depth
  end
  continue
end

run
