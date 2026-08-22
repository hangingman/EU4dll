set pagination off
set confirm off
set breakpoint pending on

break LocalizeAddLocalization
commands
  silent
  printf "TRACE symbol=LocalizeAddLocalization tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

break LocalizeAddLocalizationYAMLBuffer
commands
  silent
  printf "TRACE symbol=LocalizeAddLocalizationYAMLBuffer tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

break YmlParse
commands
  silent
  printf "TRACE symbol=YmlParse tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

break PdxLocalizeInitialize
commands
  silent
  printf "TRACE symbol=PdxLocalizeInitialize tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

break ReloadPdxLocalize
commands
  silent
  printf "TRACE symbol=ReloadPdxLocalize tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

break CTextBox::ChangeTextBox
commands
  silent
  printf "TRACE symbol=CTextBox::ChangeTextBox tid=%d pc=%p\n", $_thread, $pc
  info registers rdi rsi rdx rcx r8 r9
  bt 8
  continue
end

run
