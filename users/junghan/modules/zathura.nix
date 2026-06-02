# Zathura — 경량 키보드 PDF 뷰어 (vim 스타일)
# mupdf 백엔드 기본 포함. 기본 PDF 핸들러로 등록.
{ lib, ... }:

{
  programs.zathura = {
    enable = true;

    options = {
      # 클립보드 — 텍스트 선택(마우스/v) 시 시스템 클립보드로
      selection-clipboard = "clipboard";

      # 열기/맞춤
      adjust-open = "best-fit";
      pages-per-row = "1";
      scroll-page-aware = "true";
      scroll-full-overlap = "0.01";
      scroll-step = "100";
      statusbar-home-tilde = "true";

      # 글꼴
      font = "monospace 10";

      # 다크/나이트 모드 색상 (i 로 토글). gruvbox 계열
      recolor = "false";
      recolor-keephue = "true";
      recolor-lightcolor = "#1d2021";  # 배경
      recolor-darkcolor = "#ebdbb2";   # 글자

      # 하이라이트/검색 색
      highlight-color = "#fabd2f";
      highlight-active-color = "#fe8019";

      # 진행률 표시
      window-title-page = "true";
      guioptions = "v";  # 스크롤바만 (s:상태바 h:가로스크롤바 v:세로스크롤바)
    };

    # vim 스타일 매핑 (기본 j/k/h/l, gg/G, /, n/N, Tab 등은 그대로 두고 보강)
    mappings = {
      # 반페이지 스크롤 (vim C-d/C-u 감각을 d/u 에도)
      u = "scroll half-up";
      d = "scroll half-down";
      # 듀얼 페이지 토글은 D 로 이동
      D = "toggle_page_mode";
      # 줌
      K = "zoom in";
      J = "zoom out";
      # 나이트모드 토글
      i = "recolor";
      # 리로드 / 회전
      r = "reload";
      R = "rotate";
      # 인쇄
      p = "print";
      # 첫 페이지
      g = "goto top";
    };
  };

  # 기본 PDF 핸들러 등록은 xdg.mimeApps(불변 store 심볼릭) 대신
  # configs/mimeapps.list out-of-store 심볼릭으로 관리 (home-manager.nix).
  # Thunar 등에서 런타임 변경 가능하도록 — 유연성 우선.
}
