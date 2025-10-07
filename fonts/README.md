# FONT CJK Support

## Hangul Fonts on NIXPKGS

- sarasa-gothic
- pretendard
- nerd-fonts-d2coding

``` nix
 environment.systemPackages = [
    pkgs.sarasa-gothic
    pkgs.pretendard
    pkgs.nerd-fonts.d2coding
  ];
```

## Monoplex Nerd (Junghan's Choice)

https://github.com/soomtong/monoplex/releases/tag/NF3.3

## DESCRIPTION

IBM Plex 폰트 기반의 코딩용 폰트 조합입니다.

PlemolJP 폰트를 기반으로 Monoplex KR 을 병합하였습니다.

― 터미널 용으로 영문과 한글(일본어) 글자폭이 1:2 비율을 가집니다.

MonoplexNerd-Bold.ttf
MonoplexNerd-BoldItalic.ttf
MonoplexNerd-ExtraLight.ttf
MonoplexNerd-ExtraLightItalic.ttf
MonoplexNerd-Italic.ttf
MonoplexNerd-Light.ttf
MonoplexNerd-LightItalic.ttf
MonoplexNerd-Medium.ttf
MonoplexNerd-MediumItalic.ttf
MonoplexNerd-Regular.ttf
MonoplexNerd-SemiBold.ttf
MonoplexNerd-SemiBoldItalic.ttf
MonoplexNerd-Text.ttf
MonoplexNerd-TextItalic.ttf
MonoplexNerd-Thin.ttf
MonoplexNerd-ThinItalic.ttf

― 영문:한글(일본어) 비율이 3:5 인 비율의 폰트입니다. 코딩용으로도 좋고 기술 문서 작성용도로 애용하고 있습니다.

MonoplexWideNerd-Bold.ttf
MonoplexWideNerd-BoldItalic.ttf
MonoplexWideNerd-ExtraLight.ttf
MonoplexWideNerd-ExtraLightItalic.ttf
MonoplexWideNerd-Italic.ttf
MonoplexWideNerd-Light.ttf
MonoplexWideNerd-LightItalic.ttf
MonoplexWideNerd-Medium.ttf
MonoplexWideNerd-MediumItalic.ttf
MonoplexWideNerd-Regular.ttf
MonoplexWideNerd-SemiBold.ttf
MonoplexWideNerd-SemiBoldItalic.ttf
MonoplexWideNerd-Text.ttf
MonoplexWideNerd-TextItalic.ttf
MonoplexWideNerd-Thin.ttf
MonoplexWideNerd-ThinItalic.ttf


## DOWNLOAD

https://github.com/soomtong/monoplex/releases/download/NF3.3/MonoplexNerd.zip

``` ssh
wget https://github.com/soomtong/monoplex/releases/download/NF3.3/MonoplexNerd.zip
wget https://github.com/soomtong/monoplex/releases/download/NF3.3/MonoplexWideNerd.zip
```


## FontName

fc-list | grep M

- Monoplex Nerd
- Monoplex Wide Nerd
