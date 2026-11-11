# Скрипт-конвертер шрифта в MIF файл

Использование:
```sh
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

make i=ter-u12n.bdf
```
где ter-u12n.bdf — входной файл шрифта.

Производит Font.mif — Memory Initialization File для Quartus. Затем в корне
command-display:
```sh
cp font2mif/Font.mif .
```

В скрипте заданы параметры для шрифтов 8x12 (работает и для 6x12).
Ширина слова в MIF-файле *108 бит*, всего слов 36 (цифры и заглавные
латинские буквы). (`WIDTH=108`, `DEPTH=36`)

> [!WARNING]
> Требование: входной шрифт имеет глифы для NUL (0x00), не имеет
> глифы для 0x01:0x1f. Далее вплоть до Z глифы имеются.

Файл header.txt — "заголовок" выходного файла MIF. Строка %F заменяется на
название шрифта.
