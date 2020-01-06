#!/bin/bash

set -ex

# Test prog for testing core file generation and gdb setup.
  cat >testprg.c <<EOS
  int main(int argc, char *argv[])
  {
            char *a;
            a=(char *)0;
            a[1]='A';
            return 0;
  }
EOS


cat testprg.c
${CC:-cc} -g -o testprg testprg.c

echo Check core file creation enviroment.
ulimit -c
cat /proc/sys/kernel/core_pattern
[ -e /etc/apport/crashdb.conf ] && cat /etc/apport/crashdb.conf

# Set core_pattern
# Woops, No write access to /proc entries when in a container.
# sudo bash -c "echo core > /proc/sys/kernel/core_pattern"

#  Set user core file size.
ulimit -c unlimited

rm -f fifo
mkfifo fifo

./testprg || RESULT=$?
if [ "$RESULT" != 139 ]; then
	echo "expected segfault and 139 exit but instead exited with $RESULT"
	exit 0
fi

j=0
for i in $(find ./ -maxdepth 1 -name 'core*' -print); do
	echo -n core file found :; ls $i;
	j=$(($j+1))
	gdb $(pwd)/testprg $i -ex "thread apply all bt" -ex "set pagination 0" -batch;
done

if [ $j == "0" ]; then
	echo "No core files were generated :("
	exit 1
fi
