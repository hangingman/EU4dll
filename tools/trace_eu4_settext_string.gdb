set pagination off
set confirm off
set breakpoint pending on

# SetText's first CString is rdx on SysV x86-64. The static analysis
# shows +0 is passed to strlen and +8 is the string length candidate.
break CTextSprite::SetText(CGraphics*, CString const&, CString const&, CString const&, unsigned short, unsigned short, CVector2<unsigned int>, FontFormatting, bool)
commands
  silent
  set $settext_string_hits = $settext_string_hits + 1
  if $settext_string_hits <= 5
    if $rdx == 0
      printf "TRACE_STRING symbol=CTextSprite::SetText hit=%d status=SKIP reason=null-cstring cstring=%p\n", $settext_string_hits, $rdx
    else
      set $settext_string_data = *(void **) $rdx
      set $settext_string_length = *(long long *) ($rdx + 8)
      if $settext_string_data == 0
        printf "TRACE_STRING symbol=CTextSprite::SetText hit=%d status=SKIP reason=null-data cstring=%p data=%p length=%lld\n", $settext_string_hits, $rdx, $settext_string_data, $settext_string_length
      else
        if $settext_string_length <= 0
          printf "TRACE_STRING symbol=CTextSprite::SetText hit=%d status=SKIP reason=length-out-of-range cstring=%p data=%p length=%lld\n", $settext_string_hits, $rdx, $settext_string_data, $settext_string_length
        else
          if $settext_string_length > 64
            printf "TRACE_STRING symbol=CTextSprite::SetText hit=%d status=SKIP reason=length-out-of-range cstring=%p data=%p length=%lld\n", $settext_string_hits, $rdx, $settext_string_data, $settext_string_length
          else
            printf "TRACE_STRING symbol=CTextSprite::SetText hit=%d status=READ id=SETTEXT_READ_%02d cstring=%p data=%p length=%lld bytes=", $settext_string_hits, $settext_string_hits, $rdx, $settext_string_data, $settext_string_length
            eval "x/%dxb $settext_string_data", $settext_string_length
          end
        end
      end
    end
  end
  continue
end

set $settext_string_hits = 0
run
