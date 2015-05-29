#!/bin/bash

DIALOG=${DIALOG=dialog}

# Прорисовка строки
_line () {
  printf %50s |tr " " "="
  echo
}

# Проверка архитектуры и установка версии CryptoPRO
_check_arch () {
  _line
  echo -n 'Проверка архитектуры операционной системы ... '
  arch=`uname -m`
  if [ $arch = 'x86_64' ]; then
    arch_dir='x86_64'
    target_dir='amd64'
  else
    arch_dir='i486'
    target_dir='ia32'
  fi
  version='4.0.0-4'
  echo $arch
}

# Проверка доступа из-под суперпользователя
_check_root () {
  if [ "$(id -u)" != "0" ]; then
    sudo_match='sudo '
  else
    sudo_match=''
  fi
}

# Предварительная проверка
_preinstall () {
  _check_arch
  _check_root
  ${sudo_match}apt-get install dialog
}

# Удаление ESMART
_remove_esmart () {
  _line
  echo 'Удаление драйвера ESMART 64k...'
  _line

  # драйвер
  debdrv='libesmart1'

  # установка драйвера
  ${sudo_match}apt-get purge $debdrv
  ${sudo_match}service pcscd restart

  _line
  echo 'Удаление драйвера ESMART 64k завершено.'
}

# Удаление Browser Plugins
_remove_plugins () {
  _line
  echo 'Удаление Browser Plugins...'
  _line

  mozilla_libs_founded=no
  if [ -e /usr/lib/mozilla ]; then
    mozilla_libs=/usr/lib/mozilla
    mozilla_libs_founded=yes
  elif [ -e /usr/lib32/mozilla ]; then
    mozilla_libs=/usr/lib32/mozilla
    mozilla_libs_founded=yes
  fi
  if [ "$mozilla_libs_founded" = yes ]; then
    ${sudo_match}rm ${mozilla_libs}/plugins/libnpcades.so*
  fi

  ${sudo_match}rm /usr/lib/librdrrtsupcp.so
  ${sudo_match}rm /usr/lib/libnpcades.so*
  if [ $arch = 'x86_64' ]; then
    ${sudo_match}rm /usr/lib32/librdrrtsupcp.so
    ${sudo_match}rm /usr/lib32/libnpcades.so*
  fi

  # обновление списка библиотек
  ${sudo_match}/sbin/ldconfig
  ${sudo_match}/sbin/ldconfig -p

  _line
  echo 'Удаление Browser Plugins завершено.'
}

# Удаление CryptoPRO
_remove_cryptopro () {
  _line
  echo 'Поиск и удаление установленных программ CryptoPRO...'
  _line

  # остановка сервиса
  ${sudo_match}service cprocsp stop

  upacks='isbc-cryptopro
cprocsp-cpopenssl-gost
cprocsp-cpopenssl
cprocsp-cpopenssl-devel
cprocsp-cpopenssl-base
cprocsp-xer2print
cprocsp-drv
cprocsp-drv-64
cprocsp-drv-devel
lsb-cprocsp-pkix
lsb-cproc
ifd-rutokens
cprocsp-npcades
cprocsp-npcades-64
cprocsp-cadescapilite
cprocsp-cadescapilite-64
lsb-cprocsp-cades
lsb-cprocsp-cades-64
lsb-cprocsp-ocsp-util
lsb-cprocsp-ocsp-util-64
lsb-cprocsp-tsp-util
lsb-cprocsp-tsp-util-64
lsb-cprocsp-pkcs11
lsb-cprocsp-pkcs11-64
cprocsp-rdr-gui-gtk
cprocsp-rdr-gui-gtk-64
cprocsp-rdr-esmart
cprocsp-rdr-esmart-64
cprocsp-rdr-pcsc
cprocsp-rdr-pcsc-64
lsb-cprocsp-kc2
lsb-cprocsp-kc2-64
lsb-cprocsp-kc1
lsb-cprocsp-kc1-64
lsb-cprocsp-capilite
lsb-cprocsp-capilite-64
lsb-cprocsp-rdr
lsb-cprocsp-rdr-64
lsb-cprocsp-base'

  for i in $upacks; do
    ${sudo_match}apt-get -y purge $i
  done

  # зачистка репозитария
  ${sudo_match}apt-get -f install
  ${sudo_match}apt-get clean
  ${sudo_match}apt-get autoremove

  _line
  echo 'Удаление CryptoPRO завершено.'
}

# Удаление настроек CryptoPRO и установленных ключей
_remove_dirs () {
  _line
  echo 'Удаление настроек CryptoPRO и установленных ключей...'
  _line

  delset='/etc/opt/cprocsp
/var/opt/cprocsp
/opt/cprocsp'

  for i in $delset; do
    echo -n "Удаление ${i} ... "
    ${sudo_match}rm -rf $i
    echo "ОК"
  done

  _line
  echo 'Удаление настроек CryptoPRO и установленных ключей завершено.'
}

# Установка CryptoPRO
_install_cryptopro () {
  _line
  echo 'Установка требуемых пакетов...'
  _line

  ${sudo_match}apt-get install lsb-base lsb-core alien libmotif4 libpcsclite1 pcscd

  _line
  echo 'Установка программ CryptoPro...'
  _line

  # i486 библиотеки
  ipack_i486='lsb-cprocsp-base
lsb-cprocsp-rdr
lsb-cprocsp-capilite
lsb-cprocsp-kc1
cprocsp-rdr-pcsc
cprocsp-rdr-gui-gtk
lsb-cprocsp-pkcs11
cprocsp-rdr-esmart
lsb-cprocsp-tsp-util
lsb-cprocsp-ocsp-util
lsb-cprocsp-cades
cprocsp-npcades'

  # x86_64 библиотеки
  ipack_x86_64='lsb-cprocsp-base
lsb-cprocsp-rdr-64
lsb-cprocsp-capilite-64
lsb-cprocsp-kc1-64
cprocsp-rdr-pcsc-64
cprocsp-rdr-gui-gtk-64
lsb-cprocsp-pkcs11-64
cprocsp-rdr-esmart-64
lsb-cprocsp-tsp-util-64
lsb-cprocsp-ocsp-util-64
lsb-cprocsp-cades-64
cprocsp-npcades-64'

  # установка
  eval $( echo packages='$'ipack_${arch_dir} )
  for i in $packages; do
    ${sudo_match}alien -kci ${arch_dir}/cprocsp/${i}-${version}.${arch_dir}.rpm
  done

  # post install
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel ocsp -mask 0xF
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel ocsp_fmt -mask 0x39
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel tsp -mask 0xF
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel tsp_fmt -mask 0x39
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel cades -mask 0xF
  ${sudo_match}/opt/cprocsp/sbin/${arch_dir}/cpconfig -loglevel cades_fmt -mask 0x39

  # restart services
  ${sudo_match}service pcscd restart
  ${sudo_match}service cprocsp restart

  _line
  echo 'Установка программ CryptoPro завершена.'
}

# Установка Browser Plugins
_install_plugins () {
  _line
  echo 'Установка Browser Plugins...'
  _line

  mozilla_libs_founded=no
  if [ -e /usr/lib/mozilla ]; then
    mozilla_libs=/usr/lib/mozilla
    mozilla_libs_founded=yes
  elif [ -e /usr/lib32/mozilla ]; then
    mozilla_libs=/usr/lib32/mozilla
    mozilla_libs_founded=yes
  fi
  if [ "$mozilla_libs_founded" = yes ]; then
    ${sudo_match}cp /opt/cprocsp/lib/${target_dir}/libnpcades.so* ${mozilla_libs}/plugins
    # обновление списка библиотек
    ${sudo_match}/sbin/ldconfig
    ${sudo_match}/sbin/ldconfig -p
  fi
  ${sudo_match}service pcscd restart

  $DIALOG --clear --title "Установка Browser Plugins" \
    --msgbox "\nЕсли у вас до установки Browser Plugins были загружены браузеры, их необходимо перезагрузить." 10 60
  _show_main_dialog
}

# Установка ESMART
_install_esmart () {
  _line
  echo 'Установка драйвера ESMART 64k...'
  _line

  # драйвер
  debdrv='libesmart1_1.4.10-1.1'

  # установка драйвера
  ${sudo_match}dpkg -i ${arch_dir}/esmart/${debdrv}.${arch_dir}.deb
  ${sudo_match}service pcscd restart

  _line
  echo 'Установка драйвера ESMART 64k завершена.'
}

# Завершение работы
_exit () {
  _line
  echo 'CProGUI <https://github.com/Patttern/CProGUI>'
  echo 'Егор Бабенко <patttern@gmail.com>'
  echo 'Выход.'
  exit 0
}

# Выполнение тестирования
_test_exec () {
  _line
  echo 'Тестирование...'

  # _line
  ${sudo_match}service pcscd restart

  _line
  /opt/cprocsp/bin/${target_dir}/list_pcsc

  _line
  /opt/cprocsp/bin/${target_dir}/csptest -keyset -enum_cont -fqcn -verifyc

  _line
  echo 'Тестирование завершено.'
  echo 'Если в ходе тестирования вы увидели подключенный ключевой носитель, а так же список ключей раположенных на нем, значит программа успешно установлена.'
  echo 'В ином случае "Ой, что-то пошло не так... :(".'
  echo -n 'Для продолжения нажмите "Enter" ...'

  read anykey
  echo 'OK'
}

# Команды тестирования
_test () {
  $DIALOG --yes-label "Да" --no-label "Отмена" \
    --title "Тестирование CryptoPro ${version}" --yesno "\\n
Перед продолжением тестирования, вставьте ключевой носитель с сертификатом в \
USB-разъем.\\nЕсли вы не желаете производить тестирование или у вас нет ключевого \
носителя, нажмите <Выход>.\\n\\nПродолжить?" 15 60
  case "$?" in
    '0')
      _test_exec
      ;;
    '1')
      _show_menu
      ;;
    '-1')
      _show_menu
      ;;
  esac
}

# Команды чистой установки
_clear_install_cmd () {
  _remove_esmart
  _remove_plugins
  _remove_cryptopro
  _remove_dirs
  _install_cryptopro
  _install_plugins
  _install_esmart
  _test
}

# Команды тестирования
_check_install_cmd () {
  _test
}

# Команды установки CryptoPRO
_cryptopro_install_cmd () {
  _remove_plugins
  _remove_cryptopro
  _install_cryptopro
  _install_plugins
}

# Команды удаления CryptoPRO
_cryptopro_remove_cmd () {
  _remove_plugins
  _remove_cryptopro
}

# Команды установки Browser Plugins
_plugins_install_cmd () {
  _remove_plugins
  _install_plugins
}

# Команды удаления Browser Plugins
_plugins_remove_cmd () {
  _remove_plugins
}

# Команды установки ESMART
_esmart_install_cmd () {
  _remove_esmart
  _install_esmart
}

# Команды удаления ESMART
_esmart_remove_cmd () {
  _remove_esmart
}

# Команды полного удаления CryptoPRO
_full_remove_cmd () {
  _remove_esmart
  _remove_plugins
  _remove_cryptopro
  _remove_dirs
}

# Проверка выбранного пункта меню
_check_choise () {
  case $choice in
    1)
      _clear_install_cmd
      _show_menu
      ;;
    2)
      _check_install_cmd
      _show_menu
      ;;
    3)
      _cryptopro_install_cmd
      _show_menu
      ;;
    4)
      _cryptopro_remove_cmd
      _show_menu
      ;;
    5)
      _plugins_install_cmd
      _show_menu
      ;;
    6)
      _plugins_remove_cmd
      _show_menu
      ;;
    7)
      _esmart_install_cmd
      _show_menu
      ;;
    8)
      _esmart_remove_cmd
      _show_menu
      ;;
    9)
      _full_remove_cmd
      _show_menu
      ;;
  esac
}

# Главное меню программы
_show_menu () {
  tempfile=`tempfile 2>/dev/null` || tempfile=/tmp/test$$
  trap "rm -f $tempfile" 0 1 2 5 15

  $DIALOG --clear --cancel-label "Выход" --title "Установщик CryptoPro ${version}" \
          --menu "Выберите тип установки:" 17 60 9 \
  1  "Чистая установка" \
  2  "Проверка установленных программ" \
  3  "Установка/переустановка CryptoPro" \
  4  "Удаление CryptoPro" \
  5  "Установка/переустановка Browser Plugins" \
  6  "Удаление Browser Plugins" \
  7  "Установка/переустановка драйвера ESMART 64k" \
  8  "Удаление драйвера ESMART 64k" \
  9  "Полное удаление" 2> $tempfile

  retval=$?

  choice=`cat $tempfile`

  case $retval in
    0)
      _check_choise
      ;;
    1)
      _exit
      ;;
  esac
}

# Начало программы
_start () {
  $DIALOG --yes-label "Да" --no-label "Выход" \
    --title "Установщик CryptoPro ${version}" --yesno "\\n
Данный установщик предназначен для установки CryptoPro с поддержкой ESMART 64k \
для операционной системы Ubuntu.\\nДля установки программы потребуются права \
суперпользователя.\\n\\nПродолжить?" 15 60
  case "$?" in
    '0')
      _show_menu
      ;;
    '1')
      _exit
      ;;
    '-1')
      _exit
      ;;
  esac
}

_preinstall
_start
