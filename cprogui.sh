#!/bin/bash

DIALOG=${DIALOG=dialog}

# Проверка архитектуры и назначение целевой директории CryptoPRO
_check_arch () {
  to_dialog=`which $DIALOG`
  arch=`uname -m`
  if [ $arch = 'x86_64' ]; then
    target_dir='amd64'
  else
    target_dir='ia32'
  fi
}

# Обнуление переменных
_reset () {
  retval=''
  choice=''
  list=''
  dest=''
  destlist=''
  copydest=''
  key=''
  rootname=''
  keyroot=''
  curpath=$HOME
  rm _keys.tmp _dest.tmp
}

# Прорисовка строки
_line () {
  printf %50s |tr " " "="
  echo
}

# Завершение работы
_exit () {
  _line
  echo 'Егор Бабенко <patttern@gmail.com>'
  echo 'Выход.'
  exit 0
}

# Главное меню
_show_main_dialog () {
  _reset
  tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
  trap "rm -f $tempfile" 0 1 2 5 15

  $DIALOG --clear --cancel-label "Выход" --title "CryptoPRO GUI" \
          --menu "Программа консольного управления CryptoPRO.\n\n\
  Выберите действие:" 17 60 7 \
  1  "Список подключенных ключевых носителей" \
  2  "Список доступных ключей сертификатов" \
  3  "Установка корневого сертификата" \
  4  "Копирование ключей между хранилищами" \
  5  "Установка ключа сертификата" \
  6  "Проверка работы контейнера по закрытому ключу" \
  7  "Удаление ключа сертификата" 2> $tempfile

  retval=$?

  choice=`cat $tempfile`

  case $retval in
    0)
      _check_choise ;;
    1)
      _exit ;;
  esac
}

# Список подключенных ключевых носителей
_list_flash () {
  list=`/opt/cprocsp/bin/${target_dir}/list_pcsc | sed 's/\([a-z :]*\)//'`
  $DIALOG --clear --title "Список подключенных ключевых носителей" \
    --msgbox "${list}" 10 52
  _show_main_dialog
}

# Список доступных ключей сертификатов
_list_keys () {
  list=`/opt/cprocsp/bin/${target_dir}/csptest -keyset -enum_cont -fqcn -verifyc | grep '\\\\'`
  $DIALOG --clear --title "Список доступных ключей сертификатов" \
    --msgbox "$list" 30 60
  _show_main_dialog
}

# Выбор файла корневого сертификата
_get_file () {
  if [ -d $curpath ]; then
    curpath=`readlink -f $curpath`"/"
  fi
  curpath=$($DIALOG --stdout --cancel-label "Отмена" --title "Выберите файл корневого сертификата" --fselect $curpath 14 80)
  if [ ! -f $curpath ]; then
    _get_file
  fi
}

# Установка корневого сертификата
_inst_root () {
  curpath=$HOME
  _get_file
  if [ "x$curpath" != 'x' ]; then
    rootname=$(basename $curpath)
    keyroot=/var/opt/cprocsp/keys/root/$rootname
    sudo cp $curpath $keyroot
    sudo /opt/cprocsp/bin/${target_dir}/certmgr -inst -store root -file $keyroot
  fi
  _show_main_dialog
}

# Выбор ключа
_select_key () {
  list=()
  /opt/cprocsp/bin/${target_dir}/csptest -keyset -enum_cont -fqcn -verifyc \
    | grep '\\\\' | sed 's/\\/\\\\/g' 2>&1 > _keys.tmp
  keysize=$(du -k "_keys.tmp" | cut -f 1)

  if [ $keysize -gt 0 ]; then
    while read LINE; do list+=("$LINE" v); done < _keys.tmp
    key=$($DIALOG --stdout --clear --cancel-label "Отмена" --title 'Список доступных ключей' \
      --menu 'Выберите копируемый ключ' 17 60 9 "${list[@]}")
  else
    $DIALOG --clear --title "Ошибка получения списка ключей" \
      --msgbox "\nНе найдено ни одного ключа сертификатов на ключевых носителях." 8 40
    _show_main_dialog
  fi
}

# Выбор хранилища назначения
_select_dest () {
  destlist=()
  /opt/cprocsp/bin/${target_dir}/list_pcsc | sed 's/\([a-z :]*\)//' | uniq -u  2>&1 > _dest.tmp
  while read LINE; do destlist+=("\\\\.\\$LINE" v); done < _dest.tmp
  destlist+=("\\\\.\\HDIMAGE" v)
  dest=$($DIALOG --stdout --clear --cancel-label "Отмена" --title 'Выбор места назначения' \
      --menu 'Выберите место назначения' 17 60 9 "${destlist[@]}")
}

# Копирование ключей между хранилищами
_copy_key () {
  _select_key

  if [ "x$key" = 'x' ]; then
    _show_main_dialog
  else
    _select_dest

    if [ "x$dest" = 'x' ]; then
      _show_main_dialog
    else
      key_alt=$(echo $key | sed 's/\\/\//g')
      keyname=$(basename "$key_alt")
      inputtext=$keyname'_local'

      keynamenew=$($DIALOG --stdout --clear --cancel-label "Отмена" --title "Введите новое имя ключа" --inputbox "Имя ключа: $keyname" 8 50 "$inputtext")

      if [ "x$keynamenew" != 'x' ]; then
        /opt/cprocsp/bin/${target_dir}/csptest -keycopy -contsrc "$key" -contdest "$dest\\$keynamenew"
      fi

      _copy_key
    fi
  fi
}

# Установка ключа сертификата
_inst_cert () {
  _select_key

  if [ "x$key" = 'x' ]; then
    _show_main_dialog
  else
    /opt/cprocsp/bin/${target_dir}/certmgr -inst -cont "$key"

    key=''
    _inst_cert
  fi
}

# Проверка работы контейнера по закрытому ключу
_check_key () {
  _select_key

  if [ "x$key" = 'x' ]; then
    _show_main_dialog
  else
    keynamenew=$($DIALOG --stdout --clear --cancel-label "Отмена" --title "Введите новое имя ключа" --insecure --passwordbox "Введите пароль для ключа $keyname" 8 50 "")

    if [ "x$keynamenew" != 'x' ]; then
      list=`/opt/cprocsp/bin/${target_dir}/csptestf -keys -cont "$key" -check -pass $keynamenew`
      $DIALOG --title "Проверка работы контейнера" \
        --msgbox "${list}" 30 60
    fi
    _check_key
  fi
}

# Удаление ключа сертификата
_del_cert () {
  $DIALOG --clear --title "В разработке" \
    --msgbox "\nУдаление ключа сертификата находится на стадии разработки." 8 40
  _show_main_dialog
}

# Проверка выбранного пункта главного меню
_check_choise () {
  case $choice in
    1)
      _list_flash ;;
    2)
      _list_keys ;;
    3)
      _inst_root ;;
    4)
      _copy_key ;;
    5)
      _inst_cert ;;
    6)
      _check_key ;;
    7)
      _del_cert ;;
  esac
}

_check_arch
_show_main_dialog
